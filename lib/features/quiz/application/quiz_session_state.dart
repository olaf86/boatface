import 'quiz_hint.dart';
import '../domain/quiz_models.dart';

class QuizSessionState {
  const QuizSessionState({
    required this.mode,
    required this.currentQuestion,
    required this.currentQuestionIndex,
    required this.totalQuestions,
    required this.score,
    required this.correctAnswers,
    required this.totalAnswerTime,
    required this.elapsedForCurrentQuestion,
    required this.remainingForCurrentQuestion,
    required this.gameOver,
    required this.isCompleted,
    required this.canContinueWithAd,
    required this.continuedByAd,
    required this.rankingEligible,
    required this.endReason,
    required this.availableHints,
    required this.hintStockCapacity,
    required this.removedOptionIndexes,
    required this.timeFreezeActive,
    required this.isProcessing,
  });

  final QuizModeConfig mode;
  final QuizQuestion? currentQuestion;
  final int currentQuestionIndex;
  final int totalQuestions;
  final int score;
  final int correctAnswers;
  final Duration totalAnswerTime;
  final Duration elapsedForCurrentQuestion;
  final Duration? remainingForCurrentQuestion;
  final bool gameOver;
  final bool isCompleted;
  final bool canContinueWithAd;
  final bool continuedByAd;
  final bool rankingEligible;
  final QuizEndReason? endReason;
  final List<QuizHintType> availableHints;
  final int hintStockCapacity;
  final Set<int> removedOptionIndexes;
  final bool timeFreezeActive;
  final bool isProcessing;

  QuizSessionState copyWith({
    QuizQuestion? currentQuestion,
    bool replaceCurrentQuestion = false,
    int? currentQuestionIndex,
    int? totalQuestions,
    int? score,
    int? correctAnswers,
    Duration? totalAnswerTime,
    Duration? elapsedForCurrentQuestion,
    Duration? remainingForCurrentQuestion,
    bool replaceRemaining = false,
    bool? gameOver,
    bool? isCompleted,
    bool? canContinueWithAd,
    bool? continuedByAd,
    bool? rankingEligible,
    QuizEndReason? endReason,
    bool replaceEndReason = false,
    List<QuizHintType>? availableHints,
    int? hintStockCapacity,
    Set<int>? removedOptionIndexes,
    bool? timeFreezeActive,
    bool? isProcessing,
  }) {
    return QuizSessionState(
      mode: mode,
      currentQuestion: replaceCurrentQuestion
          ? currentQuestion
          : (currentQuestion ?? this.currentQuestion),
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      score: score ?? this.score,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      totalAnswerTime: totalAnswerTime ?? this.totalAnswerTime,
      elapsedForCurrentQuestion:
          elapsedForCurrentQuestion ?? this.elapsedForCurrentQuestion,
      remainingForCurrentQuestion: replaceRemaining
          ? remainingForCurrentQuestion
          : (remainingForCurrentQuestion ?? this.remainingForCurrentQuestion),
      gameOver: gameOver ?? this.gameOver,
      isCompleted: isCompleted ?? this.isCompleted,
      canContinueWithAd: canContinueWithAd ?? this.canContinueWithAd,
      continuedByAd: continuedByAd ?? this.continuedByAd,
      rankingEligible: rankingEligible ?? this.rankingEligible,
      endReason: replaceEndReason ? endReason : (endReason ?? this.endReason),
      availableHints: availableHints ?? this.availableHints,
      hintStockCapacity: hintStockCapacity ?? this.hintStockCapacity,
      removedOptionIndexes: removedOptionIndexes ?? this.removedOptionIndexes,
      timeFreezeActive: timeFreezeActive ?? this.timeFreezeActive,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}
