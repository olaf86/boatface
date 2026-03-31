import '../../quiz/domain/quiz_models.dart';

class ReviewMistakeOption {
  const ReviewMistakeOption({
    required this.racerId,
    required this.label,
    this.labelReading,
    this.imageUrl,
  });

  final String racerId;
  final String label;
  final String? labelReading;
  final String? imageUrl;

  static ReviewMistakeOption? tryParseJson(Object? value) {
    if (value is! Map<Object?, Object?>) {
      return null;
    }

    final String? racerId = value['racerId'] as String?;
    final String? label = value['label'] as String?;
    if (racerId == null || racerId.isEmpty || label == null || label.isEmpty) {
      return null;
    }

    return ReviewMistakeOption(
      racerId: racerId,
      label: label,
      labelReading: value['labelReading'] as String?,
      imageUrl: value['imageUrl'] as String?,
    );
  }
}

class ReviewMistakeEntry {
  const ReviewMistakeEntry({
    required this.mistakeId,
    required this.resultId,
    required this.sessionId,
    required this.modeId,
    required this.modeLabel,
    required this.questionIndex,
    required this.mistakeSequence,
    required this.promptType,
    required this.prompt,
    this.promptImageUrl,
    required this.options,
    required this.correctIndex,
    this.selectedIndex,
    required this.correctRacerId,
    this.selectedRacerId,
    required this.correctOption,
    this.selectedOption,
    required this.elapsedMs,
    required this.outcome,
    required this.createdAt,
  });

  final String mistakeId;
  final String resultId;
  final String sessionId;
  final String modeId;
  final String modeLabel;
  final int questionIndex;
  final int mistakeSequence;
  final QuizPromptType promptType;
  final String prompt;
  final String? promptImageUrl;
  final List<ReviewMistakeOption> options;
  final int correctIndex;
  final int? selectedIndex;
  final String correctRacerId;
  final String? selectedRacerId;
  final ReviewMistakeOption correctOption;
  final ReviewMistakeOption? selectedOption;
  final int elapsedMs;
  final QuizMistakeOutcome outcome;
  final DateTime createdAt;

  static ReviewMistakeEntry? tryParseJson(Object? value) {
    if (value is! Map<Object?, Object?>) {
      return null;
    }

    final String? mistakeId = value['mistakeId'] as String?;
    final String? resultId = value['resultId'] as String?;
    final String? sessionId = value['sessionId'] as String?;
    final String? modeId = value['modeId'] as String?;
    final String? modeLabel = value['modeLabel'] as String?;
    final int? questionIndex = value['questionIndex'] as int?;
    final int? mistakeSequence = value['mistakeSequence'] as int?;
    final QuizPromptType? promptType = _parsePromptType(
      value['promptType'] as String?,
    );
    final String? prompt = value['prompt'] as String?;
    final int? correctIndex = value['correctIndex'] as int?;
    final int? selectedIndex = value['selectedIndex'] as int?;
    final String? correctRacerId = value['correctRacerId'] as String?;
    final String? selectedRacerId = value['selectedRacerId'] as String?;
    final ReviewMistakeOption? correctOption = ReviewMistakeOption.tryParseJson(
      value['correctOption'],
    );
    final ReviewMistakeOption? selectedOption =
        ReviewMistakeOption.tryParseJson(value['selectedOption']);
    final int? elapsedMs = value['elapsedMs'] as int?;
    final QuizMistakeOutcome? outcome = _parseOutcome(
      value['outcome'] as String?,
    );
    final DateTime? createdAt = DateTime.tryParse(
      value['createdAt'] as String? ?? '',
    )?.toLocal();
    final Object? optionsValue = value['options'];
    if (mistakeId == null ||
        resultId == null ||
        sessionId == null ||
        modeId == null ||
        modeLabel == null ||
        questionIndex == null ||
        mistakeSequence == null ||
        promptType == null ||
        prompt == null ||
        correctIndex == null ||
        correctRacerId == null ||
        correctOption == null ||
        elapsedMs == null ||
        outcome == null ||
        createdAt == null ||
        optionsValue is! List<Object?>) {
      return null;
    }

    final List<ReviewMistakeOption> options = optionsValue
        .map(ReviewMistakeOption.tryParseJson)
        .whereType<ReviewMistakeOption>()
        .toList(growable: false);
    if (options.length != optionsValue.length) {
      return null;
    }

    return ReviewMistakeEntry(
      mistakeId: mistakeId,
      resultId: resultId,
      sessionId: sessionId,
      modeId: modeId,
      modeLabel: modeLabel,
      questionIndex: questionIndex,
      mistakeSequence: mistakeSequence,
      promptType: promptType,
      prompt: prompt,
      promptImageUrl: value['promptImageUrl'] as String?,
      options: options,
      correctIndex: correctIndex,
      selectedIndex: selectedIndex,
      correctRacerId: correctRacerId,
      selectedRacerId: selectedRacerId,
      correctOption: correctOption,
      selectedOption: selectedOption,
      elapsedMs: elapsedMs,
      outcome: outcome,
      createdAt: createdAt,
    );
  }
}

QuizPromptType? _parsePromptType(String? value) {
  return switch (value) {
    'faceToName' => QuizPromptType.faceToName,
    'nameToFace' => QuizPromptType.nameToFace,
    'partialFaceToName' => QuizPromptType.partialFaceToName,
    'registrationToFace' => QuizPromptType.registrationToFace,
    'faceToRegistration' => QuizPromptType.faceToRegistration,
    _ => null,
  };
}

QuizMistakeOutcome? _parseOutcome(String? value) {
  return switch (value) {
    'wrongAnswer' => QuizMistakeOutcome.wrongAnswer,
    'timeout' => QuizMistakeOutcome.timeout,
    'abandoned' => QuizMistakeOutcome.abandoned,
    _ => null,
  };
}
