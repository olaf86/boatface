import 'dart:math';

import 'quiz_answer_feedback.dart';
import 'quiz_hint.dart';
import '../domain/quiz_models.dart';

class QuizSession {
  QuizSession._internal({
    required this.mode,
    required List<_QuizPlanSlot> planSlots,
    required List<RacerProfile> racers,
    Random? random,
  }) : _planSlots = planSlots,
       _racers = racers,
       _random = random ?? Random() {
    _hintStock.addAll(_buildInitialHintStock(mode));
    if (_planSlots.isNotEmpty) {
      _startQuestionForCurrentSlot();
    }
  }

  final QuizModeConfig mode;
  final List<_QuizPlanSlot> _planSlots;
  final List<RacerProfile> _racers;
  final Random _random;
  final List<QuizQuestionRecord> _questionHistory = <QuizQuestionRecord>[];
  final Set<String> _usedTargetIds = <String>{};
  final List<QuizHintItem> _hintStock = <QuizHintItem>[];
  int _nextHintId = 0;

  int currentIndex = 0;
  int score = 0;
  int correctAnswers = 0;
  Duration totalAnswerTime = Duration.zero;
  bool gameOver = false;
  bool rankingEligible = true;
  bool continuedByAd = false;
  bool timeFreezeActive = false;
  Set<int> removedOptionIndexes = <int>{};
  QuizEndReason? endReason;
  DateTime? clientFinishedAt;
  QuizAnswerFeedback? pendingAnswerFeedback;
  QuizQuestion? _currentQuestion;

  int get totalQuestions => _planSlots.length;
  QuizQuestion? get currentQuestion => _currentQuestion;
  List<QuizHintItem> get hintStock =>
      List<QuizHintItem>.unmodifiable(_hintStock);
  List<QuizQuestionRecord> get questionHistory =>
      List<QuizQuestionRecord>.unmodifiable(_questionHistory);

  bool get isCompleted => endReason == QuizEndReason.completed;
  bool get canContinueWithAd =>
      gameOver && !continuedByAd && currentIndex < totalQuestions;
  bool get canUseFiftyFiftyHint =>
      _hintStock.any(
        (QuizHintItem item) => item.type == QuizHintType.fiftyFifty,
      ) &&
      !gameOver &&
      !isCompleted &&
      pendingAnswerFeedback == null &&
      currentQuestion != null &&
      removedOptionIndexes.isEmpty;
  bool get canUseTimeFreezeHint =>
      mode.timeLimitSeconds != null &&
      _hintStock.any(
        (QuizHintItem item) => item.type == QuizHintType.timeFreeze,
      ) &&
      !timeFreezeActive &&
      !gameOver &&
      !isCompleted &&
      pendingAnswerFeedback == null;

