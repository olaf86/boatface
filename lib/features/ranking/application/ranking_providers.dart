import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ranking_repository.dart';
import '../domain/ranking_models.dart';

final rankingSnapshotProvider = FutureProvider.autoDispose
    .family<RankingSnapshot, RankingRequest>((Ref ref, RankingRequest request) {
      return ref
          .watch(rankingRepositoryProvider)
          .fetchRankings(
            modeId: request.modeId,
            period: request.period,
            limit: request.limit,
          );
    });
