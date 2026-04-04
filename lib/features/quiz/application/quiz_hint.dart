enum QuizHintType { fiftyFifty, timeFreeze }

class QuizHintItem {
  const QuizHintItem({required this.id, required this.type});

  final String id;
  final QuizHintType type;
}

const int kQuizHintStockCapacity = 4;