  QuizAnswerFeedback? submitAnswer({
    required int selectedIndex,
    required Duration elapsed,
    required Duration? remaining,
  }) {
    if (gameOver || isCompleted || pendingAnswerFeedback != null) {
      return null;
    }
    totalAnswerTime += elapsed;

    final QuizQuestion question = currentQuestion!;
    final bool correct = selectedIndex == question.correctIndex;
    final QuizAnswerFeedback feedback = QuizAnswerFeedback(
      question: question,
      questionIndex: currentIndex,
      selectedIndex: selectedIndex,
      correctIndex: question.correctIndex,
      isCorrect: correct,
      remainingForQuestion: remaining,
    );
    _updateCurrentRecord(
      (QuizQuestionRecord record) => record.copyWith(
        selectedIndex: selectedIndex,
        elapsed: elapsed,
        remainingForQuestion: remaining,
        outcome: correct
            ? QuizQuestionOutcome.correct
            : QuizQuestionOutcome.wrongAnswer,
      ),
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
    _awardHintForMilestone();
    _advance();
  }

  bool useFiftyFiftyHint() {
    final QuizHintItem? item = _firstHintOfType(QuizHintType.fiftyFifty);
    if (item == null) {
      return false;
    }
    return useHint(item.id);
  }

  bool useTimeFreezeHint() {
    final QuizHintItem? item = _firstHintOfType(QuizHintType.timeFreeze);
    if (item == null) {
      return false;
    }
    return useHint(item.id);
  }

  bool useHint(String hintId) {
    final QuizHintItem? hint = _hintById(hintId);
    if (hint == null) {
      return false;
    }
    return switch (hint.type) {
      QuizHintType.fiftyFifty => _useFiftyFiftyHint(hint.id),
      QuizHintType.timeFreeze => _useTimeFreezeHint(hint.id),
    };
  }

  bool _useFiftyFiftyHint(String hintId) {
    if (!canUseFiftyFiftyHint) {
      return false;
    }
    final QuizQuestion question = currentQuestion!;
    final List<int> wrongIndexes = <int>[
      for (int index = 0; index < question.options.length; index += 1)
        if (index != question.correctIndex) index,
    ];
    if (wrongIndexes.length <= 1) {
      return false;
    }

    removedOptionIndexes = wrongIndexes.skip(1).toSet();
    _consumeHint(hintId);
    return true;
  }

  bool _useTimeFreezeHint(String hintId) {
    if (!canUseTimeFreezeHint) {
      return false;
    }
    _consumeHint(hintId);
    timeFreezeActive = true;
    return true;
  }

  void submitTimeout({required Duration elapsed}) {
    if (gameOver || isCompleted || pendingAnswerFeedback != null) {
      return;
    }
    totalAnswerTime += elapsed;
    _markCurrentRecordIfPending(QuizQuestionOutcome.timeout, elapsed: elapsed);
    _endAs(QuizEndReason.timeout);
  }

  void continueAfterAd() {
    if (!canContinueWithAd || pendingAnswerFeedback != null) {
      return;
    }
    continuedByAd = true;
    gameOver = false;
    endReason = null;
    clientFinishedAt = null;
    _resetQuestionScopedHints();
    _startQuestionForCurrentSlot();
  }

  void abandon() {
    if (isCompleted || gameOver || pendingAnswerFeedback != null) {
      return;
    }
    rankingEligible = false;
    _markCurrentRecordIfPending(
      QuizQuestionOutcome.abandoned,
      elapsed: _currentRecord?.elapsed ?? Duration.zero,
    );
    _endAs(QuizEndReason.abandoned);
  }

  QuizResultSummary toSummary() {
    return QuizResultSummary(
      modeId: mode.id,
      modeLabel: mode.label,
      score: score,
      correctAnswers: correctAnswers,
      totalQuestions: totalQuestions,
      totalAnswerTime: totalAnswerTime,
      endReason: endReason ?? QuizEndReason.completed,
      rankingEligible: rankingEligible,
      continuedByAd: continuedByAd,
      clientFinishedAt: clientFinishedAt ?? DateTime.now(),
      mistakes: _buildMistakeSnapshots(),
    );
  }

  void _advance() {
    _resetQuestionScopedHints();
    currentIndex += 1;
    if (currentIndex >= totalQuestions) {
      _currentQuestion = null;
      endReason = QuizEndReason.completed;
      clientFinishedAt = DateTime.now();
      return;
    }
    _startQuestionForCurrentSlot();
  }

  void _endAs(QuizEndReason reason) {
    timeFreezeActive = false;
    gameOver = true;
    endReason = reason;
    clientFinishedAt = DateTime.now();
  }

  void _resetQuestionScopedHints() {
    removedOptionIndexes = <int>{};
    timeFreezeActive = false;
  }

  QuizHintItem? _firstHintOfType(QuizHintType type) {
    for (final QuizHintItem item in _hintStock) {
      if (item.type == type) {
        return item;
      }
    }
    return null;
  }

  QuizHintItem? _hintById(String hintId) {
    for (final QuizHintItem item in _hintStock) {
      if (item.id == hintId) {
        return item;
      }
    }
    return null;
  }

  void _consumeHint(String hintId) {
    final int index = _hintStock.indexWhere(
      (QuizHintItem item) => item.id == hintId,
    );
    if (index >= 0) {
      _hintStock.removeAt(index);
    }
  }

  void _awardHintForMilestone() {
    if (!_supportsMilestoneHintReward ||
        correctAnswers == 0 ||
        correctAnswers % 10 != 0 ||
        _hintStock.length >= kQuizHintStockCapacity) {
      return;
    }

    final List<QuizHintType> rewardCandidates = _buildRewardHintCandidates();
    if (rewardCandidates.isEmpty) {
      return;
    }

    _hintStock.add(
      _createHintItem(
        rewardCandidates[_random.nextInt(rewardCandidates.length)],
      ),
    );
  }

  bool get _supportsMilestoneHintReward =>
      mode.id == 'challenge' || mode.id == 'master';

  List<QuizHintType> _buildRewardHintCandidates() {
    return <QuizHintType>[
      QuizHintType.fiftyFifty,
      if (mode.timeLimitSeconds != null) QuizHintType.timeFreeze,
    ];
  }

  List<QuizHintItem> _buildInitialHintStock(QuizModeConfig mode) {
    if (mode.id == 'careful') {
      return <QuizHintType>[
        QuizHintType.fiftyFifty,
        QuizHintType.fiftyFifty,
        QuizHintType.fiftyFifty,
      ].map(_createHintItem).toList(growable: false);
    }
    return <QuizHintType>[
      QuizHintType.fiftyFifty,
      if (mode.timeLimitSeconds != null) QuizHintType.timeFreeze,
    ].take(kQuizHintStockCapacity).map(_createHintItem).toList(growable: false);
  }

  QuizHintItem _createHintItem(QuizHintType type) {
    final String id = 'hint-${_nextHintId++}';
    return QuizHintItem(id: id, type: type);
  }

  QuizQuestionRecord? get _currentRecord =>
      _questionHistory.isEmpty ? null : _questionHistory.last;

  void _startQuestionForCurrentSlot() {
    final _QuizPlanSlot slot = _planSlots[currentIndex];
    final QuizQuestion question = QuizSessionFactory._generateQuestion(
      promptType: slot.promptType,
      questionIndex: currentIndex,
      totalQuestionCount: _planSlots.length,
      racers: _racers,
      targetCondition: slot.targetCondition,
      optionCondition: slot.optionCondition,
      excludedTargetIds: _usedTargetIds,
      random: _random,
    );
    _currentQuestion = question;
    _usedTargetIds.add(question.correctRacerId);
    _questionHistory.add(
      QuizQuestionRecord(slotIndex: currentIndex, question: question),
    );
  }

  void _updateCurrentRecord(
    QuizQuestionRecord Function(QuizQuestionRecord record) update,
  ) {
    if (_questionHistory.isEmpty) {
      return;
    }
    _questionHistory[_questionHistory.length - 1] = update(
      _questionHistory.last,
    );
  }

  void _markCurrentRecordIfPending(
    QuizQuestionOutcome outcome, {
    required Duration elapsed,
  }) {
    final QuizQuestionRecord? currentRecord = _currentRecord;
    if (currentRecord == null || currentRecord.outcome != null) {
      return;
    }
    _updateCurrentRecord(
      (QuizQuestionRecord record) =>
          record.copyWith(elapsed: elapsed, outcome: outcome),
    );
  }

  List<QuizMistakeSnapshot> _buildMistakeSnapshots() {
    final List<QuizMistakeSnapshot> mistakes = <QuizMistakeSnapshot>[];
    for (final QuizQuestionRecord record in _questionHistory) {
      final QuizMistakeOutcome? mistakeOutcome = _mapMistakeOutcome(
        record.outcome,
      );
      if (mistakeOutcome == null) {
        continue;
      }

      final QuizQuestion question = record.question;
      final int? selectedIndex = record.selectedIndex;
      mistakes.add(
        QuizMistakeSnapshot(
          questionIndex: record.slotIndex,
          mistakeSequence: mistakes.length,
          promptType: question.promptType,
          prompt: question.prompt,
          promptImageUrl: question.promptImageUrl,
          options: question.options
              .map(
                (QuizOption option) => QuizMistakeOptionSnapshot(
                  racerId: option.racerId,
                  label: option.label,
                  labelReading: option.labelReading,
                  imageUrl: option.imageUrl,
                ),
              )
              .toList(growable: false),
          correctIndex: question.correctIndex,
          selectedIndex: selectedIndex,
          correctRacerId: question.correctRacerId,
          selectedRacerId: selectedIndex == null
              ? null
              : question.options[selectedIndex].racerId,
          elapsed: record.elapsed,
          outcome: mistakeOutcome,
        ),
      );
    }

    return List<QuizMistakeSnapshot>.unmodifiable(mistakes);
  }

  QuizMistakeOutcome? _mapMistakeOutcome(QuizQuestionOutcome? outcome) {
    return switch (outcome) {
      QuizQuestionOutcome.wrongAnswer => QuizMistakeOutcome.wrongAnswer,
      QuizQuestionOutcome.timeout => QuizMistakeOutcome.timeout,
      QuizQuestionOutcome.abandoned => QuizMistakeOutcome.abandoned,
      QuizQuestionOutcome.correct || null => null,
    };
  }
}

enum QuizQuestionOutcome { correct, wrongAnswer, timeout, abandoned }

class QuizQuestionRecord {
  const QuizQuestionRecord({
    required this.slotIndex,
    required this.question,
    this.selectedIndex,
    this.elapsed = Duration.zero,
    this.remainingForQuestion,
    this.outcome,
  });

