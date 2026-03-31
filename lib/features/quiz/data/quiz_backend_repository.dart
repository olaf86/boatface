import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/firebase_functions_client.dart';
import '../../../shared/data/firebase_functions_provider.dart';
import '../domain/quiz_backend_models.dart';
import '../domain/quiz_models.dart';

abstract class QuizBackendRepository {
  Future<QuizSessionLease> createQuizSession({required String modeId});

  Future<QuizResultSubmissionReceipt> submitQuizResult({
    required String sessionId,
    required QuizResultSummary summary,
  });
}

final Provider<QuizBackendRepository> quizBackendRepositoryProvider =
    Provider<QuizBackendRepository>((Ref ref) {
      return FirebaseQuizBackendRepository(
        functionsClient: ref.watch(firebaseFunctionsClientProvider),
      );
    });

class FirebaseQuizBackendRepository implements QuizBackendRepository {
  FirebaseQuizBackendRepository({
    required FirebaseFunctionsClient functionsClient,
  }) : _functionsClient = functionsClient;

  final FirebaseFunctionsClient _functionsClient;

  @override
  Future<QuizSessionLease> createQuizSession({required String modeId}) async {
    final Map<String, Object?> json = await _functionsClient.postJsonObject(
      '/createQuizSession',
      body: <String, Object?>{'modeId': modeId},
      defaultErrorMessage: 'クイズセッションの作成に失敗しました。',
    );

    final String? sessionId = json['sessionId'] as String?;
    final String? expiresAtText = json['expiresAt'] as String?;
    if (sessionId == null || expiresAtText == null || expiresAtText.isEmpty) {
      throw const QuizBackendRepositoryException('クイズセッションの形式が不正です。');
    }

    final DateTime? expiresAt = DateTime.tryParse(expiresAtText);
    if (expiresAt == null) {
      throw const QuizBackendRepositoryException('クイズセッション期限の形式が不正です。');
    }

    return QuizSessionLease(sessionId: sessionId, expiresAt: expiresAt);
  }

  @override
  Future<QuizResultSubmissionReceipt> submitQuizResult({
    required String sessionId,
    required QuizResultSummary summary,
  }) async {
    final Map<String, Object?> json = await _functionsClient.postJsonObject(
      '/submitQuizResult',
      body: <String, Object?>{
        'sessionId': sessionId,
        'modeId': summary.modeId,
        'modeLabel': summary.modeLabel,
        'score': summary.score,
        'correctAnswers': summary.correctAnswers,
        'totalQuestions': summary.totalQuestions,
        'totalAnswerTimeMs': summary.totalAnswerTime.inMilliseconds,
        'endReason': _endReasonId(summary.endReason),
        'rankingEligible': summary.rankingEligible,
        'continuedByAd': summary.continuedByAd,
        'clientFinishedAt': summary.clientFinishedAt.toUtc().toIso8601String(),
        'mistakes': summary.mistakes
            .map((QuizMistakeSnapshot mistake) => mistake.toJson())
            .toList(),
      },
      defaultErrorMessage: 'クイズ結果の送信に失敗しました。',
    );

    final String? resultId = json['resultId'] as String?;
    final bool? rankingEligible = json['rankingEligible'] as bool?;
    final String? periodKeyDaily = json['periodKeyDaily'] as String?;
    final String? periodKeyTerm = json['periodKeyTerm'] as String?;
    if (resultId == null ||
        rankingEligible == null ||
        periodKeyDaily == null ||
        periodKeyTerm == null) {
      throw const QuizBackendRepositoryException('クイズ結果送信レスポンスの形式が不正です。');
    }

    return QuizResultSubmissionReceipt(
      resultId: resultId,
      rankingEligible: rankingEligible,
      periodKeyDaily: periodKeyDaily,
      periodKeyTerm: periodKeyTerm,
    );
  }

  String _endReasonId(QuizEndReason endReason) {
    return switch (endReason) {
      QuizEndReason.completed => 'completed',
      QuizEndReason.wrongAnswer => 'wrongAnswer',
      QuizEndReason.timeout => 'timeout',
      QuizEndReason.abandoned => 'abandoned',
    };
  }
}

class QuizBackendRepositoryException implements Exception {
  const QuizBackendRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
