import 'dart:async';

import 'package:boatface/features/quiz/data/quiz_data_providers.dart';
import 'package:boatface/features/quiz/data/racer_master_models.dart';
import 'package:boatface/features/quiz/data/racer_repository.dart';
import 'package:boatface/features/quiz/application/quiz_hint.dart';
import 'package:boatface/features/quiz/application/quiz_session_controller.dart';
import 'package:boatface/features/quiz/domain/quiz_models.dart';
import 'package:boatface/features/quiz/presentation/racer_name_text.dart';
import 'package:boatface/features/quiz/presentation/quiz_screen.dart';
import 'package:boatface/shared/ads/rewarded_continue_ad_service.dart';
import 'package:boatface/shared/environment/app_environment.dart';
import 'package:boatface/shared/privacy/tracking_transparency_service.dart';
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

  testWidgets('does not preload rewarded ad on production iOS before ATT', (
    WidgetTester tester,
  ) async {
    final QuizModeConfig mode = _buildMode(timeLimitSeconds: 10);
    final _FakeRewardedContinueAdService adService =
        _FakeRewardedContinueAdService(
          () async => const RewardedContinueAdResult.granted(
            RewardedContinueAdOutcome.loadFailedFallback,
          ),
        );
    final _FakeTrackingTransparencyService trackingService =
        _FakeTrackingTransparencyService(
          fetchResult: const TrackingTransparencyInfo(
            status: TrackingTransparencyStatus.notDetermined,
          ),
          requestResult: const TrackingTransparencyInfo(
            status: TrackingTransparencyStatus.notDetermined,
          ),
        );

    await tester.pumpWidget(
      _buildApp(
        mode: mode,
        overrides: <Override>[
          rewardedContinueAdServiceProvider.overrideWithValue(adService),
          trackingTransparencyServiceProvider.overrideWithValue(
            trackingService,
          ),
          appEnvironmentProvider.overrideWithValue(
            const AppEnvironment(isProduction: true),
          ),
          trackingTransparencySupportedProvider.overrideWithValue(true),
        ],
      ),
    );
    await tester.pump();

    expect(adService.preloadCallCount, 0);
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

  testWidgets('requests ATT before rewarded ad on production iOS', (
    WidgetTester tester,
  ) async {
    final QuizModeConfig mode = _buildMode(timeLimitSeconds: 10);
    final _FakeRewardedContinueAdService adService =
        _FakeRewardedContinueAdService(
          () async => const RewardedContinueAdResult.granted(
            RewardedContinueAdOutcome.earnedReward,
          ),
        );
    final _FakeTrackingTransparencyService trackingService =
        _FakeTrackingTransparencyService(
          fetchResult: const TrackingTransparencyInfo(
            status: TrackingTransparencyStatus.notDetermined,
          ),
          requestResult: const TrackingTransparencyInfo(
            status: TrackingTransparencyStatus.authorized,
            idfa: 'ABC',
          ),
        );

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        racerRepositoryProvider.overrideWithValue(_FakeRacerRepository()),
        rewardedContinueAdServiceProvider.overrideWithValue(adService),
        trackingTransparencyServiceProvider.overrideWithValue(trackingService),
        appEnvironmentProvider.overrideWithValue(
          const AppEnvironment(isProduction: true),
        ),
        trackingTransparencySupportedProvider.overrideWithValue(true),
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

      expect(trackingService.fetchCallCount, greaterThanOrEqualTo(1));
      expect(trackingService.requestCallCount, 1);
      expect(adService.showCallCount, 1);
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

class _FakeTrackingTransparencyService implements TrackingTransparencyService {
  _FakeTrackingTransparencyService({
    required this.fetchResult,
    required this.requestResult,
  });

  final TrackingTransparencyInfo fetchResult;
  final TrackingTransparencyInfo requestResult;
  int fetchCallCount = 0;
  int requestCallCount = 0;

  @override
  Future<TrackingTransparencyInfo> fetchInfo() async {
    fetchCallCount += 1;
    return fetchResult;
  }

  @override
  Future<void> openSettings() async {}

  @override
  Future<TrackingTransparencyInfo> requestAuthorization() async {
    requestCallCount += 1;
    return requestResult;
  }
}
