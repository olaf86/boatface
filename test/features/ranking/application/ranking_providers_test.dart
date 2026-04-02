import 'package:boatface/features/ranking/application/ranking_providers.dart';
import 'package:boatface/features/auth/application/auth_controller.dart';
import 'package:boatface/features/auth/domain/auth_state.dart';
import 'package:boatface/features/ranking/data/ranking_repository.dart';
import 'package:boatface/features/ranking/domain/ranking_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('re-fetches rankings after the last listener is removed', () async {
    final _FakeRankingRepository repository = _FakeRankingRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        rankingRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    const RankingRequest request = RankingRequest(
      modeId: 'quick',
      period: RankingPeriod.today,
    );

    final ProviderSubscription<AsyncValue<RankingSnapshot>> firstSubscription =
        container.listen(rankingSnapshotProvider(request), (_, _) {});
    addTearDown(firstSubscription.close);

    await container.read(rankingSnapshotProvider(request).future);
    expect(repository.fetchCount, 1);

    firstSubscription.close();
    await Future<void>.delayed(Duration.zero);

    final ProviderSubscription<AsyncValue<RankingSnapshot>> secondSubscription =
        container.listen(rankingSnapshotProvider(request), (_, _) {});
    addTearDown(secondSubscription.close);

    await container.read(rankingSnapshotProvider(request).future);
    expect(repository.fetchCount, 2);
  });

  test(
    'combines ranking snapshot and term best score for the current user',
    () async {
      final ProviderContainer container = ProviderContainer(
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
      );
      addTearDown(container.dispose);

      const RankingRequest request = RankingRequest(
        modeId: 'quick',
        period: RankingPeriod.today,
      );

      final ProviderSubscription<AsyncValue<RankingCurrentUserSummary>>
      summarySubscription = container.listen(
        rankingCurrentUserSummaryProvider(request),
        (_, _) {},
      );
      addTearDown(summarySubscription.close);

      final RankingCurrentUserSummary summary = await container.read(
        rankingCurrentUserSummaryProvider(request).future,
      );

      expect(summary.currentUserEntry?.rank, 2);
      expect(summary.currentUserEntry?.score, 1180);
      expect(summary.termBestScore.bestScore, 1185);
    },
  );
}

class _FakeRankingRepository implements RankingRepository {
  int fetchCount = 0;

  @override
  Future<RankingSnapshot> fetchRankings({
    required String modeId,
    required RankingPeriod period,
    int limit = 50,
  }) async {
    fetchCount += 1;
    return RankingSnapshot(
      modeId: modeId,
      period: period,
      generatedAt: DateTime.utc(2026, 3, 22, 12, fetchCount),
      entries: const <RankingEntry>[
        RankingEntry(
          rank: 1,
          userId: 'user-1',
          displayName: '一位ユーザー',
          region: null,
          score: 1200,
          totalAnswerTimeMs: 32100,
        ),
        RankingEntry(
          rank: 2,
          userId: 'current-user',
          displayName: '現在のユーザー',
          region: null,
          score: 1180,
          totalAnswerTimeMs: 33800,
        ),
      ],
    );
  }

  @override
  Future<RankingTermBestScore> fetchMyTermBestScore({
    required String modeId,
  }) async {
    return RankingTermBestScore(
      modeId: modeId,
      periodKeyTerm: '2026-H1',
      bestScore: 1185,
    );
  }
}
