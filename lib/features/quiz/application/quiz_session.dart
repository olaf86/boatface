import 'dart:math';

import '../domain/quiz_models.dart';

class QuizSession {
  QuizSession({
    required this.mode,
    required this.problemSetVersion,
    required this.seed,
    required this.questions,
  });

  final QuizModeConfig mode;
  final String problemSetVersion;
  final int seed;
  final List<QuizQuestion> questions;

  int currentIndex = 0;
  int score = 0;
  int correctAnswers = 0;
  Duration totalAnswerTime = Duration.zero;
  bool gameOver = false;
  bool rankingEligible = true;
  bool continuedByAd = false;
  QuizEndReason? endReason;

  String get seedToken => '$problemSetVersion-$seed';

  QuizQuestion? get currentQuestion =>
      currentIndex >= 0 && currentIndex < questions.length
      ? questions[currentIndex]
      : null;

  bool get isCompleted => endReason == QuizEndReason.completed;
  bool get canContinueWithAd =>
      gameOver && !continuedByAd && currentIndex < questions.length;

  void submitAnswer({required int selectedIndex, required Duration elapsed}) {
    if (gameOver || isCompleted) {
      return;
    }
    totalAnswerTime += elapsed;

    final QuizQuestion question = questions[currentIndex];
    final bool correct = selectedIndex == question.correctIndex;

    if (!correct) {
      _endAs(QuizEndReason.wrongAnswer);
      return;
    }

    score += 1;
    correctAnswers += 1;
    _advance();
  }

  void submitTimeout({required Duration elapsed}) {
    if (gameOver || isCompleted) {
      return;
    }
    totalAnswerTime += elapsed;
    _endAs(QuizEndReason.timeout);
  }

  void continueAfterAd() {
    if (!canContinueWithAd) {
      return;
    }
    continuedByAd = true;
    gameOver = false;
    endReason = null;
    currentIndex += 1;
    if (currentIndex >= questions.length) {
      endReason = QuizEndReason.completed;
    }
  }

  void abandon() {
    if (isCompleted || gameOver) {
      return;
    }
    rankingEligible = false;
    _endAs(QuizEndReason.abandoned);
  }

  QuizResultSummary toSummary() {
    return QuizResultSummary(
      modeId: mode.id,
      modeLabel: mode.label,
      score: score,
      correctAnswers: correctAnswers,
      totalQuestions: questions.length,
      totalAnswerTime: totalAnswerTime,
      seedToken: seedToken,
      endReason: endReason ?? QuizEndReason.completed,
      rankingEligible: rankingEligible,
      continuedByAd: continuedByAd,
    );
  }

  void _advance() {
    currentIndex += 1;
    if (currentIndex >= questions.length) {
      endReason = QuizEndReason.completed;
    }
  }

  void _endAs(QuizEndReason reason) {
    gameOver = true;
    endReason = reason;
  }
}

class QuizSessionFactory {
  static QuizSession create({
    required QuizModeConfig mode,
    required List<RacerProfile> racers,
    required String problemSetVersion,
    int? seed,
  }) {
    final int resolvedSeed = seed ?? DateTime.now().millisecondsSinceEpoch;
    final Random random = Random(resolvedSeed);
    final int count = mode.questionCount;
    final List<RacerProfile> base = List<RacerProfile>.from(racers)
      ..shuffle(random);
    final List<RacerProfile> picked = <RacerProfile>[
      for (int i = 0; i < count; i++) base[i % base.length],
    ];

    final List<QuizQuestion> questions = <QuizQuestion>[];
    int cursor = 0;
    for (final QuizSegment segment in mode.segments) {
      for (int i = 0; i < segment.count; i++) {
        final RacerProfile target = picked[cursor];
        questions.add(
          _buildQuestion(
            promptType: segment.promptType,
            target: target,
            racers: racers,
            random: random,
          ),
        );
        cursor += 1;
      }
    }

    return QuizSession(
      mode: mode,
      problemSetVersion: problemSetVersion,
      seed: resolvedSeed,
      questions: questions,
    );
  }

  static QuizQuestion _buildQuestion({
    required QuizPromptType promptType,
    required RacerProfile target,
    required List<RacerProfile> racers,
    required Random random,
  }) {
    final List<RacerProfile> pool = List<RacerProfile>.from(racers)
      ..removeWhere((RacerProfile r) => r.id == target.id)
      ..shuffle(random);
    final List<RacerProfile> candidates = <RacerProfile>[
      target,
      ...pool.take(3),
    ]..shuffle(random);
    final int correctIndex = candidates.indexWhere(
      (RacerProfile r) => r.id == target.id,
    );

    return QuizQuestion(
      promptType: promptType,
      prompt: _buildPrompt(promptType, target),
      options: candidates
          .map<String>(
            (RacerProfile racer) => _buildOptionLabel(promptType, racer),
          )
          .toList(growable: false),
      correctIndex: correctIndex,
      correctRacerId: target.id,
    );
  }

  static String _buildPrompt(QuizPromptType type, RacerProfile target) {
    switch (type) {
      case QuizPromptType.faceToName:
        return 'この顔の選手名は？ (${target.faceLabel})';
      case QuizPromptType.nameToFace:
        return '「${target.name}」の顔はどれ？';
      case QuizPromptType.partialFaceToName:
        return '拡大された顔の一部から選手名を選んでください (${target.faceLabel})';
      case QuizPromptType.registrationToFace:
        return '登録番号 ${target.registrationNumber} の顔はどれ？';
      case QuizPromptType.faceToRegistration:
        return 'この顔の登録番号は？ (${target.faceLabel})';
    }
  }

  static String _buildOptionLabel(QuizPromptType type, RacerProfile racer) {
    switch (type) {
      case QuizPromptType.faceToName:
      case QuizPromptType.partialFaceToName:
        return racer.name;
      case QuizPromptType.nameToFace:
      case QuizPromptType.registrationToFace:
        return racer.faceLabel;
      case QuizPromptType.faceToRegistration:
        return racer.registrationNumber.toString();
    }
  }
}
