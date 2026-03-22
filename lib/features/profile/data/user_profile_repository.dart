import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/firebase_functions_client.dart';
import '../../../shared/data/firebase_functions_provider.dart';
import '../domain/user_profile.dart';

abstract class UserProfileRepository {
  Future<UserProfile> fetchMyProfile();

  Future<UserProfile> updateMyProfile({
    required String nickname,
    required UserRegion? region,
  });
}

final Provider<UserProfileRepository> userProfileRepositoryProvider =
    Provider<UserProfileRepository>((Ref ref) {
      return FirebaseUserProfileRepository(
        functionsClient: ref.watch(firebaseFunctionsClientProvider),
      );
    });

class FirebaseUserProfileRepository implements UserProfileRepository {
  FirebaseUserProfileRepository({
    required FirebaseFunctionsClient functionsClient,
  }) : _functionsClient = functionsClient;

  final FirebaseFunctionsClient _functionsClient;

  @override
  Future<UserProfile> fetchMyProfile() async {
    final Map<String, Object?> json = await _functionsClient.getJsonObject(
      '/getMyProfile',
      defaultErrorMessage: 'プロフィールの取得に失敗しました。',
    );
    final UserProfile? profile = UserProfile.tryParseJson(json);
    if (profile == null) {
      throw const UserProfileRepositoryException('プロフィールの形式が不正です。');
    }

    return profile;
  }

  @override
  Future<UserProfile> updateMyProfile({
    required String nickname,
    required UserRegion? region,
  }) async {
    final Map<String, Object?> json = await _functionsClient.postJsonObject(
      '/updateMyProfile',
      body: <String, Object?>{
        'nickname': nickname.trim(),
        'region': region?.toRequestJson(),
      },
      defaultErrorMessage: 'プロフィールの更新に失敗しました。',
    );
    final UserProfile? profile = UserProfile.tryParseJson(json);
    if (profile == null) {
      throw const UserProfileRepositoryException('プロフィールの形式が不正です。');
    }

    return profile;
  }
}

class UserProfileRepositoryException implements Exception {
  const UserProfileRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
