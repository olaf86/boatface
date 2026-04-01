import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/firebase_functions_client.dart';
import '../../../shared/data/firebase_functions_provider.dart';
import '../domain/review_models.dart';

abstract class ReviewRepository {
  Future<List<ReviewMistakeEntry>> fetchMyMistakes();
}

final Provider<ReviewRepository> reviewRepositoryProvider =
    Provider<ReviewRepository>((Ref ref) {
      return FirebaseReviewRepository(
        functionsClient: ref.watch(firebaseFunctionsClientProvider),
      );
    });

class FirebaseReviewRepository implements ReviewRepository {
  FirebaseReviewRepository({required FirebaseFunctionsClient functionsClient})
    : _functionsClient = functionsClient;

  final FirebaseFunctionsClient _functionsClient;

  @override
  Future<List<ReviewMistakeEntry>> fetchMyMistakes() async {
    final Map<String, Object?> json = await _functionsClient.getJsonObject(
      '/getMyQuizMistakes',
      defaultErrorMessage: '振り返りデータの取得に失敗しました。',
    );
    final Object? mistakesValue = json['mistakes'];
    if (mistakesValue is! List<Object?>) {
      throw const ReviewRepositoryException('振り返りデータの形式が不正です。');
    }

    final List<ReviewMistakeEntry> mistakes = mistakesValue
        .map(ReviewMistakeEntry.tryParseJson)
        .whereType<ReviewMistakeEntry>()
        .toList(growable: false);
    if (mistakes.length != mistakesValue.length) {
      throw const ReviewRepositoryException('振り返りデータの形式が不正です。');
    }

    return mistakes;
  }
}

class ReviewRepositoryException implements Exception {
  const ReviewRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
