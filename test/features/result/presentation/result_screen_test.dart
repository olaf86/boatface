import 'dart:async';

import 'package:boatface/features/quiz/data/quiz_backend_repository.dart';
import 'package:boatface/features/quiz/domain/quiz_backend_models.dart';
import 'package:boatface/features/quiz/domain/quiz_models.dart';
import 'package:boatface/features/result/presentation/result_screen.dart';
import 'package:boatface/app/navigation/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  QuizResultSummary buildSummary({
    required QuizEndReason endReason,
    String modeId = 'mode-1',
    String modeLabel = 'テストモード',
    List<QuizMistakeSnapshot> mistakes = const <QuizMistakeSnapshot>[],
  }) {
    return QuizResultSummary(
      modeId: modeId,
      modeLabel: modeLabel,
      score: 5,
      correctAnswers: 5,
      totalQuestions: 5,
      totalAnswerTime: const Duration(seconds: 12),
      endReason: endReason,
      rankingEligible: true,
      continuedByAd: false,
      clientFinishedAt: DateTime.utc(2026, 3, 22, 12),
      mistakes: mistakes,
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
    expect(
      find.text('テストモードクリアおめでとうございます！次のモードにも挑戦してみましょう！'),
      findsOneWidget,
    );
  });

  testWidgets('達人モードクリア時は専用メッセージを表示する', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          quizBackendRepositoryProvider.overrideWithValue(
            _FakeQuizBackendRepository(),
          ),
        ],
        child: MaterialApp(
          home: ResultScreen(
            summary: buildSummary(
              endReason: QuizEndReason.completed,
              modeId: 'master',
              modeLabel: '達人',
            ),
            sessionId: 'session-1',
          ),
        ),
      ),
    );

    await tester.pump();

    expect(
      find.text('ここまで来たあなたは、もう達人。次は自己ベスト更新を狙いましょう。'),
      findsOneWidget,
    );
    expect(
      find.text('達人モードクリアおめでとうございます！次のモードにも挑戦してみましょう！'),
      findsNothing,
    );
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

  testWidgets('ランキングボタンで AppShell のランキングタブへ戻る', (WidgetTester tester) async {
    _setResultSurfaceSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          quizBackendRepositoryProvider.overrideWithValue(
            _FakeQuizBackendRepository(),
          ),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const _ShellProbeScreen(),
        ),
      ),
    );

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return ResultScreen(
            summary: buildSummary(endReason: QuizEndReason.completed),
            sessionId: 'session-1',
          );
        },
      ),
    );

    await _pumpResultScreen(tester);
    final Finder rankingButton = find.text('ランキングを見る', skipOffstage: false);
    await tester.ensureVisible(rankingButton);
    await tester.tap(rankingButton);
    await tester.pumpAndSettle();

    expect(find.text('現在タブ: ランキング'), findsOneWidget);
    expect(find.text('リザルト'), findsNothing);
  });

  testWidgets('左上ホームアイコンと最下部のホームボタンで遊ぶタブへ戻る', (WidgetTester tester) async {
    _setResultSurfaceSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          quizBackendRepositoryProvider.overrideWithValue(
            _FakeQuizBackendRepository(),
          ),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const _ShellProbeScreen(),
        ),
      ),
    );

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return ResultScreen(
            summary: buildSummary(endReason: QuizEndReason.completed),
            sessionId: 'session-1',
          );
        },
      ),
    );

    await _pumpResultScreen(tester);
    await tester.tap(find.byIcon(Icons.home_rounded));
    await tester.pumpAndSettle();

    expect(find.text('現在タブ: 遊ぶ'), findsOneWidget);
    expect(find.text('リザルト'), findsNothing);

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return ResultScreen(
            summary: buildSummary(endReason: QuizEndReason.completed),
            sessionId: 'session-1',
          );
        },
      ),
    );

    await _pumpResultScreen(tester);
    final Finder homeButton = find.text('ホームに戻る', skipOffstage: false);
    await tester.ensureVisible(homeButton);
    await tester.tap(homeButton);
    await tester.pumpAndSettle();

    expect(find.text('現在タブ: 遊ぶ'), findsOneWidget);
    expect(find.text('リザルト'), findsNothing);
  });

  testWidgets('保存成功時はシンプルなスナックバーを表示する', (WidgetTester tester) async {
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

    await _pumpResultScreen(tester);

    expect(find.text('保存しました。'), findsOneWidget);
    expect(find.text('クイズ結果を保存しました。'), findsNothing);
  });

  testWidgets('保存中でも結果画面のボタン位置が変わらない', (WidgetTester tester) async {
    _setResultSurfaceSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final Completer<QuizResultSubmissionReceipt> completer =
        Completer<QuizResultSubmissionReceipt>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          quizBackendRepositoryProvider.overrideWithValue(
            _PendingQuizBackendRepository(completer),
          ),
        ],
        child: MaterialApp(
          home: ResultScreen(
            summary: buildSummary(
              endReason: QuizEndReason.completed,
              mistakes: const <QuizMistakeSnapshot>[
                QuizMistakeSnapshot(
                  questionIndex: 0,
                  mistakeSequence: 0,
                  promptType: QuizPromptType.nameToFace,
                  prompt: '誰でしょう',
                  options: <QuizMistakeOptionSnapshot>[
                    QuizMistakeOptionSnapshot(
                      racerId: 'r1',
                      label: '正解',
                      labelReading: null,
                      imageUrl: null,
                    ),
                    QuizMistakeOptionSnapshot(
                      racerId: 'r2',
                      label: '不正解',
                      labelReading: null,
                      imageUrl: null,
                    ),
                  ],
                  correctIndex: 0,
                  selectedIndex: 1,
                  correctRacerId: 'r1',
                  selectedRacerId: 'r2',
                  elapsed: Duration(seconds: 2),
                  outcome: QuizMistakeOutcome.wrongAnswer,
                ),
              ],
            ),
            sessionId: 'session-1',
          ),
        ),
      ),
    );

    await tester.pump();

    final Finder rankingButton = find.widgetWithText(FilledButton, 'ランキングを見る');
    final Finder reviewButton = find.widgetWithText(FilledButton, 'ミスを振り返る');
    final Finder homeButton = find.widgetWithText(OutlinedButton, 'ホームに戻る');

    final Offset rankingPositionBefore = tester.getTopLeft(rankingButton);
    final Offset reviewPositionBefore = tester.getTopLeft(reviewButton);
    final Offset homePositionBefore = tester.getTopLeft(homeButton);

    completer.complete(
      const QuizResultSubmissionReceipt(
        resultId: 'result-1',
        rankingEligible: true,
        periodKeyDaily: '2026-03-22',
        periodKeyTerm: '2026-03',
      ),
    );

    await _pumpResultScreen(tester);

    expect(tester.getTopLeft(rankingButton), rankingPositionBefore);
    expect(tester.getTopLeft(reviewButton), reviewPositionBefore);
    expect(tester.getTopLeft(homeButton), homePositionBefore);
  });
}

class _ShellProbeScreen extends ConsumerWidget {
  const _ShellProbeScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppShellTab currentTab = ref.watch(appShellTabControllerProvider);
    return Scaffold(body: Center(child: Text('現在タブ: ${currentTab.label}')));
  }
}

Future<void> _pumpResultScreen(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void _setResultSurfaceSize(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 1400);
}

class _FakeQuizBackendRepository implements QuizBackendRepository {
  @override
  Future<QuizSessionLease> createQuizSession({required String modeId}) async {
    return QuizSessionLease(
      sessionId: 'session-1',
      expiresAt: DateTime.utc(2026, 3, 24, 12),
    );
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

class _PendingQuizBackendRepository implements QuizBackendRepository {
  _PendingQuizBackendRepository(this.completer);

  final Completer<QuizResultSubmissionReceipt> completer;

  @override
  Future<QuizSessionLease> createQuizSession({required String modeId}) async {
    return QuizSessionLease(
      sessionId: 'session-1',
      expiresAt: DateTime.utc(2026, 3, 24, 12),
    );
  }

  @override
  Future<QuizResultSubmissionReceipt> submitQuizResult({
    required String sessionId,
    required QuizResultSummary summary,
  }) {
    return completer.future;
  }
}
