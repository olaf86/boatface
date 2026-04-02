import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/firebase_functions_client.dart';
import '../../../shared/data/firebase_functions_provider.dart';
import '../domain/ranking_models.dart';

abstract class RankingRepository {
  Future<RankingSnapshot> fetchRankings({
    required String modeId,
    required RankingPeriod period,
    int limit = 50,
  });

  Future<RankingTermBestScore> fetchMyTermBestScore({required String modeId});
}

final Provider<RankingRepository> rankingRepositoryProvider =
    Provider<RankingRepository>((Ref ref) {
      return FirebaseRankingRepository(
        functionsClient: ref.watch(firebaseFunctionsClientProvider),
      );
    });

class FirebaseRankingRepository implements RankingRepository {
  FirebaseRankingRepository({required FirebaseFunctionsClient functionsClient})
    : _functionsClient = functionsClient;

  final FirebaseFunctionsClient _functionsClient;

  @override
  Future<RankingSnapshot> fetchRankings({
    required String modeId,
    required RankingPeriod period,
    int limit = 50,
  }) async {
    final Map<String, Object?> json = await _functionsClient.getJsonObject(
      '/getRankings',
      queryParameters: <String, String>{
        'modeId': modeId,
        'period': period.id,
        'limit': '$limit',
      },
      defaultErrorMessage: 'ランキングの取得に失敗しました。',
    );
    final RankingSnapshot? snapshot = RankingSnapshot.tryParseJson(json);
    if (snapshot == null) {
      throw const RankingRepositoryException('ランキングの形式が不正です。');
    }

    return snapshot;
  }

  @override
  Future<RankingTermBestScore> fetchMyTermBestScore({
    required String modeId,
  }) async {
    final Map<String, Object?> json = await _functionsClient.getJsonObject(
      '/getMyQuizHighScore',
      queryParameters: <String, String>{'modeId': modeId},
      defaultErrorMessage: 'ベストスコアの取得に失敗しました。',
    );
    final RankingTermBestScore? bestScore = RankingTermBestScore.tryParseJson(
      json,
    );
    if (bestScore == null) {
      throw const RankingRepositoryException('ベストスコアの形式が不正です。');
    }

    return bestScore;
  }
}

class RankingRepositoryException implements Exception {
  const RankingRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
