import 'dart:math';

import 'quiz_answer_feedback.dart';
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
  QuizAnswerFeedback? pendingAnswerFeedback;

  QuizQuestion? get currentQuestion =>
      currentIndex >= 0 && currentIndex < questions.length
      ? questions[currentIndex]
      : null;

  bool get isCompleted => endReason == QuizEndReason.completed;
  bool get canContinueWithAd =>
      gameOver && !continuedByAd && currentIndex < questions.length;

  QuizAnswerFeedback? submitAnswer({
    required int selectedIndex,
    required Duration elapsed,
    required Duration? remaining,
  }) {
    if (gameOver || isCompleted || pendingAnswerFeedback != null) {
      return null;
    }
    totalAnswerTime += elapsed;

    final QuizQuestion question = questions[currentIndex];
    final bool correct = selectedIndex == question.correctIndex;
    final QuizAnswerFeedback feedback = QuizAnswerFeedback(
      question: question,
      questionIndex: currentIndex,
      selectedIndex: selectedIndex,
      correctIndex: question.correctIndex,
      isCorrect: correct,
      remainingForQuestion: remaining,
    );
    pendingAnswerFeedback = feedback;

    return feedback;
  }

  void completePendingAnswerFeedback() {
    final QuizAnswerFeedback? feedback = pendingAnswerFeedback;
    if (feedback == null) {
      return;
    }
    pendingAnswerFeedback = null;

    if (!feedback.isCorrect) {
      _endAs(QuizEndReason.wrongAnswer);
      return;
    }

    score += 1;
    correctAnswers += 1;
    _advance();
  }

  void submitTimeout({required Duration elapsed}) {
    if (gameOver || isCompleted || pendingAnswerFeedback != null) {
      return;
    }
    totalAnswerTime += elapsed;
    _endAs(QuizEndReason.timeout);
  }

  void continueAfterAd() {
    if (!canContinueWithAd || pendingAnswerFeedback != null) {
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
    if (isCompleted || gameOver || pendingAnswerFeedback != null) {
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
    final List<QuizQuestion> questions = <QuizQuestion>[];
    for (final QuizSegment segment in mode.segments) {
      for (final _SegmentFlowPlan plan in _buildSegmentFlowPlans(segment)) {
        final List<RacerProfile> targets = _pickTargetsForCondition(
          racers: racers,
          condition: plan.step.targetCondition,
          count: plan.questionCount,
          random: random,
        );
        for (final RacerProfile target in targets) {
          questions.add(
            _buildQuestion(
              promptType: segment.promptType,
              target: target,
              racers: racers,
              optionCondition: plan.step.resolvedOptionCondition,
              random: random,
              timeLimitSeconds: mode.timeLimitSeconds,
            ),
          );
        }
      }
    }

    return QuizSession(mode: mode, questions: questions);
  }

  static QuizQuestion _buildQuestion({
    required QuizPromptType promptType,
    required RacerProfile target,
    required List<RacerProfile> racers,
    required QuizRacerCondition optionCondition,
    required Random random,
    required int? timeLimitSeconds,
  }) {
    final List<RacerProfile> candidatePool = _candidatePoolForQuestion(
      target: target,
      racers: racers,
      random: random,
      condition: optionCondition,
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

  static List<RacerProfile> _candidatePoolForQuestion({
    required RacerProfile target,
    required List<RacerProfile> racers,
    required Random random,
    required QuizRacerCondition condition,
  }) {
    final List<RacerProfile> basePool = List<RacerProfile>.from(racers)
      ..removeWhere((RacerProfile racer) => racer.id == target.id);
    final List<RacerProfile>? filteredPool = _filterRacersByCondition(
      racers: basePool,
      condition: condition,
      target: target,
      minimumCount: _requiredDistractorCount,
    );

    return _prioritizeSimilarRacers(
      target: target,
      pool: filteredPool ?? basePool,
      random: random,
    );
  }

  static List<_SegmentFlowPlan> _buildSegmentFlowPlans(QuizSegment segment) {
    final List<QuizQuestionFlowStep> flowSteps =
        segment.flowSteps == null || segment.flowSteps!.isEmpty
        ? const <QuizQuestionFlowStep>[
            QuizQuestionFlowStep(
              weight: 100,
              optionCondition: QuizRacerCondition(
                sameRacerClassAsTarget: true,
                sameGenderAsTarget: true,
              ),
            ),
          ]
        : segment.flowSteps!;

    final int totalWeight = flowSteps.fold<int>(
      0,
      (int sum, QuizQuestionFlowStep step) => sum + step.weight,
    );
    final List<_SegmentFlowPlan> plans = <_SegmentFlowPlan>[];
    final List<_SegmentFlowRemainder> remainders = <_SegmentFlowRemainder>[];
    int assigned = 0;

    for (int index = 0; index < flowSteps.length; index += 1) {
      final QuizQuestionFlowStep step = flowSteps[index];
      final double exactCount = segment.count * step.weight / totalWeight;
      final int questionCount = exactCount.floor();
      assigned += questionCount;
      plans.add(_SegmentFlowPlan(step: step, questionCount: questionCount));
      remainders.add(
        _SegmentFlowRemainder(index: index, value: exactCount - questionCount),
      );
    }

    final int remaining = segment.count - assigned;
    remainders.sort(
      (_SegmentFlowRemainder left, _SegmentFlowRemainder right) =>
          right.value.compareTo(left.value) == 0
          ? left.index.compareTo(right.index)
          : right.value.compareTo(left.value),
    );
    for (int i = 0; i < remaining; i += 1) {
      final int planIndex = remainders[i].index;
      plans[planIndex] = plans[planIndex].copyWith(
        questionCount: plans[planIndex].questionCount + 1,
      );
    }

    return plans
        .where(((_SegmentFlowPlan plan) => plan.questionCount > 0))
        .toList(growable: false);
  }

  static List<RacerProfile> _pickTargetsForCondition({
    required List<RacerProfile> racers,
    required QuizRacerCondition condition,
    required int count,
    required Random random,
  }) {
    if (count == 0) {
      return const <RacerProfile>[];
    }
    final List<RacerProfile>? filteredPool = _filterRacersByCondition(
      racers: racers,
      condition: condition,
      minimumCount: 1,
    );
    final List<RacerProfile> base = List<RacerProfile>.from(
      filteredPool ?? racers,
    )..shuffle(random);

    return <RacerProfile>[
      for (int i = 0; i < count; i += 1) base[i % base.length],
    ];
  }

  static List<RacerProfile>? _filterRacersByCondition({
    required List<RacerProfile> racers,
    required QuizRacerCondition condition,
    RacerProfile? target,
    required int minimumCount,
  }) {
    final List<RacerProfile> filtered = racers
        .where((RacerProfile racer) {
          if (!_matchesCondition(
            racer: racer,
            condition: condition,
            target: target,
          )) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
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

  static bool _matchesCondition({
    required RacerProfile racer,
    required QuizRacerCondition condition,
    RacerProfile? target,
  }) {
    if (!_matchesStringList(condition.racerClasses, racer.racerClass)) {
      return false;
    }
    if (!_matchesStringList(condition.genders, racer.gender)) {
      return false;
    }
    if (!_matchesStringList(condition.birthPlaces, racer.birthPlace)) {
      return false;
    }
    if (!_matchesStringList(condition.homeBranches, racer.homeBranch)) {
      return false;
    }
    if (!_matchesStringList(
      condition.affiliationBranches,
      racer.affiliationBranch,
    )) {
      return false;
    }
    if (!_matchesAgeRange(condition.ageRange, racer.birthDate)) {
      return false;
    }
    if (condition.sameRacerClassAsTarget &&
        target != null &&
        racer.racerClass != target.racerClass) {
      return false;
    }
    if (condition.sameGenderAsTarget &&
        target != null &&
        racer.gender != target.gender) {
      return false;
    }
    return true;
  }

  static bool _matchesStringList(List<String>? allowed, String? value) {
    if (allowed == null || allowed.isEmpty) {
      return true;
    }
    if (value == null || value.isEmpty) {
      return false;
    }
    return allowed.contains(value);
  }

  static bool _matchesAgeRange(QuizAgeRange? range, DateTime? birthDate) {
    if (range == null) {
      return true;
    }
    if (birthDate == null) {
      return false;
    }
    final DateTime now = DateTime.now().toUtc();
    int age = now.year - birthDate.year;
    final bool birthdayNotPassed =
        now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day);
    if (birthdayNotPassed) {
      age -= 1;
    }
    if (range.min != null && age < range.min!) {
      return false;
    }
    if (range.max != null && age > range.max!) {
      return false;
    }
    return true;
  }

  static const int _requiredDistractorCount = 3;
}

class _SegmentFlowPlan {
  const _SegmentFlowPlan({required this.step, required this.questionCount});

  final QuizQuestionFlowStep step;
  final int questionCount;

  _SegmentFlowPlan copyWith({int? questionCount}) {
    return _SegmentFlowPlan(
      step: step,
      questionCount: questionCount ?? this.questionCount,
    );
  }
}

class _SegmentFlowRemainder {
  const _SegmentFlowRemainder({required this.index, required this.value});

  final int index;
  final double value;
}
