import 'package:boatface/features/home/presentation/home_screen.dart';
import 'package:boatface/features/profile/data/user_profile_repository.dart';
import 'package:boatface/features/profile/domain/user_profile.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('does not show locked labels before profile finishes loading', (
    WidgetTester tester,
  ) async {
    final Completer<UserProfile> profileCompleter = Completer<UserProfile>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          userProfileRepositoryProvider.overrideWithValue(
            _DeferredUserProfileRepository(profileCompleter.future),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('未開放'), findsNothing);
    expect(find.byIcon(Icons.lock_rounded), findsNothing);
    expect(find.text('さくっと'), findsNothing);
  });

  testWidgets('shows locked state for unavailable modes', (
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

    expect(find.text('未開放'), findsNothing);
    expect(find.byIcon(Icons.lock_rounded), findsNWidgets(3));
    expect(find.text('クイズモードを選択'), findsOneWidget);
    expect(find.text('10問・A1級限定の顔 → 選手名'), findsNothing);
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

    expect(find.text('未開放'), findsNothing);
    expect(find.byIcon(Icons.lock_rounded), findsNWidgets(2));
    expect(find.text('じっくり'), findsOneWidget);
    expect(find.text('30問・前半20問は顔 → 選手名、後半10問は選手名 → 顔'), findsNothing);
  });

  testWidgets(
    'tapping a locked mode shakes and swaps title to unlock condition temporarily',
    (WidgetTester tester) async {
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

      expect(find.text('「さくっと」を全問クリアで開放'), findsNothing);

      final Finder lockedCard = find.byKey(
        const ValueKey<String>('mode-card-careful'),
      );
      final double xBeforeTap = tester.getTopLeft(lockedCard).dx;

      await tester.tap(find.text('じっくり'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(find.text('「さくっと」を全問クリアで開放'), findsOneWidget);
      expect(tester.getTopLeft(lockedCard).dx, isNot(xBeforeTap));

      await tester.pump(const Duration(milliseconds: 260));

      expect(find.text('じっくり'), findsNothing);

      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pumpAndSettle();

      expect(find.text('「さくっと」を全問クリアで開放'), findsNothing);
      expect(find.text('じっくり'), findsOneWidget);
    },
  );
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

class _DeferredUserProfileRepository implements UserProfileRepository {
  const _DeferredUserProfileRepository(this.profileFuture);

  final Future<UserProfile> profileFuture;

  @override
  Future<UserProfile> fetchMyProfile() => profileFuture;

  @override
  Future<UserProfile> updateMyProfile({
    required String nickname,
    required UserRegion? region,
  }) {
    throw UnimplementedError();
  }
}
