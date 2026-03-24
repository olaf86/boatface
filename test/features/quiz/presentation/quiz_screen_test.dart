import 'package:boatface/features/quiz/data/quiz_data_providers.dart';
import 'package:boatface/features/quiz/data/racer_master_models.dart';
import 'package:boatface/features/quiz/data/racer_repository.dart';
import 'package:boatface/features/quiz/application/quiz_session_controller.dart';
import 'package:boatface/features/quiz/domain/quiz_models.dart';
import 'package:boatface/features/quiz/presentation/racer_name_text.dart';
import 'package:boatface/features/quiz/presentation/quiz_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('centers text inside text choice buttons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildApp(mode: _buildMode(timeLimitSeconds: 10)));

    final Finder buttonFinder = find.byKey(
      const ValueKey<String>('quiz-option-0'),
    );
    final Text optionText = tester.widget<Text>(
      find.descendant(of: buttonFinder, matching: find.byType(Text)).first,
    );

    expect(optionText.textAlign, TextAlign.center);
  });

  testWidgets('shows hint buttons and freezes time in timed mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildApp(mode: _buildMode(timeLimitSeconds: 10)));

    expect(
      find.byKey(const ValueKey<String>('quiz-hint-fifty-fifty')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('quiz-hint-time-freeze')),
      findsOneWidget,
    );
    expect(find.byTooltip('2択に絞る'), findsOneWidget);
    expect(find.byTooltip('時間を停止する'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('quiz-hint-time-freeze')),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byTooltip('時間停止ヒントは使用済み'), findsOneWidget);
  });

  testWidgets('hides time-freeze hint in unlimited mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(mode: _buildMode(timeLimitSeconds: null)),
    );

    expect(
      find.byKey(const ValueKey<String>('quiz-hint-fifty-fifty')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('quiz-hint-time-freeze')),
      findsNothing,
    );
    expect(find.byTooltip('2択に絞る'), findsOneWidget);
    expect(find.byTooltip('時間を停止する'), findsNothing);
  });

  testWidgets('shows game-over dialog after a wrong answer', (
    WidgetTester tester,
  ) async {
    final QuizModeConfig mode = _buildMode(timeLimitSeconds: 10);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        racerRepositoryProvider.overrideWithValue(_FakeRacerRepository()),
      ],
    );
    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: QuizScreen(
              mode: mode,
              sessionId: 'session-1',
              sessionExpiresAt: DateTime.utc(2026, 3, 25),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final QuizSessionController controller = container.read(
        quizSessionControllerProvider(mode).notifier,
      );
      final state = container.read(quizSessionControllerProvider(mode));
      final int wrongIndex = (state.currentQuestion!.correctIndex + 1) % 4;

      controller.submitAnswer(wrongIndex);
      controller.completeAnswerFeedback();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const ValueKey<String>('game-over-dialog')),
        findsOneWidget,
      );
      expect(find.text('ゲームオーバー'), findsOneWidget);
      expect(find.text('結果へ'), findsOneWidget);
    } finally {
      container.dispose();
    }
  });

  testWidgets('shows furigana for racer names when available', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildApp(mode: _buildMode(timeLimitSeconds: 10)));

    expect(find.textContaining('センシュ'), findsWidgets);
    expect(find.textContaining('選手'), findsWidgets);
  });

  testWidgets('shows expiry dialog when session expired on resume', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        mode: _buildMode(timeLimitSeconds: 10),
        sessionExpiresAt: DateTime.utc(2000, 1, 1),
      ),
    );
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text('セッション期限切れ'), findsOneWidget);
    expect(
      find.text('バックグラウンド中にクイズセッションの有効期限が切れました。ホームに戻ります。'),
      findsOneWidget,
    );
  });

  testWidgets('splits family and given names with separate ruby labels', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: RacerNameText(name: '高橋 二朗', nameKana: 'タカハシ ジロウ'),
          ),
        ),
      ),
    );

    expect(find.text('高橋'), findsOneWidget);
    expect(find.text('二朗'), findsOneWidget);
    expect(find.text('タカハシ'), findsOneWidget);
    expect(find.text('ジロウ'), findsOneWidget);
  });
}

Widget _buildApp({required QuizModeConfig mode, DateTime? sessionExpiresAt}) {
  return ProviderScope(
    overrides: <Override>[
      racerRepositoryProvider.overrideWithValue(_FakeRacerRepository()),
    ],
    child: MaterialApp(
      home: QuizScreen(
        mode: mode,
        sessionId: 'session-1',
        sessionExpiresAt: sessionExpiresAt ?? DateTime.utc(2026, 3, 25),
      ),
    ),
  );
}

QuizModeConfig _buildMode({
  QuizPromptType promptType = QuizPromptType.faceToName,
  required int? timeLimitSeconds,
}) {
  return QuizModeConfig(
    id: 'test',
    label: 'テスト',
    description: 'screen test mode',
    timeLimitSeconds: timeLimitSeconds,
    segments: <QuizSegment>[QuizSegment(promptType: promptType, count: 1)],
  );
}

class _FakeRacerRepository implements RacerRepository {
  @override
  RacerDatasetManifest? get currentManifest => null;

  @override
  bool get hasUsableData => true;

  @override
  bool get hasUsableSnapshot => true;

  @override
  Future<RacerSyncResult> initialize() async {
    return const RacerSyncResult(
      activeManifest: null,
      remoteManifest: null,
      downloadedSnapshot: false,
      downloadedImagePack: false,
      usedLocalSnapshot: true,
    );
  }

  @override
  List<RacerProfile> requireCachedAll() {
    return List<RacerProfile>.generate(8, (int index) {
      return RacerProfile(
        id: 'racer-$index',
        name: '選手$index',
        nameKana: 'センシュ$index',
        registrationNumber: 5000 + index,
        racerClass: index.isEven ? 'A1' : 'A2',
        gender: index.isEven ? 'male' : 'female',
        imageUrl: 'https://example.com/racer-$index.jpg',
        imageSource: 'test',
        updatedAt: DateTime.utc(2026, 3, 21),
        isActive: true,
      );
    });
  }

  @override
  Future<RacerSyncResult> syncIfNeeded() async {
    return const RacerSyncResult(
      activeManifest: null,
      remoteManifest: null,
      downloadedSnapshot: false,
      downloadedImagePack: false,
      usedLocalSnapshot: true,
    );
  }
}
