import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boatface/features/quiz/application/quiz_session_controller.dart';
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
  });
}

ProviderContainer _createContainer() {
  return ProviderContainer(
    overrides: <Override>[
      racerRepositoryProvider.overrideWithValue(_FakeRacerRepository()),
    ],
  );
}

QuizModeConfig _buildMode({required int questionCount}) {
  return QuizModeConfig(
    id: 'test',
    label: 'テスト',
    description: 'controller test mode',
    timeLimitSeconds: 10,
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
        registrationNumber: 5000 + index,
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
