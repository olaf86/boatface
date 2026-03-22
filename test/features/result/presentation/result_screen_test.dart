import 'package:boatface/features/quiz/data/quiz_backend_repository.dart';
import 'package:boatface/features/quiz/domain/quiz_backend_models.dart';
import 'package:boatface/features/quiz/domain/quiz_models.dart';
import 'package:boatface/features/result/presentation/result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  QuizResultSummary buildSummary({required QuizEndReason endReason}) {
    return QuizResultSummary(
      modeId: 'mode-1',
      modeLabel: 'テストモード',
      score: 5,
      correctAnswers: 5,
      totalQuestions: 5,
      totalAnswerTime: const Duration(seconds: 12),
      endReason: endReason,
      rankingEligible: true,
      continuedByAd: false,
      clientFinishedAt: DateTime.utc(2026, 3, 22, 12),
    );
  }

  testWidgets('全問クリア時に紙吹雪演出を表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          quizBackendRepositoryProvider.overrideWithValue(
            _FakeQuizBackendRepository(),
          ),
        ],
        child: MaterialApp(
          home: ResultScreen(
            summary: buildSummary(endReason: QuizEndReason.completed),
            sessionId: 'session-1',
          ),
        ),
      ),
    );

    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('mode-clear-confetti')),
      findsOneWidget,
    );
    expect(find.text('MODE CLEAR'), findsOneWidget);
  });

  testWidgets('全問クリア以外では紙吹雪演出を表示しない', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          quizBackendRepositoryProvider.overrideWithValue(
            _FakeQuizBackendRepository(),
          ),
        ],
        child: MaterialApp(
          home: ResultScreen(
            summary: buildSummary(endReason: QuizEndReason.wrongAnswer),
            sessionId: 'session-1',
          ),
        ),
      ),
    );

    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('mode-clear-confetti')),
      findsNothing,
    );
    expect(find.text('MODE CLEAR'), findsNothing);
  });
}

class _FakeQuizBackendRepository implements QuizBackendRepository {
  @override
  Future<String> createQuizSession({required String modeId}) async {
    return 'session-1';
  }

  @override
  Future<QuizResultSubmissionReceipt> submitQuizResult({
    required String sessionId,
    required QuizResultSummary summary,
  }) async {
    return const QuizResultSubmissionReceipt(
      resultId: 'result-1',
      rankingEligible: true,
      periodKeyDaily: '2026-03-22',
      periodKeyTerm: '2026-03',
    );
  }
}