  final int slotIndex;
  final QuizQuestion question;
  final int? selectedIndex;
  final Duration elapsed;
  final Duration? remainingForQuestion;
  final QuizQuestionOutcome? outcome;

  QuizQuestionRecord copyWith({
    int? selectedIndex,
    bool replaceSelectedIndex = false,
    Duration? elapsed,
    Duration? remainingForQuestion,
    bool replaceRemaining = false,
    QuizQuestionOutcome? outcome,
    bool replaceOutcome = false,
  }) {
    return QuizQuestionRecord(
      slotIndex: slotIndex,
      question: question,
      selectedIndex: replaceSelectedIndex
          ? selectedIndex
          : (selectedIndex ?? this.selectedIndex),
      elapsed: elapsed ?? this.elapsed,
      remainingForQuestion: replaceRemaining
          ? remainingForQuestion
          : (remainingForQuestion ?? this.remainingForQuestion),
      outcome: replaceOutcome ? outcome : (outcome ?? this.outcome),
    );
  }
}

class QuizSessionFactory {
  static QuizSession create({
    required QuizModeConfig mode,
    required List<RacerProfile> racers,
    Random? random,
  }) {
    final Random resolvedRandom = random ?? Random();
    final List<_QuizPlanSlot> planSlots = <_QuizPlanSlot>[];
    for (final QuizSegment segment in mode.segments) {
      for (final _SegmentFlowPlan plan in _buildSegmentFlowPlans(segment)) {
        for (int i = 0; i < plan.questionCount; i += 1) {
          planSlots.add(
            _QuizPlanSlot(
              promptType: segment.promptType,
              targetCondition: plan.step.targetCondition,
              optionCondition: plan.step.resolvedOptionCondition,
            ),
          );
        }
      }
    }

    return QuizSession._internal(
      mode: mode,
      planSlots: planSlots,
      racers: racers,
      random: resolvedRandom,
    );
  }

