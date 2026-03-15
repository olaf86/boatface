import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/quiz_data_providers.dart';
import '../domain/quiz_models.dart';
import 'quiz_session.dart';
import 'quiz_session_state.dart';

final AutoDisposeNotifierProviderFamily<
  QuizSessionController,
  QuizSessionState,
  QuizModeConfig
>
quizSessionControllerProvider =
    AutoDisposeNotifierProviderFamily<
      QuizSessionController,
      QuizSessionState,
      QuizModeConfig
    >(QuizSessionController.new);

class QuizSessionController
    extends AutoDisposeFamilyNotifier<QuizSessionState, QuizModeConfig> {
  late final QuizSession _session;
  late final Stopwatch _stopwatch;
  Timer? _ticker;

  @override
  QuizSessionState build(QuizModeConfig mode) {
    final racers = ref.read(mockRacerRepositoryProvider).fetchAll();

    _session = QuizSessionFactory.create(mode: mode, racers: racers);
    _stopwatch = Stopwatch()..start();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), _onTick);
    ref.onDispose(() {
      _ticker?.cancel();
      _stopwatch.stop();
    });

    return _toState();
  }

  QuizResultSummary get summary => _session.toSummary();

  void submitAnswer(int selectedIndex) {
    state = state.copyWith(isProcessing: true);

    _session.submitAnswer(
      selectedIndex: selectedIndex,
      elapsed: _stopwatch.elapsed,
    );

    if (_session.gameOver || _session.isCompleted) {
      _stopwatch.stop();
      state = _toState(isProcessing: false);
      return;
    }

    _stopwatch
      ..reset()
      ..start();
    state = _toState(isProcessing: false);
  }

  void continueAfterAd() {
    _session.continueAfterAd();
    if (_session.gameOver || _session.isCompleted) {
      state = _toState();
      return;
    }
    _stopwatch
      ..reset()
      ..start();
    state = _toState();
  }

  void abandon() {
    _session.abandon();
    _stopwatch.stop();
    state = _toState();
  }

  void handleLifecyclePause() {
    if (_session.gameOver || _session.isCompleted) {
      return;
    }
    _session.submitTimeout(elapsed: _stopwatch.elapsed);
    _stopwatch.stop();
    state = _toState();
  }

  void _onTick(Timer timer) {
    if (_session.gameOver || _session.isCompleted) {
      return;
    }
    final int? timeLimitSeconds = _session.mode.timeLimitSeconds;
    if (timeLimitSeconds != null &&
        _stopwatch.elapsed >= Duration(seconds: timeLimitSeconds)) {
      _session.submitTimeout(elapsed: _stopwatch.elapsed);
      _stopwatch.stop();
      state = _toState();
      return;
    }
    state = _toState();
  }

  QuizSessionState _toState({bool isProcessing = false}) {
    final int? limitSeconds = _session.mode.timeLimitSeconds;
    final Duration elapsed = _stopwatch.elapsed;
    final Duration? remaining = limitSeconds == null
        ? null
        : Duration(
            milliseconds:
                (Duration(seconds: limitSeconds).inMilliseconds -
                        elapsed.inMilliseconds)
                    .clamp(0, 99999999),
          );

    return QuizSessionState(
      mode: _session.mode,
      currentQuestion: _session.currentQuestion,
      currentQuestionIndex: _session.currentIndex,
      totalQuestions: _session.questions.length,
      score: _session.score,
      correctAnswers: _session.correctAnswers,
      totalAnswerTime: _session.totalAnswerTime,
      elapsedForCurrentQuestion: elapsed,
      remainingForCurrentQuestion: remaining,
      gameOver: _session.gameOver,
      isCompleted: _session.isCompleted,
      canContinueWithAd: _session.canContinueWithAd,
      continuedByAd: _session.continuedByAd,
      rankingEligible: _session.rankingEligible,
      endReason: _session.endReason,
      isProcessing: isProcessing,
    );
  }
}
