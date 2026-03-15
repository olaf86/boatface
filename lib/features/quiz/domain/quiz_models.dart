enum QuizPromptType {
  faceToName,
  nameToFace,
  partialFaceToName,
  registrationToFace,
  faceToRegistration,
}

enum QuizEndReason { completed, wrongAnswer, timeout, abandoned }

class QuizSegment {
  const QuizSegment({required this.promptType, required this.count});

  final QuizPromptType promptType;
  final int count;

  QuizSegment copyWith({QuizPromptType? promptType, int? count}) {
    return QuizSegment(
      promptType: promptType ?? this.promptType,
      count: count ?? this.count,
    );
  }
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
    required this.registrationNumber,
    required this.imageUrl,
    required this.imageSource,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final int registrationNumber;
  final String imageUrl;
  final String imageSource;
  final DateTime updatedAt;

  String get faceLabel => '顔画像 ${registrationNumber.toString()}';
}

class QuizQuestion {
  const QuizQuestion({
    required this.promptType,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.correctRacerId,
  });

  final QuizPromptType promptType;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String correctRacerId;
}

class QuizResultSummary {
  const QuizResultSummary({
    required this.modeId,
    required this.modeLabel,
    required this.score,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.totalAnswerTime,
    required this.seedToken,
    required this.endReason,
    required this.rankingEligible,
    required this.continuedByAd,
  });

  final String modeId;
  final String modeLabel;
  final int score;
  final int correctAnswers;
  final int totalQuestions;
  final Duration totalAnswerTime;
  final String seedToken;
  final QuizEndReason endReason;
  final bool rankingEligible;
  final bool continuedByAd;
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
