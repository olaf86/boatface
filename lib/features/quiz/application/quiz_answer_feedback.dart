import '../domain/quiz_models.dart';

class QuizAnswerFeedback {
  const QuizAnswerFeedback({
    required this.question,
    required this.questionIndex,
    required this.selectedIndex,
    required this.correctIndex,
    required this.isCorrect,
    required this.remainingForQuestion,
  });

  final QuizQuestion question;
  final int questionIndex;
  final int selectedIndex;
  final int correctIndex;
  final bool isCorrect;
  final Duration? remainingForQuestion;
}
