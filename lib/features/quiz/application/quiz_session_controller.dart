import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/quiz_data_providers.dart';
import '../domain/quiz_models.dart';
import 'quiz_answer_feedback.dart';
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
    final racers = ref.read(racerRepositoryProvider).requireCachedAll();

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
  List<QuizQuestionRecord> get questionHistory => _session.questionHistory;

  QuizAnswerFeedback? submitAnswer(int selectedIndex) {
    final Duration elapsed = _stopwatch.elapsed;
    final Duration? remaining = _buildRemaining(elapsed);
    _stopwatch.stop();

    final QuizAnswerFeedback? feedback = _session.submitAnswer(
      selectedIndex: selectedIndex,
      elapsed: elapsed,
      remaining: remaining,
    );
    if (feedback == null) {
      if (!_session.gameOver &&
          !_session.isCompleted &&
          _session.pendingAnswerFeedback == null) {
        _stopwatch.start();
      }
      return null;
    }

    state = _toState();
    return feedback;
  }

  bool useFiftyFiftyHint() {
    final bool used = _session.useFiftyFiftyHint();
    if (used) {
      state = _toState();
    }
    return used;
  }

  bool useTimeFreezeHint() {
    final bool used = _session.useTimeFreezeHint();
    if (!used) {
      return false;
    }
    _stopwatch.stop();
    state = _toState();
    return true;
  }

  void completeAnswerFeedback() {
    if (_session.pendingAnswerFeedback == null) {
      return;
    }

    _session.completePendingAnswerFeedback();
    if (!_session.gameOver && !_session.isCompleted) {
      _stopwatch
        ..reset()
        ..start();
    }
    state = _toState();
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
    if (_session.gameOver ||
        _session.isCompleted ||
        _session.pendingAnswerFeedback != null ||
        _session.timeFreezeActive) {
      return;
    }
    _session.submitTimeout(elapsed: _stopwatch.elapsed);
    _stopwatch.stop();
    state = _toState();
  }

  void _onTick(Timer timer) {
    if (_session.gameOver ||
        _session.isCompleted ||
        _session.pendingAnswerFeedback != null ||
        _session.timeFreezeActive) {
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
    final Duration elapsed = _stopwatch.elapsed;

    return QuizSessionState(
      mode: _session.mode,
      currentQuestion: _session.currentQuestion,
      currentQuestionIndex: _session.currentIndex,
      totalQuestions: _session.totalQuestions,
      score: _session.score,
      correctAnswers: _session.correctAnswers,
      totalAnswerTime: _session.totalAnswerTime,
      elapsedForCurrentQuestion: elapsed,
      remainingForCurrentQuestion: _buildRemaining(elapsed),
      gameOver: _session.gameOver,
      isCompleted: _session.isCompleted,
      canContinueWithAd: _session.canContinueWithAd,
      continuedByAd: _session.continuedByAd,
      rankingEligible: _session.rankingEligible,
      endReason: _session.endReason,
      fiftyFiftyHintUsed: _session.fiftyFiftyHintUsed,
      canUseFiftyFiftyHint: _session.canUseFiftyFiftyHint,
      removedOptionIndexes: Set<int>.unmodifiable(
        _session.removedOptionIndexes,
      ),
      timeFreezeHintUsed: _session.timeFreezeHintUsed,
      canUseTimeFreezeHint: _session.canUseTimeFreezeHint,
      timeFreezeActive: _session.timeFreezeActive,
      isProcessing: isProcessing,
    );
  }

  Duration? _buildRemaining(Duration elapsed) {
    final int? limitSeconds = _session.mode.timeLimitSeconds;
    return limitSeconds == null
        ? null
        : Duration(
            milliseconds:
                (Duration(seconds: limitSeconds).inMilliseconds -
                        elapsed.inMilliseconds)
                    .clamp(0, 99999999),
          );
  }
}
