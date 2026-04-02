import 'package:boatface/features/auth/application/auth_controller.dart';
import 'package:boatface/features/auth/domain/auth_state.dart';
import 'package:boatface/features/ranking/data/ranking_repository.dart';
import 'package:boatface/features/ranking/domain/ranking_models.dart';
import 'package:boatface/features/ranking/presentation/ranking_screen.dart';
import 'package:boatface/features/profile/domain/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hides mode description and shows crowns for top three', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          rankingRepositoryProvider.overrideWithValue(_FakeRankingRepository()),
          authStateProvider.overrideWith(
            (Ref ref) => Stream<AuthState>.value(
              const AuthState(
                uid: 'current-user',
                providerIds: <String>['anonymous'],
                providerLabel: '匿名ログイン',
                isAnonymous: true,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: RankingScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('10問・A1級限定の顔 -> 選手名'), findsNothing);
    expect(find.text('表示条件'), findsNothing);
    expect(find.text('SCORE'), findsOneWidget);
    expect(find.byIcon(Icons.workspace_premium_rounded), findsNWidgets(3));
    expect(find.text('1200'), findsOneWidget);
    expect(find.text('当期ベストスコア'), findsOneWidget);
    expect(find.text('1185'), findsOneWidget);
  });
}

class _FakeRankingRepository implements RankingRepository {
  @override
  Future<RankingSnapshot> fetchRankings({
    required String modeId,
    required RankingPeriod period,
    int limit = 50,
  }) async {
    return RankingSnapshot(
      modeId: modeId,
      period: period,
      generatedAt: DateTime.utc(2026, 3, 22, 12),
      entries: <RankingEntry>[
        RankingEntry(
          rank: 1,
          userId: 'user-1',
          displayName: '一位ユーザー',
          region: _tokyo,
          score: 1200,
          totalAnswerTimeMs: 32100,
        ),
        RankingEntry(
          rank: 2,
          userId: 'current-user',
          displayName: '現在のユーザー',
          region: _tokyo,
          score: 1180,
          totalAnswerTimeMs: 33800,
        ),
        RankingEntry(
          rank: 3,
          userId: 'user-3',
          displayName: '三位ユーザー',
          region: _tokyo,
          score: 1105,
          totalAnswerTimeMs: 35000,
        ),
        RankingEntry(
          rank: 4,
          userId: 'user-4',
          displayName: '四位ユーザー',
          region: _tokyo,
          score: 990,
          totalAnswerTimeMs: 40100,
        ),
      ],
    );
  }

  @override
  Future<RankingTermBestScore> fetchMyTermBestScore({
    required String modeId,
  }) async {
    return const RankingTermBestScore(
      modeId: 'quick',
      periodKeyTerm: '2026-H1',
      bestScore: 1185,
    );
  }
}

const UserRegion _tokyo = UserRegion(
  category: UserRegionCategory.prefecture,
  code: 'tokyo',
  label: '東京都',
);
