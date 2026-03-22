import 'package:boatface/features/ranking/application/ranking_providers.dart';
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
        container.listen(rankingSnapshotProvider(request), (_, __) {});
    addTearDown(firstSubscription.close);

    await container.read(rankingSnapshotProvider(request).future);
    expect(repository.fetchCount, 1);

    firstSubscription.close();
    await Future<void>.delayed(Duration.zero);

    final ProviderSubscription<AsyncValue<RankingSnapshot>> secondSubscription =
        container.listen(rankingSnapshotProvider(request), (_, __) {});
    addTearDown(secondSubscription.close);

    await container.read(rankingSnapshotProvider(request).future);
    expect(repository.fetchCount, 2);
  });
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
      entries: const <RankingEntry>[],
    );
  }
}
