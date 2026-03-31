enum QuizPromptType {
  faceToName,
  nameToFace,
  partialFaceToName,
  registrationToFace,
  faceToRegistration,
}

enum QuizEndReason { completed, wrongAnswer, timeout, abandoned }

class QuizSegment {
  const QuizSegment({
    required this.promptType,
    required this.count,
    this.flowSteps,
  });

  final QuizPromptType promptType;
  final int count;
  final List<QuizQuestionFlowStep>? flowSteps;

  QuizSegment copyWith({
    QuizPromptType? promptType,
    int? count,
    List<QuizQuestionFlowStep>? flowSteps,
  }) {
    return QuizSegment(
      promptType: promptType ?? this.promptType,
      count: count ?? this.count,
      flowSteps: flowSteps ?? this.flowSteps,
    );
  }
}

class QuizQuestionFlowStep {
  const QuizQuestionFlowStep({
    required this.weight,
    this.targetCondition = const QuizRacerCondition(),
    this.optionCondition,
  });

  final int weight;
  final QuizRacerCondition targetCondition;
  final QuizRacerCondition? optionCondition;

  QuizRacerCondition get resolvedOptionCondition =>
      optionCondition ?? targetCondition;
}

class QuizRacerCondition {
  const QuizRacerCondition({
    this.racerClasses,
    this.genders,
    this.ageRange,
    this.birthPlaces,
    this.homeBranches,
    this.affiliationBranches,
    this.sameRacerClassAsTarget = false,
    this.sameGenderAsTarget = false,
  });

  final List<String>? racerClasses;
  final List<String>? genders;
  final QuizAgeRange? ageRange;
  final List<String>? birthPlaces;
  final List<String>? homeBranches;
  final List<String>? affiliationBranches;
  final bool sameRacerClassAsTarget;
  final bool sameGenderAsTarget;

  QuizRacerCondition copyWith({
    List<String>? racerClasses,
    List<String>? genders,
    QuizAgeRange? ageRange,
    List<String>? birthPlaces,
    List<String>? homeBranches,
    List<String>? affiliationBranches,
    bool? sameRacerClassAsTarget,
    bool? sameGenderAsTarget,
  }) {
    return QuizRacerCondition(
      racerClasses: racerClasses ?? this.racerClasses,
      genders: genders ?? this.genders,
      ageRange: ageRange ?? this.ageRange,
      birthPlaces: birthPlaces ?? this.birthPlaces,
      homeBranches: homeBranches ?? this.homeBranches,
      affiliationBranches: affiliationBranches ?? this.affiliationBranches,
      sameRacerClassAsTarget:
          sameRacerClassAsTarget ?? this.sameRacerClassAsTarget,
      sameGenderAsTarget: sameGenderAsTarget ?? this.sameGenderAsTarget,
    );
  }
}

class QuizAgeRange {
  const QuizAgeRange({this.min, this.max});

  final int? min;
  final int? max;
}

class QuizModeConfig {
  const QuizModeConfig({
    required this.id,
    required this.label,
    required this.description,
    required this.timeLimitSeconds,
    required this.segments,
    this.availableInMvp = true,
  });

  final String id;
  final String label;
  final String description;
  final int? timeLimitSeconds;
  final List<QuizSegment> segments;
  final bool availableInMvp;

  int get questionCount =>
      segments.fold<int>(0, (sum, segment) => sum + segment.count);

  QuizModeConfig copyWith({
    String? id,
    String? label,
    String? description,
    int? timeLimitSeconds,
    bool clearTimeLimit = false,
    List<QuizSegment>? segments,
    bool? availableInMvp,
  }) {
    return QuizModeConfig(
      id: id ?? this.id,
      label: label ?? this.label,
      description: description ?? this.description,
      timeLimitSeconds: clearTimeLimit
          ? null
          : (timeLimitSeconds ?? this.timeLimitSeconds),
      segments: segments ?? this.segments,
      availableInMvp: availableInMvp ?? this.availableInMvp,
    );
  }
}

class RacerProfile {
  const RacerProfile({
    required this.id,
    required this.name,
    required this.nameKana,
    required this.registrationNumber,
    required this.racerClass,
    required this.gender,
    required this.imageUrl,
    this.imageStoragePath,
    required this.imageSource,
    required this.updatedAt,
    required this.isActive,
    this.birthDate,
    this.birthPlace,
    this.homeBranch,
    this.affiliationBranch,
    this.localImagePath,
  });

  final String id;
  final String name;
  final String nameKana;
  final int registrationNumber;
  final String racerClass;
  final String gender;
  final String imageUrl;
  final String? imageStoragePath;
  final String imageSource;
  final DateTime updatedAt;
  final bool isActive;
  final DateTime? birthDate;
  final String? birthPlace;
  final String? homeBranch;
  final String? affiliationBranch;
  final String? localImagePath;

