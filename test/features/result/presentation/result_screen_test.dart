import 'package:boatface/features/quiz/domain/quiz_models.dart';
import 'package:boatface/features/result/presentation/result_screen.dart';
import 'package:flutter/material.dart';
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
    );
  }

  testWidgets('全問クリア時に紙吹雪演出を表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(
          summary: buildSummary(endReason: QuizEndReason.completed),
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
      MaterialApp(
        home: ResultScreen(
          summary: buildSummary(endReason: QuizEndReason.wrongAnswer),
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
