import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_state.dart';

final Provider<FirebaseAuth> firebaseAuthProvider = Provider<FirebaseAuth>(
  (Ref ref) => FirebaseAuth.instance,
);

final Provider<GoogleSignIn> googleSignInProvider = Provider<GoogleSignIn>(
  (Ref ref) => GoogleSignIn.instance,
);

final StreamProvider<AuthState> authStateProvider = StreamProvider<AuthState>((
  Ref ref,
) {
  final FirebaseAuth auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges().map(_mapUserToAuthState);
});

final NotifierProvider<AuthController, AsyncValue<void>>
authControllerProvider = NotifierProvider<AuthController, AsyncValue<void>>(
  AuthController.new,
);

AuthState _mapUserToAuthState(User? user) {
  if (user == null) {
    return const AuthState.signedOut();
  }

  final Set<String> providerIds = user.providerData
      .map((UserInfo userInfo) => userInfo.providerId)
      .where((String providerId) => providerId.isNotEmpty)
      .toSet();

  if (providerIds.isEmpty && user.isAnonymous) {
    providerIds.add('anonymous');
  }

  return AuthState(
    uid: user.uid,
    providerIds: providerIds.toList()..sort(),
    providerLabel: _providerLabelFor(user, providerIds),
    isAnonymous: user.isAnonymous,
  );
}

String _providerLabelFor(User user, Set<String> providerIds) {
  if (user.isAnonymous || providerIds.contains('anonymous')) {
    return '匿名ログイン';
  }
  if (providerIds.contains('google.com')) {
    return 'Google';
  }
  if (providerIds.contains('gc.apple.com')) {
    return 'Game Center';
  }
  if (providerIds.contains('playgames.google.com')) {
    return 'Play Games';
  }
  return 'ログイン済み';
}

class AuthController extends Notifier<AsyncValue<void>> {
  FirebaseAuth get _auth => ref.read(firebaseAuthProvider);
  GoogleSignIn get _googleSignIn => ref.read(googleSignInProvider);

  @override
  AsyncValue<void> build() => const AsyncData<void>(null);

  Future<void> signInAnonymously() async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(() async {
      if (_auth.currentUser != null) {
        return;
      }
      await _auth.signInAnonymously();
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(() async {
      await _googleSignIn.signOut();
      await _auth.signOut();
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(() async {
      await _googleSignIn.initialize();
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final User? currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.isAnonymous) {
        await currentUser.linkWithCredential(credential);
        return;
      }

      await _auth.signInWithCredential(credential);
    });
  }

  String? get errorMessage {
    final Object? error = state.asError?.error;
    if (error is FirebaseAuthException) {
      return error.message ?? '認証に失敗しました。';
    }
    if (error == null) {
      return null;
    }
    return '認証に失敗しました。';
  }
}