  String get faceLabel => '顔画像 ${registrationNumber.toString()}';

  bool get hasLocalImagePath =>
      localImagePath != null && localImagePath!.isNotEmpty;

  RacerProfile copyWith({
    String? id,
    String? name,
    String? nameKana,
    int? registrationNumber,
    String? racerClass,
    String? gender,
    String? imageUrl,
    String? imageStoragePath,
    bool clearImageStoragePath = false,
    String? imageSource,
    DateTime? updatedAt,
    bool? isActive,
    DateTime? birthDate,
    bool clearBirthDate = false,
    String? birthPlace,
    bool clearBirthPlace = false,
    String? homeBranch,
    bool clearHomeBranch = false,
    String? affiliationBranch,
    bool clearAffiliationBranch = false,
    String? localImagePath,
    bool clearLocalImagePath = false,
  }) {
    return RacerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      nameKana: nameKana ?? this.nameKana,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      racerClass: racerClass ?? this.racerClass,
      gender: gender ?? this.gender,
      imageUrl: imageUrl ?? this.imageUrl,
      imageStoragePath: clearImageStoragePath
          ? null
          : (imageStoragePath ?? this.imageStoragePath),
      imageSource: imageSource ?? this.imageSource,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
      birthPlace: clearBirthPlace ? null : (birthPlace ?? this.birthPlace),
      homeBranch: clearHomeBranch ? null : (homeBranch ?? this.homeBranch),
      affiliationBranch: clearAffiliationBranch
          ? null
          : (affiliationBranch ?? this.affiliationBranch),
      localImagePath: clearLocalImagePath
          ? null
          : (localImagePath ?? this.localImagePath),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'nameKana': nameKana,
      'registrationNumber': registrationNumber,
      'class': racerClass,
      'gender': gender,
      'imageUrl': imageUrl,
      'imageStoragePath': imageStoragePath,
      'imageSource': imageSource,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'isActive': isActive,
      'birthDate': birthDate?.toUtc().toIso8601String(),
      'birthPlace': birthPlace,
      'homeBranch': homeBranch,
      'affiliationBranch': affiliationBranch,
    };
  }

  static RacerProfile? tryParseJson(Map<String, Object?> json) {
    final Object? idValue = json['id'];
    final Object? nameValue = json['name'];
    final Object? nameKanaValue = json['nameKana'];
    final Object? registrationNumberValue = json['registrationNumber'];
    final Object? classValue = json['class'];
    final Object? genderValue = json['gender'];
    final Object? imageUrlValue = json['imageUrl'];
    final Object? imageStoragePathValue = json['imageStoragePath'];
    final Object? imageSourceValue = json['imageSource'];
    final Object? updatedAtValue = json['updatedAt'];
    final Object? isActiveValue = json['isActive'];
    final Object? birthDateValue = json['birthDate'];
    final Object? birthPlaceValue = json['birthPlace'];
    final Object? homeBranchValue = json['homeBranch'];
    final Object? affiliationBranchValue = json['affiliationBranch'];

    if (idValue is! String ||
        idValue.isEmpty ||
        nameValue is! String ||
        nameValue.isEmpty ||
        nameKanaValue is! String ||
        nameKanaValue.isEmpty ||
        registrationNumberValue is! int ||
        classValue is! String ||
        classValue.isEmpty ||
        genderValue is! String ||
        genderValue.isEmpty ||
        imageUrlValue is! String ||
        imageUrlValue.isEmpty ||
        imageSourceValue is! String ||
        imageSourceValue.isEmpty ||
        updatedAtValue is! String ||
        isActiveValue is! bool) {
      return null;
    }

    final DateTime? updatedAt = DateTime.tryParse(updatedAtValue);
    if (updatedAt == null) {
      return null;
    }

    final DateTime? birthDate =
        birthDateValue is String && birthDateValue.isNotEmpty
        ? DateTime.tryParse(birthDateValue)?.toUtc()
        : null;

    return RacerProfile(
      id: idValue,
      name: nameValue,
      nameKana: nameKanaValue,
      registrationNumber: registrationNumberValue,
      racerClass: classValue,
      gender: genderValue,
      imageUrl: imageUrlValue,
      imageStoragePath:
          imageStoragePathValue is String && imageStoragePathValue.isNotEmpty
          ? imageStoragePathValue
          : null,
      imageSource: imageSourceValue,
      updatedAt: updatedAt.toUtc(),
      isActive: isActiveValue,
      birthDate: birthDate,
      birthPlace: birthPlaceValue is String && birthPlaceValue.isNotEmpty
          ? birthPlaceValue
          : null,
      homeBranch: homeBranchValue is String && homeBranchValue.isNotEmpty
          ? homeBranchValue
          : null,
      affiliationBranch:
          affiliationBranchValue is String && affiliationBranchValue.isNotEmpty
          ? affiliationBranchValue
          : null,
    );
  }
}

