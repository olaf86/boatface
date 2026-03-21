import 'dart:math';

import '../domain/quiz_models.dart';

class QuizSession {
  QuizSession({required this.mode, required this.questions});

  final QuizModeConfig mode;
  final List<QuizQuestion> questions;

  int currentIndex = 0;
  int score = 0;
  int correctAnswers = 0;
  Duration totalAnswerTime = Duration.zero;
  bool gameOver = false;
  bool rankingEligible = true;
  bool continuedByAd = false;
  QuizEndReason? endReason;

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
  }) {
    final Random random = Random();
    final int count = mode.questionCount;
    final List<RacerProfile> targetPool = _targetPoolForMode(mode, racers);
    final List<RacerProfile> base = List<RacerProfile>.from(targetPool)
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
            mode: mode,
            random: random,
            timeLimitSeconds: mode.timeLimitSeconds,
          ),
        );
        cursor += 1;
      }
    }

    return QuizSession(mode: mode, questions: questions);
  }

  static QuizQuestion _buildQuestion({
    required QuizPromptType promptType,
    required RacerProfile target,
    required List<RacerProfile> racers,
    required QuizModeConfig mode,
    required Random random,
    required int? timeLimitSeconds,
  }) {
    final _CandidateFilter filter = _candidateFilterForQuestion(
      mode: mode,
      target: target,
    );
    final List<RacerProfile> candidatePool = _candidatePoolForQuestion(
      target: target,
      racers: racers,
      random: random,
      racerClass: filter.racerClass,
      gender: filter.gender,
    );
    final List<RacerProfile> candidates = <RacerProfile>[
      target,
      ...candidatePool.take(3),
    ]..shuffle(random);
    final int correctIndex = candidates.indexWhere(
      (RacerProfile r) => r.id == target.id,
    );

    return QuizQuestion(
      promptType: promptType,
      prompt: _buildPrompt(promptType, target),
      promptImageUrl: _buildPromptImageUrl(promptType, target),
      promptImageLocalPath: _buildPromptImageLocalPath(promptType, target),
      promptImageReveal: _buildPromptImageReveal(
        promptType: promptType,
        random: random,
        timeLimitSeconds: timeLimitSeconds,
      ),
      options: candidates
          .map<QuizOption>(
            (RacerProfile racer) => _buildOption(promptType, racer),
          )
          .toList(growable: false),
      correctIndex: correctIndex,
      correctRacerId: target.id,
    );
  }

  static String _buildPrompt(QuizPromptType type, RacerProfile target) {
    switch (type) {
      case QuizPromptType.faceToName:
        return 'この顔の選手名は？';
      case QuizPromptType.nameToFace:
        return '「${target.name}」の顔はどれ？';
      case QuizPromptType.partialFaceToName:
        return '拡大された顔の一部から選手名を選んでください';
      case QuizPromptType.registrationToFace:
        return '登録番号 ${target.registrationNumber} の顔はどれ？';
      case QuizPromptType.faceToRegistration:
        return 'この顔の登録番号は？';
    }
  }

  static String? _buildPromptImageLocalPath(
    QuizPromptType type,
    RacerProfile target,
  ) {
    switch (type) {
      case QuizPromptType.faceToName:
      case QuizPromptType.partialFaceToName:
      case QuizPromptType.faceToRegistration:
        return target.localImagePath;
      case QuizPromptType.nameToFace:
      case QuizPromptType.registrationToFace:
        return null;
    }
  }

  static String? _buildPromptImageUrl(
    QuizPromptType type,
    RacerProfile target,
  ) {
    switch (type) {
      case QuizPromptType.faceToName:
      case QuizPromptType.partialFaceToName:
      case QuizPromptType.faceToRegistration:
        return target.imageUrl;
      case QuizPromptType.nameToFace:
      case QuizPromptType.registrationToFace:
        return null;
    }
  }

  static QuizImageReveal? _buildPromptImageReveal({
    required QuizPromptType promptType,
    required Random random,
    required int? timeLimitSeconds,
  }) {
    if (promptType != QuizPromptType.partialFaceToName) {
      return null;
    }

    final int durationMs = timeLimitSeconds == null
        ? 5000
        : (timeLimitSeconds * 650).round().clamp(3500, 7000);

    return QuizImageReveal(
      startScale: 2.2 + (random.nextDouble() * 0.8),
      startAlignmentX: (random.nextDouble() * 0.7) - 0.35,
      startAlignmentY: (random.nextDouble() * 0.45) - 0.25,
      duration: Duration(milliseconds: durationMs),
    );
  }

  static QuizOption _buildOption(QuizPromptType type, RacerProfile racer) {
    switch (type) {
      case QuizPromptType.faceToName:
      case QuizPromptType.partialFaceToName:
        return QuizOption(racerId: racer.id, label: racer.name);
      case QuizPromptType.nameToFace:
      case QuizPromptType.registrationToFace:
        return QuizOption(
          racerId: racer.id,
          label: racer.name,
          imageUrl: racer.imageUrl,
          localImagePath: racer.localImagePath,
        );
      case QuizPromptType.faceToRegistration:
        return QuizOption(
          racerId: racer.id,
          label: racer.registrationNumber.toString(),
        );
    }
  }

  static List<RacerProfile> _targetPoolForMode(
    QuizModeConfig mode,
    List<RacerProfile> racers,
  ) {
    final String? requiredRacerClass = _requiredRacerClassForMode(mode);
    if (requiredRacerClass == null) {
      return racers;
    }

    final List<RacerProfile>? filteredPool = _filterRacersByAttributes(
      racers: racers,
      racerClass: requiredRacerClass,
      minimumCount: _minimumCandidatePoolSize,
    );
    if (filteredPool != null) {
      return filteredPool;
    }

    return racers;
  }

  static List<RacerProfile> _candidatePoolForQuestion({
    required RacerProfile target,
    required List<RacerProfile> racers,
    required Random random,
    String? racerClass,
    String? gender,
  }) {
    final List<RacerProfile> basePool = List<RacerProfile>.from(racers)
      ..removeWhere((RacerProfile racer) => racer.id == target.id);
    final List<RacerProfile>? filteredPool = _filterRacersByAttributes(
      racers: basePool,
      racerClass: racerClass,
      gender: gender,
      minimumCount: _requiredDistractorCount,
    );

    return _prioritizeSimilarRacers(
      target: target,
      pool: filteredPool ?? basePool,
      random: random,
    );
  }

  static String? _requiredRacerClassForMode(QuizModeConfig mode) {
    switch (mode.id) {
      case 'quick':
        return 'A1';
      default:
        return null;
    }
  }

  static _CandidateFilter _candidateFilterForQuestion({
    required QuizModeConfig mode,
    required RacerProfile target,
  }) {
    switch (mode.id) {
      case 'quick':
        return _CandidateFilter(racerClass: 'A1', gender: target.gender);
      default:
        return _CandidateFilter(
          racerClass: target.racerClass,
          gender: target.gender,
        );
    }
  }

  static List<RacerProfile>? _filterRacersByAttributes({
    required List<RacerProfile> racers,
    String? racerClass,
    String? gender,
    required int minimumCount,
  }) {
    final List<RacerProfile> filtered = racers.where((RacerProfile racer) {
      if (racerClass != null && racer.racerClass != racerClass) {
        return false;
      }
      if (gender != null && racer.gender != gender) {
        return false;
      }
      return true;
    }).toList(growable: false);
    if (filtered.length < minimumCount) {
      return null;
    }
    return filtered;
  }

  static List<RacerProfile> _prioritizeSimilarRacers({
    required RacerProfile target,
    required List<RacerProfile> pool,
    required Random random,
  }) {
    final List<RacerProfile> exactMatches = <RacerProfile>[];
    final List<RacerProfile> sameClass = <RacerProfile>[];
    final List<RacerProfile> sameGender = <RacerProfile>[];
    final List<RacerProfile> rest = <RacerProfile>[];

    for (final RacerProfile racer in pool) {
      final bool matchesClass = racer.racerClass == target.racerClass;
      final bool matchesGender = racer.gender == target.gender;

      if (matchesClass && matchesGender) {
        exactMatches.add(racer);
      } else if (matchesClass) {
        sameClass.add(racer);
      } else if (matchesGender) {
        sameGender.add(racer);
      } else {
        rest.add(racer);
      }
    }

    exactMatches.shuffle(random);
    sameClass.shuffle(random);
    sameGender.shuffle(random);
    rest.shuffle(random);

    return <RacerProfile>[
      ...exactMatches,
      ...sameClass,
      ...sameGender,
      ...rest,
    ];
  }

  static const int _requiredDistractorCount = 3;
  static const int _minimumCandidatePoolSize = _requiredDistractorCount + 1;
}

class _CandidateFilter {
  const _CandidateFilter({this.racerClass, this.gender});

  final String? racerClass;
  final String? gender;
}
