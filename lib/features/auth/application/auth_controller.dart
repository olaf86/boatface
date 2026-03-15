import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_state.dart';

final NotifierProvider<AuthController, AuthState> authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    return const AuthState();
  }

  void signIn(String providerLabel) {
    state = state.copyWith(providerLabel: providerLabel);
  }

  void signOut() {
    state = state.copyWith(clearProvider: true);
  }
}