class QuizImageReveal {
  const QuizImageReveal({
    required this.startScale,
    required this.startAlignmentX,
    required this.startAlignmentY,
    required this.duration,
  });

  final double startScale;
  final double startAlignmentX;
  final double startAlignmentY;
  final Duration duration;
}

class QuizOption {
  const QuizOption({
    required this.racerId,
    required this.label,
    this.labelReading,
    this.imageUrl,
    this.localImagePath,
  });

  final String racerId;
  final String label;
  final String? labelReading;
  final String? imageUrl;
  final String? localImagePath;

  bool get hasImage =>
      (imageUrl != null && imageUrl!.isNotEmpty) ||
      (localImagePath != null && localImagePath!.isNotEmpty);
}

class QuizQuestion {
  const QuizQuestion({
    required this.promptType,
    required this.prompt,
    this.promptImageUrl,
    this.promptImageLocalPath,
    this.promptImageReveal,
    required this.options,
    required this.correctIndex,
    required this.correctRacerId,
  });

  final QuizPromptType promptType;
  final String prompt;
  final String? promptImageUrl;
  final String? promptImageLocalPath;
  final QuizImageReveal? promptImageReveal;
  final List<QuizOption> options;
  final int correctIndex;
  final String correctRacerId;

  bool get hasPromptImage =>
      (promptImageUrl != null && promptImageUrl!.isNotEmpty) ||
      (promptImageLocalPath != null && promptImageLocalPath!.isNotEmpty);

  bool get hasImageOptions =>
      options.any((QuizOption option) => option.hasImage);
}

enum QuizMistakeOutcome { wrongAnswer, timeout, abandoned }

class QuizMistakeOptionSnapshot {
  const QuizMistakeOptionSnapshot({
    required this.racerId,
    required this.label,
    this.labelReading,
    this.imageUrl,
  });

  final String racerId;
  final String label;
  final String? labelReading;
  final String? imageUrl;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'racerId': racerId,
      'label': label,
      'labelReading': labelReading,
      'imageUrl': imageUrl,
    };
  }
}

class QuizMistakeSnapshot {
  const QuizMistakeSnapshot({
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
    required this.elapsed,
    required this.outcome,
  });

  final int questionIndex;
  final int mistakeSequence;
  final QuizPromptType promptType;
  final String prompt;
  final String? promptImageUrl;
  final List<QuizMistakeOptionSnapshot> options;
  final int correctIndex;
  final int? selectedIndex;
  final String correctRacerId;
  final String? selectedRacerId;
  final Duration elapsed;
  final QuizMistakeOutcome outcome;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'questionIndex': questionIndex,
      'mistakeSequence': mistakeSequence,
      'promptType': promptType.name,
      'prompt': prompt,
      'promptImageUrl': promptImageUrl,
      'options': options
          .map((QuizMistakeOptionSnapshot option) => option.toJson())
          .toList(),
      'correctIndex': correctIndex,
      'selectedIndex': selectedIndex,
      'correctRacerId': correctRacerId,
      'selectedRacerId': selectedRacerId,
      'elapsedMs': elapsed.inMilliseconds,
      'outcome': outcome.name,
    };
  }
}

class QuizResultSummary {
  const QuizResultSummary({
    required this.modeId,
    required this.modeLabel,
    required this.score,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.totalAnswerTime,
    required this.endReason,
    required this.rankingEligible,
    required this.continuedByAd,
    required this.clientFinishedAt,
    required this.mistakes,
  });

  final String modeId;
  final String modeLabel;
  final int score;
  final int correctAnswers;
  final int totalQuestions;
  final Duration totalAnswerTime;
  final QuizEndReason endReason;
  final bool rankingEligible;
  final bool continuedByAd;
  final DateTime clientFinishedAt;
  final List<QuizMistakeSnapshot> mistakes;
}

String promptTypeLabel(QuizPromptType type) {
  switch (type) {
    case QuizPromptType.faceToName:
      return '顔 -> 選手名';
    case QuizPromptType.nameToFace:
      return '選手名 -> 顔';
    case QuizPromptType.partialFaceToName:
      return '顔の一部 -> 選手名';
    case QuizPromptType.registrationToFace:
      return '登録番号 -> 顔';
    case QuizPromptType.faceToRegistration:
      return '顔 -> 登録番号';
  }
}
