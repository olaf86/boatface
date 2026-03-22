import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/user_profile_repository.dart';
import '../domain/user_profile.dart';

final FutureProvider<UserProfile> userProfileProvider =
    FutureProvider<UserProfile>((Ref ref) {
      return ref.watch(userProfileRepositoryProvider).fetchMyProfile();
    });

final NotifierProvider<UserProfileController, AsyncValue<UserProfile?>>
userProfileControllerProvider =
    NotifierProvider<UserProfileController, AsyncValue<UserProfile?>>(
      UserProfileController.new,
    );

class UserProfileController extends Notifier<AsyncValue<UserProfile?>> {
  UserProfileRepository get _repository =>
      ref.read(userProfileRepositoryProvider);

  @override
  AsyncValue<UserProfile?> build() => const AsyncData<UserProfile?>(null);

  Future<UserProfile> saveProfile({
    required String nickname,
    required UserRegion? region,
  }) async {
    state = const AsyncLoading<UserProfile?>();
    state = await AsyncValue.guard<UserProfile?>(() async {
      final UserProfile profile = await _repository.updateMyProfile(
        nickname: nickname,
        region: region,
      );
      ref.invalidate(userProfileProvider);
      return profile;
    });

    final UserProfile? profile = state.valueOrNull;
    if (profile == null) {
      throw const UserProfileRepositoryException('プロフィールの更新に失敗しました。');
    }

    return profile;
  }
}
