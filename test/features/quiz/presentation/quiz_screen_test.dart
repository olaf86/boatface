import 'dart:async';

import 'package:boatface/features/quiz/data/quiz_data_providers.dart';
import 'package:boatface/features/quiz/data/racer_master_models.dart';
import 'package:boatface/features/quiz/data/racer_repository.dart';
import 'package:boatface/features/quiz/application/quiz_hint.dart';
import 'package:boatface/features/quiz/application/quiz_session_controller.dart';
import 'package:boatface/features/quiz/application/quiz_session_state.dart';
import 'package:boatface/features/quiz/domain/quiz_models.dart';
import 'package:boatface/features/quiz/presentation/racer_name_text.dart';
import 'package:boatface/features/quiz/presentation/quiz_screen.dart';
import 'package:boatface/shared/ads/rewarded_continue_ad_service.dart';
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

      expect(
        find.byKey(const ValueKey<String>('quiz-hint-fifty-fifty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('quiz-hint-time-freeze')),
        findsOneWidget,
      );
      expect(find.text('HINT'), findsOneWidget);
      expect(find.byTooltip('2択に絞る'), findsOneWidget);
      expect(find.byTooltip('時間を停止する'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('quiz-hint-time-freeze')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 360));

      final state = container.read(quizSessionControllerProvider(mode));
      expect(state.timeFreezeActive, true);
      expect(
        state.availableHints.map((QuizHintItem item) => item.type),
        isNot(contains(QuizHintType.timeFreeze)),
      );
    } finally {
      container.dispose();
    }
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
    expect(find.text('HINT'), findsOneWidget);
    expect(find.byTooltip('2択に絞る'), findsOneWidget);
    expect(find.byTooltip('時間を停止する'), findsNothing);
  });

  testWidgets('shows emergency border while 3 seconds or less remain', (
    WidgetTester tester,
  ) async {
    final QuizModeConfig mode = _buildMode(timeLimitSeconds: 10);
    final QuizSessionState initialState = _buildSessionState(mode: mode)
        .copyWith(
          remainingForCurrentQuestion: const Duration(milliseconds: 2900),
          replaceRemaining: true,
          elapsedForCurrentQuestion: const Duration(milliseconds: 7100),
        );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        quizSessionControllerProvider.overrideWith(
          () => _FakeQuizSessionController(initialState),
        ),
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

      expect(
        find.byKey(const ValueKey<String>('quiz-emergency-border')),
        findsOneWidget,
      );
    } finally {
      container.dispose();
    }
  });

  testWidgets('renders partial face variants with dedicated presenters', (
    WidgetTester tester,
  ) async {
    final QuizModeConfig mode = _buildMode(
      promptType: QuizPromptType.partialFaceToName,
      timeLimitSeconds: 10,
    );
    final _FakeQuizSessionController controller = _FakeQuizSessionController(
      _buildSessionState(
        mode: mode,
        currentQuestion: _buildPartialFaceQuestion(
          variant: PartialFaceVariant.zoomOutCenter,
          spec: const QuizZoomOutCenterVisualSpec(
            startScale: 2.2,
            startAlignmentX: 0.08,
            startAlignmentY: -0.04,
          ),
        ),
      ),
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        quizSessionControllerProvider.overrideWith(() => controller),
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

      expect(
        find.byKey(const ValueKey<String>('quiz-partial-face-zoom-out')),
        findsOneWidget,
      );

      controller.setSessionState(
        controller.state.copyWith(
          currentQuestion: _buildPartialFaceQuestion(
            variant: PartialFaceVariant.spotlights,
            spec: const QuizSpotlightsVisualSpec(
              spotlightCount: 2,
              startRadiusFactor: 0.2,
              endRadiusFactor: 0.32,
              horizontalTravelFactor: 0.58,
              verticalTravelFactor: 0.44,
              horizontalTurns: 1.3,
              verticalTurns: 1.9,
              phaseOffsetTurns: 0.18,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('quiz-partial-face-sliding-window')),
        findsOneWidget,
      );

      controller.setSessionState(
        controller.state.copyWith(
          currentQuestion: _buildPartialFaceQuestion(
            variant: PartialFaceVariant.tileReveal,
            spec: const QuizTileRevealVisualSpec(
              tileRows: 4,
              tileColumns: 4,
              revealOrder: <int>[
                0,
                5,
                10,
                15,
                1,
                4,
                11,
                14,
                2,
                7,
                8,
                13,
                3,
                6,
                9,
                12,
              ],
              initialVisibleTileCount: 0,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('quiz-partial-face-tile-reveal')),
        findsOneWidget,
      );
    } finally {
      container.dispose();
    }
  });

  testWidgets('partial face zoom reveal progresses smoothly over time', (
    WidgetTester tester,
  ) async {
    final QuizModeConfig mode = _buildMode(
      promptType: QuizPromptType.partialFaceToName,
      timeLimitSeconds: 10,
    );
    final _FakeQuizSessionController controller = _FakeQuizSessionController(
      _buildSessionState(
        mode: mode,
        currentQuestion: _buildPartialFaceQuestion(
          variant: PartialFaceVariant.zoomOutCenter,
          spec: const QuizZoomOutCenterVisualSpec(
            startScale: 2.3,
            startAlignmentX: 0.1,
            startAlignmentY: -0.05,
          ),
        ),
      ).copyWith(
        remainingForCurrentQuestion: const Duration(seconds: 8),
        replaceRemaining: true,
        elapsedForCurrentQuestion: const Duration(seconds: 2),
      ),
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        quizSessionControllerProvider.overrideWith(() => controller),
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

      final Finder earlyTransformFinder = find.descendant(
        of: find.byKey(const ValueKey<String>('quiz-partial-face-zoom-out')),
        matching: find.byType(Transform),
      );
      final Transform earlyTransform = tester.widget<Transform>(
        earlyTransformFinder.first,
      );
      final double earlyScale = earlyTransform.transform.storage[0];

      controller.setSessionState(
        controller.state.copyWith(
          remainingForCurrentQuestion: const Duration(seconds: 1),
          replaceRemaining: true,
          elapsedForCurrentQuestion: const Duration(seconds: 9),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      final Transform lateTransform = tester.widget<Transform>(
        earlyTransformFinder.first,
      );
      final double lateScale = lateTransform.transform.storage[0];

      expect(earlyScale, greaterThan(lateScale));
    } finally {
      container.dispose();
    }
  });

  testWidgets('partial face animation keeps running during time freeze', (
    WidgetTester tester,
  ) async {
    final QuizModeConfig mode = _buildMode(
      promptType: QuizPromptType.partialFaceToName,
      timeLimitSeconds: 10,
    );
    final _FakeQuizSessionController controller = _FakeQuizSessionController(
      _buildSessionState(
        mode: mode,
        currentQuestion: _buildPartialFaceQuestion(
          variant: PartialFaceVariant.zoomOutCenter,
          spec: const QuizZoomOutCenterVisualSpec(
            startScale: 2.3,
            startAlignmentX: 0.1,
            startAlignmentY: -0.05,
          ),
        ),
      ).copyWith(
        remainingForCurrentQuestion: const Duration(seconds: 8),
        replaceRemaining: true,
        elapsedForCurrentQuestion: const Duration(seconds: 2),
        timeFreezeActive: true,
      ),
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        quizSessionControllerProvider.overrideWith(() => controller),
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

      final Finder transformFinder = find.descendant(
        of: find.byKey(const ValueKey<String>('quiz-partial-face-zoom-out')),
        matching: find.byType(Transform),
      );
      final double earlyScale = tester
          .widget<Transform>(transformFinder.first)
          .transform
          .storage[0];

      await tester.pump(const Duration(seconds: 2));

      final double laterScale = tester
          .widget<Transform>(transformFinder.first)
          .transform
          .storage[0];

      expect(earlyScale, greaterThan(laterScale));
      expect(controller.state.timeFreezeActive, true);
      expect(
        controller.state.remainingForCurrentQuestion,
        const Duration(seconds: 8),
      );
    } finally {
      container.dispose();
    }
  });

  testWidgets('hides emergency border while more than 3 seconds remain', (
    WidgetTester tester,
  ) async {
    final QuizModeConfig mode = _buildMode(timeLimitSeconds: 10);
    final QuizSessionState initialState = _buildSessionState(mode: mode)
        .copyWith(
          remainingForCurrentQuestion: const Duration(milliseconds: 3100),
          replaceRemaining: true,
          elapsedForCurrentQuestion: const Duration(milliseconds: 6900),
        );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        quizSessionControllerProvider.overrideWith(
          () => _FakeQuizSessionController(initialState),
        ),
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

      expect(
        find.byKey(const ValueKey<String>('quiz-emergency-border')),
        findsNothing,
      );
    } finally {
      container.dispose();
    }
  });

  testWidgets('hides emergency border while time freeze is active', (
    WidgetTester tester,
  ) async {
    final QuizModeConfig mode = _buildMode(timeLimitSeconds: 10);
    final QuizSessionState initialState = _buildSessionState(mode: mode)
        .copyWith(
          remainingForCurrentQuestion: const Duration(milliseconds: 2900),
          replaceRemaining: true,
          elapsedForCurrentQuestion: const Duration(milliseconds: 7100),
        );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        quizSessionControllerProvider.overrideWith(
          () => _FakeQuizSessionController(initialState),
        ),
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

      expect(
        find.byKey(const ValueKey<String>('quiz-emergency-border')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('quiz-hint-time-freeze')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 360));

      expect(
        find.byKey(const ValueKey<String>('quiz-emergency-border')),
        findsNothing,
      );
    } finally {
      container.dispose();
    }
  });

  testWidgets('animates emergency border without framework errors', (
    WidgetTester tester,
  ) async {
    final QuizModeConfig mode = _buildMode(timeLimitSeconds: 10);
    final QuizSessionState initialState = _buildSessionState(mode: mode)
        .copyWith(
          remainingForCurrentQuestion: const Duration(milliseconds: 2900),
          replaceRemaining: true,
          elapsedForCurrentQuestion: const Duration(milliseconds: 7100),
        );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        quizSessionControllerProvider.overrideWith(
          () => _FakeQuizSessionController(initialState),
        ),
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
      await tester.pump(const Duration(milliseconds: 620));

      expect(tester.takeException(), isNull);
    } finally {
      container.dispose();
    }
  });

  testWidgets(
    'disables remaining same-type hint buttons while the hint effect is active',
    (WidgetTester tester) async {
      final QuizModeConfig mode = _buildMode(
        modeId: 'careful',
        questionCount: 2,
        timeLimitSeconds: null,
      );
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

        final Finder fiftyFiftyButtons = find.byKey(
          const ValueKey<String>('quiz-hint-fifty-fifty'),
        );
        expect(fiftyFiftyButtons, findsNWidgets(3));

        await tester.tap(fiftyFiftyButtons.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 360));

        final Iterable<String> disabledIds = container
            .read(quizSessionControllerProvider(mode))
            .availableHints
            .map((QuizHintItem item) => item.id);
        expect(disabledIds, hasLength(2));
        expect(
          container.read(quizSessionControllerProvider(mode)).disabledHintTypes,
          contains(QuizHintType.fiftyFifty),
        );

        final QuizSessionController controller = container.read(
          quizSessionControllerProvider(mode).notifier,
        );
        final QuizQuestion currentQuestion = container
            .read(quizSessionControllerProvider(mode))
            .currentQuestion!;
        controller.submitAnswer(currentQuestion.correctIndex);
        controller.completeAnswerFeedback();
        await tester.pump();

        final Iterable<String> reenabledIds = container
            .read(quizSessionControllerProvider(mode))
            .availableHints
            .map((QuizHintItem item) => item.id);
        expect(
          container.read(quizSessionControllerProvider(mode)).disabledHintTypes,
          isNot(contains(QuizHintType.fiftyFifty)),
        );
        expect(reenabledIds, hasLength(2));
      } finally {
        container.dispose();
      }
    },
  );

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

  testWidgets('preloads rewarded ad when quiz screen appears', (
    WidgetTester tester,
  ) async {
    final QuizModeConfig mode = _buildMode(timeLimitSeconds: 10);
    final _FakeRewardedContinueAdService adService =
        _FakeRewardedContinueAdService(
          () async => const RewardedContinueAdResult.granted(
            RewardedContinueAdOutcome.loadFailedFallback,
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          racerRepositoryProvider.overrideWithValue(_FakeRacerRepository()),
          rewardedContinueAdServiceProvider.overrideWithValue(adService),
        ],
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

    expect(adService.preloadCallCount, 1);
  });

  testWidgets('continues when rewarded ad fallback grants a retry', (
    WidgetTester tester,
  ) async {
    final QuizModeConfig mode = _buildMode(timeLimitSeconds: 10);
    final Completer<RewardedContinueAdResult> adCompleter =
        Completer<RewardedContinueAdResult>();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        racerRepositoryProvider.overrideWithValue(_FakeRacerRepository()),
        rewardedContinueAdServiceProvider.overrideWithValue(
          _FakeRewardedContinueAdService(() => adCompleter.future),
        ),
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

      await _triggerGameOver(tester, container, mode);

      await tester.tap(find.text('広告を見て続行'));
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('rewarded-continue-loading')),
        findsOneWidget,
      );

      adCompleter.complete(
        const RewardedContinueAdResult.granted(
          RewardedContinueAdOutcome.loadFailedFallback,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final state = container.read(quizSessionControllerProvider(mode));
      expect(state.gameOver, isFalse);
      expect(state.continuedByAd, isTrue);
      expect(
        find.byKey(const ValueKey<String>('rewarded-continue-loading')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('game-over-dialog')),
        findsNothing,
      );
    } finally {
      container.dispose();
    }
  });

  testWidgets('requires reward completion when rewarded ad closes early', (
    WidgetTester tester,
  ) async {
    final QuizModeConfig mode = _buildMode(timeLimitSeconds: 10);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        racerRepositoryProvider.overrideWithValue(_FakeRacerRepository()),
        rewardedContinueAdServiceProvider.overrideWithValue(
          _FakeRewardedContinueAdService(
            () async => const RewardedContinueAdResult.denied(
              RewardedContinueAdOutcome.dismissedWithoutReward,
            ),
          ),
        ),
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

      await _triggerGameOver(tester, container, mode);

      await tester.tap(find.text('広告を見て続行'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final state = container.read(quizSessionControllerProvider(mode));
      expect(state.gameOver, isTrue);
      expect(state.continuedByAd, isFalse);
      expect(find.text('広告視聴が完了しなかったため続行できません。'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('game-over-dialog')),
        findsOneWidget,
      );
    } finally {
      container.dispose();
    }
  });

  testWidgets('does not continue when ad consent is still required', (
    WidgetTester tester,
  ) async {
    final QuizModeConfig mode = _buildMode(timeLimitSeconds: 10);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        racerRepositoryProvider.overrideWithValue(_FakeRacerRepository()),
        rewardedContinueAdServiceProvider.overrideWithValue(
          _FakeRewardedContinueAdService(
            () async => const RewardedContinueAdResult.denied(
              RewardedContinueAdOutcome.consentRequiredDenied,
            ),
          ),
        ),
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

      await _triggerGameOver(tester, container, mode);

      await tester.tap(find.text('広告を見て続行'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final QuizSessionState state = container.read(
        quizSessionControllerProvider(mode),
      );
      expect(state.gameOver, isTrue);
      expect(state.continuedByAd, isFalse);
      expect(find.text('広告利用の同意が必要です。設定から変更できます。'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('game-over-dialog')),
        findsOneWidget,
      );
    } finally {
      container.dispose();
    }
  });

  testWidgets('replaces exit confirmation with game-over dialog on timeout', (
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
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('クイズを終了'), findsOneWidget);

      final QuizSessionController controller = container.read(
        quizSessionControllerProvider(mode).notifier,
      );
      final QuizSessionState state = container.read(
        quizSessionControllerProvider(mode),
      );
      final int wrongIndex = (state.currentQuestion!.correctIndex + 1) % 4;
      controller.submitAnswer(wrongIndex);
      controller.completeAnswerFeedback();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('クイズを終了'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('game-over-dialog')),
        findsOneWidget,
      );
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

Widget _buildApp({
  required QuizModeConfig mode,
  DateTime? sessionExpiresAt,
  List<Override> overrides = const <Override>[],
}) {
  return ProviderScope(
    overrides: <Override>[
      racerRepositoryProvider.overrideWithValue(_FakeRacerRepository()),
      ...overrides,
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

QuizSessionState _buildSessionState({
  required QuizModeConfig mode,
  QuizQuestion? currentQuestion,
}) {
  return QuizSessionState(
    mode: mode,
    currentQuestion: currentQuestion ?? _buildDefaultQuestion(),
    currentQuestionIndex: 0,
    totalQuestions: 1,
    score: 0,
    correctAnswers: 0,
    totalAnswerTime: Duration.zero,
    elapsedForCurrentQuestion: Duration.zero,
    remainingForCurrentQuestion: mode.timeLimitSeconds == null
        ? null
        : Duration(seconds: mode.timeLimitSeconds!),
    gameOver: false,
    isCompleted: false,
    canContinueWithAd: false,
    continuedByAd: false,
    rankingEligible: true,
    endReason: null,
    availableHints: <QuizHintItem>[
      const QuizHintItem(id: 'hint-fifty-fifty', type: QuizHintType.fiftyFifty),
      if (mode.timeLimitSeconds != null)
        const QuizHintItem(
          id: 'hint-time-freeze',
          type: QuizHintType.timeFreeze,
        ),
    ],
    hintStockCapacity: kQuizHintStockCapacity,
    disabledHintTypes: const <QuizHintType>{},
    removedOptionIndexes: const <int>{},
    timeFreezeActive: false,
    isProcessing: false,
  );
}

QuizQuestion _buildDefaultQuestion() {
  return const QuizQuestion(
    promptType: QuizPromptType.faceToName,
    prompt: 'この選手は誰？',
    promptImageUrl: 'https://example.com/prompt.jpg',
    options: <QuizOption>[
      QuizOption(racerId: 'racer-0', label: '選手0', labelReading: 'センシュ0'),
      QuizOption(racerId: 'racer-1', label: '選手1', labelReading: 'センシュ1'),
      QuizOption(racerId: 'racer-2', label: '選手2', labelReading: 'センシュ2'),
      QuizOption(racerId: 'racer-3', label: '選手3', labelReading: 'センシュ3'),
    ],
    correctIndex: 0,
    correctRacerId: 'racer-0',
  );
}

QuizQuestion _buildPartialFaceQuestion({
  required PartialFaceVariant variant,
  required QuizPromptVisualSpec spec,
}) {
  return QuizQuestion(
    promptType: QuizPromptType.partialFaceToName,
    prompt: 'この顔の選手名は？',
    promptImageUrl: 'https://example.com/prompt.jpg',
    partialFaceVariant: variant,
    promptVisualSpec: spec,
    options: const <QuizOption>[
      QuizOption(racerId: 'racer-0', label: '選手0', labelReading: 'センシュ0'),
      QuizOption(racerId: 'racer-1', label: '選手1', labelReading: 'センシュ1'),
      QuizOption(racerId: 'racer-2', label: '選手2', labelReading: 'センシュ2'),
      QuizOption(racerId: 'racer-3', label: '選手3', labelReading: 'センシュ3'),
    ],
    correctIndex: 0,
    correctRacerId: 'racer-0',
  );
}

Future<void> _triggerGameOver(
  WidgetTester tester,
  ProviderContainer container,
  QuizModeConfig mode,
) async {
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
}

QuizModeConfig _buildMode({
  String modeId = 'test',
  QuizPromptType promptType = QuizPromptType.faceToName,
  int questionCount = 1,
  required int? timeLimitSeconds,
}) {
  return QuizModeConfig(
    id: modeId,
    label: 'テスト',
    description: 'screen test mode',
    timeLimitSeconds: timeLimitSeconds,
    segments: <QuizSegment>[
      QuizSegment(promptType: promptType, count: questionCount),
    ],
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
        registrationTerm: 90 + index,
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

class _FakeQuizSessionController extends QuizSessionController {
  _FakeQuizSessionController(this._initialState);

  final QuizSessionState _initialState;

  @override
  QuizSessionState build(QuizModeConfig mode) => _initialState;

  void setSessionState(QuizSessionState nextState) {
    state = nextState;
  }

  @override
  bool useHint(String hintId) {
    QuizHintItem? hint;
    for (final QuizHintItem item in state.availableHints) {
      if (item.id == hintId) {
        hint = item;
        break;
      }
    }
    if (hint == null) {
      return false;
    }

    state = state.copyWith(
      availableHints: state.availableHints
          .where((QuizHintItem item) => item.id != hintId)
          .toList(),
      disabledHintTypes: Set<QuizHintType>.unmodifiable(<QuizHintType>{
        ...state.disabledHintTypes,
        hint.type,
      }),
      timeFreezeActive: hint.type == QuizHintType.timeFreeze
          ? true
          : state.timeFreezeActive,
    );
    return true;
  }
}

class _FakeRewardedContinueAdService implements RewardedContinueAdService {
  _FakeRewardedContinueAdService(this._onShowContinueAd);

  final Future<RewardedContinueAdResult> Function() _onShowContinueAd;
  int preloadCallCount = 0;
  int showCallCount = 0;

  @override
  Future<void> preloadContinueAd() async {
    preloadCallCount += 1;
  }

  @override
  Future<RewardedContinueAdResult> showContinueAd() {
    showCallCount += 1;
    return _onShowContinueAd();
  }

  @override
  void dispose() {}
}
