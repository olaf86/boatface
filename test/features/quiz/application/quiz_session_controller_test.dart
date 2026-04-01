import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boatface/features/quiz/application/quiz_session_controller.dart';
import 'package:boatface/features/quiz/application/quiz_session.dart';
import 'package:boatface/features/quiz/application/quiz_session_state.dart';
import 'package:boatface/features/quiz/data/quiz_data_providers.dart';
import 'package:boatface/features/quiz/data/racer_master_models.dart';
import 'package:boatface/features/quiz/data/racer_repository.dart';
import 'package:boatface/features/quiz/domain/quiz_models.dart';

void main() {
  group('QuizSessionController', () {
    test('keeps current question until correct feedback completes', () {
      final QuizModeConfig mode = _buildMode(questionCount: 2);
      final ProviderContainer container = _createContainer();
      addTearDown(container.dispose);

      final QuizSessionController controller = container.read(
        quizSessionControllerProvider(mode).notifier,
      );
      final QuizSessionState initialState = container.read(
        quizSessionControllerProvider(mode),
      );
      final QuizQuestion firstQuestion = initialState.currentQuestion!;

      final feedback = controller.submitAnswer(firstQuestion.correctIndex);
      final QuizSessionState pendingState = container.read(
        quizSessionControllerProvider(mode),
      );

      expect(feedback, isNotNull);
      expect(feedback!.isCorrect, true);
      expect(pendingState.currentQuestionIndex, 0);
      expect(pendingState.currentQuestion, same(firstQuestion));
      expect(pendingState.isCompleted, false);

      controller.completeAnswerFeedback();
      final QuizSessionState completedState = container.read(
        quizSessionControllerProvider(mode),
      );
      expect(completedState.currentQuestionIndex, 1);
      expect(completedState.gameOver, false);
    });

    test('delays game over until incorrect feedback completes', () {
      final QuizModeConfig mode = _buildMode(questionCount: 2);
      final ProviderContainer container = _createContainer();
      addTearDown(container.dispose);

      final QuizSessionController controller = container.read(
        quizSessionControllerProvider(mode).notifier,
      );
      final QuizQuestion firstQuestion = container
          .read(quizSessionControllerProvider(mode))
          .currentQuestion!;
      final int wrongIndex =
          (firstQuestion.correctIndex + 1) % firstQuestion.options.length;

      final feedback = controller.submitAnswer(wrongIndex);
      final QuizSessionState pendingState = container.read(
        quizSessionControllerProvider(mode),
      );

      expect(feedback, isNotNull);
      expect(feedback!.isCorrect, false);
      expect(pendingState.gameOver, false);
      expect(pendingState.endReason, isNull);

      controller.completeAnswerFeedback();
      final QuizSessionState completedState = container.read(
        quizSessionControllerProvider(mode),
      );
      expect(completedState.gameOver, true);
      expect(completedState.endReason, QuizEndReason.wrongAnswer);
    });

    test('summary includes mistake snapshots for later review', () {
      final QuizModeConfig mode = _buildMode(questionCount: 2);
      final ProviderContainer container = _createContainer();
      addTearDown(container.dispose);

      final QuizSessionController controller = container.read(
        quizSessionControllerProvider(mode).notifier,
      );
      final QuizQuestion firstQuestion = container
          .read(quizSessionControllerProvider(mode))
          .currentQuestion!;
      final int wrongIndex =
          (firstQuestion.correctIndex + 1) % firstQuestion.options.length;

      controller.submitAnswer(wrongIndex);
      controller.completeAnswerFeedback();

      final QuizResultSummary summary = controller.summary;
      expect(summary.mistakes, hasLength(1));
      expect(summary.mistakes.single.questionIndex, 0);
      expect(summary.mistakes.single.mistakeSequence, 0);
      expect(summary.mistakes.single.promptType, firstQuestion.promptType);
      expect(summary.mistakes.single.correctIndex, firstQuestion.correctIndex);
      expect(summary.mistakes.single.selectedIndex, wrongIndex);
      expect(
        summary.mistakes.single.correctRacerId,
        firstQuestion.correctRacerId,
      );
      expect(
        summary.mistakes.single.selectedRacerId,
        firstQuestion.options[wrongIndex].racerId,
      );
      expect(summary.mistakes.single.outcome, QuizMistakeOutcome.wrongAnswer);
    });

    test('replaces the current question after continuing from an ad', () {
      final QuizModeConfig mode = _buildMode(questionCount: 2);
      final ProviderContainer container = _createContainer();
      addTearDown(container.dispose);

      final QuizSessionController controller = container.read(
        quizSessionControllerProvider(mode).notifier,
      );
      final QuizSessionState initialState = container.read(
        quizSessionControllerProvider(mode),
      );
      final QuizQuestion firstQuestion = initialState.currentQuestion!;
      final int wrongIndex =
          (firstQuestion.correctIndex + 1) % firstQuestion.options.length;

      controller.submitAnswer(wrongIndex);
      controller.completeAnswerFeedback();
      controller.continueAfterAd();

      final QuizSessionState continuedState = container.read(
        quizSessionControllerProvider(mode),
      );
      final QuizQuestion replacementQuestion = continuedState.currentQuestion!;
      expect(continuedState.gameOver, false);
      expect(continuedState.continuedByAd, true);
      expect(continuedState.currentQuestionIndex, 0);
      expect(replacementQuestion, isNot(same(firstQuestion)));
      expect(
        replacementQuestion.correctRacerId,
        isNot(firstQuestion.correctRacerId),
      );

      final List<QuizQuestionRecord> history = controller.questionHistory;
      expect(history, hasLength(2));
      expect(history[0].slotIndex, 0);
      expect(history[0].outcome, QuizQuestionOutcome.wrongAnswer);
      expect(history[1].slotIndex, 0);
      expect(
        history[1].question.correctRacerId,
        replacementQuestion.correctRacerId,
      );
      expect(history[1].outcome, isNull);
    });

    test(
      'delays completion on final correct answer until feedback completes',
      () {
        final QuizModeConfig mode = _buildMode(questionCount: 1);
        final ProviderContainer container = _createContainer();
        addTearDown(container.dispose);

        final QuizSessionController controller = container.read(
          quizSessionControllerProvider(mode).notifier,
        );
        final QuizQuestion firstQuestion = container
            .read(quizSessionControllerProvider(mode))
            .currentQuestion!;

        controller.submitAnswer(firstQuestion.correctIndex);
        final QuizSessionState pendingState = container.read(
          quizSessionControllerProvider(mode),
        );
        expect(pendingState.isCompleted, false);
        expect(pendingState.currentQuestion, isNotNull);

        controller.completeAnswerFeedback();
        final QuizSessionState completedState = container.read(
          quizSessionControllerProvider(mode),
        );
        expect(completedState.isCompleted, true);
        expect(completedState.currentQuestion, isNull);
        expect(completedState.endReason, QuizEndReason.completed);
      },
    );

    test('uses fifty-fifty hint only once per session', () {
      final QuizModeConfig mode = _buildMode(questionCount: 2);
      final ProviderContainer container = _createContainer();
      addTearDown(container.dispose);

      final QuizSessionController controller = container.read(
        quizSessionControllerProvider(mode).notifier,
      );

      expect(controller.useFiftyFiftyHint(), true);

      final QuizSessionState hintedState = container.read(
        quizSessionControllerProvider(mode),
      );
      expect(hintedState.fiftyFiftyHintUsed, true);
      expect(hintedState.canUseFiftyFiftyHint, false);
      expect(hintedState.removedOptionIndexes, hasLength(2));

      controller.completeAnswerFeedback();
      expect(controller.useFiftyFiftyHint(), false);
    });

    test('resets time freeze after advancing and allows it only once', () {
      final QuizModeConfig mode = _buildMode(questionCount: 2);
      final ProviderContainer container = _createContainer();
      addTearDown(container.dispose);

      final QuizSessionController controller = container.read(
        quizSessionControllerProvider(mode).notifier,
      );
      final QuizQuestion firstQuestion = container
          .read(quizSessionControllerProvider(mode))
          .currentQuestion!;

      expect(controller.useTimeFreezeHint(), true);

      final QuizSessionState frozenState = container.read(
        quizSessionControllerProvider(mode),
      );
      expect(frozenState.timeFreezeHintUsed, true);
      expect(frozenState.timeFreezeActive, true);
      expect(frozenState.canUseTimeFreezeHint, false);

      controller.submitAnswer(firstQuestion.correctIndex);
      controller.completeAnswerFeedback();

      final QuizSessionState advancedState = container.read(
        quizSessionControllerProvider(mode),
      );
      expect(advancedState.currentQuestionIndex, 1);
      expect(advancedState.timeFreezeActive, false);
      expect(advancedState.timeFreezeHintUsed, true);
      expect(advancedState.canUseTimeFreezeHint, false);
      expect(controller.useTimeFreezeHint(), false);
    });

    test('disables time freeze hint in unlimited mode', () {
      final QuizModeConfig mode = _buildMode(
        questionCount: 1,
        timeLimitSeconds: null,
      );
      final ProviderContainer container = _createContainer();
      addTearDown(container.dispose);

      final QuizSessionController controller = container.read(
        quizSessionControllerProvider(mode).notifier,
      );
      final QuizSessionState state = container.read(
        quizSessionControllerProvider(mode),
      );

      expect(state.canUseTimeFreezeHint, false);
      expect(controller.useTimeFreezeHint(), false);
    });

    test('does not fail immediately when app lifecycle pauses', () async {
      final QuizModeConfig mode = _buildMode(questionCount: 1);
      final ProviderContainer container = _createContainer();
      addTearDown(container.dispose);
      final provider = quizSessionControllerProvider(mode);
      final ProviderSubscription<QuizSessionState> subscription = container
          .listen(provider, (_, _) {});
      addTearDown(subscription.close);

      final QuizSessionController controller = container.read(
        provider.notifier,
      );

      controller.handleLifecyclePause();
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      final QuizSessionState pausedState = container.read(provider);
      expect(pausedState.gameOver, false);
      expect(pausedState.isCompleted, false);
      expect(pausedState.endReason, isNull);
    });

    test('resumes timer after app lifecycle resumes', () async {
      final QuizModeConfig mode = _buildMode(
        questionCount: 1,
        timeLimitSeconds: 1,
      );
      final ProviderContainer container = _createContainer();
      addTearDown(container.dispose);
      final provider = quizSessionControllerProvider(mode);
      final ProviderSubscription<QuizSessionState> subscription = container
          .listen(provider, (_, _) {});
      addTearDown(subscription.close);

      final QuizSessionController controller = container.read(
        provider.notifier,
      );

      await Future<void>.delayed(const Duration(milliseconds: 350));
      controller.handleLifecyclePause();
      await Future<void>.delayed(const Duration(milliseconds: 900));

      final QuizSessionState pausedState = container.read(provider);
      expect(pausedState.gameOver, false);

      controller.handleLifecycleResume();
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      final QuizSessionState resumedState = container.read(provider);
      expect(resumedState.gameOver, true);
      expect(resumedState.endReason, QuizEndReason.timeout);
    });
  });
}

ProviderContainer _createContainer() {
  return ProviderContainer(
    overrides: <Override>[
      racerRepositoryProvider.overrideWithValue(_FakeRacerRepository()),
    ],
  );
}

QuizModeConfig _buildMode({
  required int questionCount,
  int? timeLimitSeconds = 10,
}) {
  return QuizModeConfig(
    id: 'test',
    label: 'テスト',
    description: 'controller test mode',
    timeLimitSeconds: timeLimitSeconds,
    segments: <QuizSegment>[
      QuizSegment(promptType: QuizPromptType.faceToName, count: questionCount),
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
