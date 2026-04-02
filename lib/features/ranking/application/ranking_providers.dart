import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
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

final rankingTermBestScoreProvider = FutureProvider.autoDispose
    .family<RankingTermBestScore, String>((Ref ref, String modeId) {
      return ref
          .watch(rankingRepositoryProvider)
          .fetchMyTermBestScore(modeId: modeId);
    });

final rankingCurrentUserSummaryProvider = FutureProvider.autoDispose
    .family<RankingCurrentUserSummary, RankingRequest>((
      Ref ref,
      RankingRequest request,
    ) async {
      final String? currentUserId = ref
          .watch(authStateProvider)
          .valueOrNull
          ?.uid;
      final Future<RankingSnapshot> snapshotFuture = ref.watch(
        rankingSnapshotProvider(request).future,
      );
      final Future<RankingTermBestScore> bestScoreFuture = ref.watch(
        rankingTermBestScoreProvider(request.modeId).future,
      );
      final RankingSnapshot snapshot = await snapshotFuture;
      final RankingTermBestScore bestScore = await bestScoreFuture;

      RankingEntry? currentUserEntry;
      if (currentUserId != null) {
        for (final RankingEntry entry in snapshot.entries) {
          if (entry.userId == currentUserId) {
            currentUserEntry = entry;
            break;
          }
        }
      }

      return RankingCurrentUserSummary(
        currentUserEntry: currentUserEntry,
        termBestScore: bestScore,
      );
    });