  static QuizQuestion _generateQuestion({
    required QuizPromptType promptType,
    required int questionIndex,
    required int totalQuestionCount,
    required List<RacerProfile> racers,
    required QuizRacerCondition targetCondition,
    required QuizRacerCondition optionCondition,
    required Set<String> excludedTargetIds,
    required Random random,
  }) {
    final RacerProfile target = _pickTargetForQuestion(
      racers: racers,
      condition: targetCondition,
      excludedTargetIds: excludedTargetIds,
      random: random,
    );
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

    final PartialFaceVariant? partialFaceVariant =
        promptType == QuizPromptType.partialFaceToName
        ? _pickPartialFaceVariant(
            questionIndex: questionIndex,
            totalQuestionCount: totalQuestionCount,
            random: random,
          )
        : null;

    return QuizQuestion(
      promptType: promptType,
      prompt: _buildPrompt(promptType, target),
      promptImageUrl: _buildPromptImageUrl(promptType, target),
      promptImageLocalPath: _buildPromptImageLocalPath(promptType, target),
      partialFaceVariant: partialFaceVariant,
      promptVisualSpec: _buildPromptVisualSpec(
        promptType: promptType,
        partialFaceVariant: partialFaceVariant,
        random: random,
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

  static RacerProfile _pickTargetForQuestion({
    required List<RacerProfile> racers,
    required QuizRacerCondition condition,
    required Set<String> excludedTargetIds,
    required Random random,
  }) {
    final List<RacerProfile> availablePool = racers
        .where((RacerProfile racer) => !excludedTargetIds.contains(racer.id))
        .toList(growable: false);
    final List<RacerProfile>? filteredAvailablePool = availablePool.isEmpty
        ? null
        : _filterRacersByCondition(
            racers: availablePool,
            condition: condition,
            minimumCount: 1,
          );
    final List<RacerProfile> targetPool =
        filteredAvailablePool == null || filteredAvailablePool.isEmpty
        ? (_filterRacersByCondition(
                racers: racers,
                condition: condition,
                minimumCount: 1,
              ) ??
              racers)
        : filteredAvailablePool;
    final List<RacerProfile> shuffledPool = List<RacerProfile>.from(targetPool)
      ..shuffle(random);
    return shuffledPool.first;
  }

  static String _buildPrompt(QuizPromptType type, RacerProfile target) {
    switch (type) {
      case QuizPromptType.faceToName:
        return 'この顔の選手名は？';
      case QuizPromptType.nameToFace:
        return 'の顔はどれ？';
      case QuizPromptType.partialFaceToName:
        return 'この顔の選手名は？';
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

  static QuizPromptVisualSpec? _buildPromptVisualSpec({
    required QuizPromptType promptType,
    required PartialFaceVariant? partialFaceVariant,
    required Random random,
  }) {
    if (promptType != QuizPromptType.partialFaceToName ||
        partialFaceVariant == null) {
      return null;
    }

    switch (partialFaceVariant) {
      case PartialFaceVariant.zoomOutCenter:
        return QuizZoomOutCenterVisualSpec(
          startScale: 1.9 + (random.nextDouble() * 0.5),
          startAlignmentX: (random.nextDouble() * 0.24) - 0.12,
          startAlignmentY: (random.nextDouble() * 0.18) - 0.09,
        );
      case PartialFaceVariant.slidingWindow:
        final bool diagonal = random.nextBool();
        final double startX = random.nextBool() ? -0.72 : 0.72;
        final double startY = diagonal
            ? (random.nextBool() ? -0.68 : 0.68)
            : ((random.nextDouble() * 0.44) - 0.22);
        final double endX = -startX;
        final double endY = diagonal ? -startY : startY;
        return QuizSlidingWindowVisualSpec(
          windowWidthFactor: 0.34 + (random.nextDouble() * 0.08),
          windowHeightFactor: 0.34 + (random.nextDouble() * 0.08),
          startAlignmentX: startX,
          startAlignmentY: startY,
          endAlignmentX: endX,
          endAlignmentY: endY,
        );
      case PartialFaceVariant.tileReveal:
        final int tileRows = random.nextBool() ? 3 : 4;
        final int tileColumns = 4;
        final List<int> revealOrder = List<int>.generate(
          tileRows * tileColumns,
          (int index) => index,
        )..shuffle(random);
        return QuizTileRevealVisualSpec(
          tileRows: tileRows,
          tileColumns: tileColumns,
          revealOrder: List<int>.unmodifiable(revealOrder),
          initialVisibleTileCount: 0,
        );
    }
  }

  static PartialFaceVariant _pickPartialFaceVariant({
    required int questionIndex,
    required int totalQuestionCount,
    required Random random,
  }) {
    final double progress = totalQuestionCount <= 1
        ? 1
        : questionIndex / (totalQuestionCount - 1);
    final List<_PartialFaceVariantWeight> weights = progress < 1 / 3
        ? const <_PartialFaceVariantWeight>[
            _PartialFaceVariantWeight(
              variant: PartialFaceVariant.zoomOutCenter,
              weight: 60,
            ),
            _PartialFaceVariantWeight(
              variant: PartialFaceVariant.slidingWindow,
              weight: 30,
            ),
            _PartialFaceVariantWeight(
              variant: PartialFaceVariant.tileReveal,
              weight: 10,
            ),
          ]
        : progress < 2 / 3
        ? const <_PartialFaceVariantWeight>[
            _PartialFaceVariantWeight(
              variant: PartialFaceVariant.zoomOutCenter,
              weight: 35,
            ),
            _PartialFaceVariantWeight(
              variant: PartialFaceVariant.slidingWindow,
              weight: 40,
            ),
            _PartialFaceVariantWeight(
              variant: PartialFaceVariant.tileReveal,
              weight: 25,
            ),
          ]
        : const <_PartialFaceVariantWeight>[
            _PartialFaceVariantWeight(
              variant: PartialFaceVariant.zoomOutCenter,
              weight: 15,
            ),
            _PartialFaceVariantWeight(
              variant: PartialFaceVariant.slidingWindow,
              weight: 35,
            ),
            _PartialFaceVariantWeight(
              variant: PartialFaceVariant.tileReveal,
              weight: 50,
            ),
          ];
    final int totalWeight = weights.fold<int>(
      0,
      (int sum, _PartialFaceVariantWeight entry) => sum + entry.weight,
    );
    int threshold = random.nextInt(totalWeight);
    for (final _PartialFaceVariantWeight entry in weights) {
      threshold -= entry.weight;
      if (threshold < 0) {
        return entry.variant;
      }
    }
    return weights.last.variant;
  }

  static QuizOption _buildOption(QuizPromptType type, RacerProfile racer) {
    switch (type) {
      case QuizPromptType.faceToName:
      case QuizPromptType.partialFaceToName:
        return QuizOption(
          racerId: racer.id,
          label: racer.name,
          labelReading: racer.nameKana,
        );
      case QuizPromptType.nameToFace:
      case QuizPromptType.registrationToFace:
        return QuizOption(
          racerId: racer.id,
          label: racer.name,
          labelReading: racer.nameKana,
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

class _PartialFaceVariantWeight {
  const _PartialFaceVariantWeight({
    required this.variant,
    required this.weight,
  });

  final PartialFaceVariant variant;
  final int weight;
}

class _SegmentFlowRemainder {
  const _SegmentFlowRemainder({required this.index, required this.value});

  final int index;
  final double value;
}

class _QuizPlanSlot {
  const _QuizPlanSlot({
    required this.promptType,
    required this.targetCondition,
    required this.optionCondition,
  });

  final QuizPromptType promptType;
  final QuizRacerCondition targetCondition;
  final QuizRacerCondition optionCondition;
}
