import 'package:boatface/features/home/presentation/home_screen.dart';
import 'package:boatface/features/profile/data/user_profile_repository.dart';
import 'package:boatface/features/profile/domain/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows locked prerequisite message for careful mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          userProfileRepositoryProvider.overrideWithValue(
            _FakeUserProfileRepository(
              profile: const UserProfile(
                uid: 'user-1',
                displayName: 'テストユーザー',
                nickname: null,
                rankingDisplayName: 'テストユーザー',
                region: null,
                quizProgress: UserQuizProgress.empty(),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('「さくっと」を全問クリアで開放'), findsOneWidget);
    expect(find.text('未開放'), findsNWidgets(2));
    expect(find.text('開放状況: 0 / 3 モードをクリア済み'), findsOneWidget);
  });

  testWidgets('unlocks careful after quick clear and keeps challenge locked', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          userProfileRepositoryProvider.overrideWithValue(
            _FakeUserProfileRepository(
              profile: const UserProfile(
                uid: 'user-1',
                displayName: 'テストユーザー',
                nickname: null,
                rankingDisplayName: 'テストユーザー',
                region: null,
                quizProgress: UserQuizProgress(
                  totalAttempts: 3,
                  attemptCountsByMode: <String, int>{'quick': 3},
                  clearedModeIds: <String>['quick'],
                  lastAttemptModeId: 'quick',
                  lastClearedModeId: 'quick',
                ),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('「さくっと」を全問クリアで開放'), findsNothing);
    expect(find.text('30問・前半20問は顔 -> 選手名、後半10問は選手名 -> 顔'), findsOneWidget);
    expect(find.text('「じっくり」を全問クリアで開放'), findsOneWidget);
  });
}

class _FakeUserProfileRepository implements UserProfileRepository {
  const _FakeUserProfileRepository({required this.profile});

  final UserProfile profile;

  @override
  Future<UserProfile> fetchMyProfile() async => profile;

  @override
  Future<UserProfile> updateMyProfile({
    required String nickname,
    required UserRegion? region,
  }) {
    throw UnimplementedError();
  }
}
