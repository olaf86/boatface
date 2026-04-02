import 'quiz_models.dart';

const int kMasterQuestionCount = 4096;
const List<QuizQuestionFlowStep> kCarefulFlowSteps = <QuizQuestionFlowStep>[
  QuizQuestionFlowStep(
    weight: 50,
    targetCondition: QuizRacerCondition(racerClasses: <String>['A1']),
    optionCondition: QuizRacerCondition(
      racerClasses: <String>['A1'],
      sameRacerClassAsTarget: true,
      sameGenderAsTarget: true,
    ),
  ),
  QuizQuestionFlowStep(
    weight: 30,
    targetCondition: QuizRacerCondition(racerClasses: <String>['A2']),
    optionCondition: QuizRacerCondition(
      racerClasses: <String>['A2'],
      sameRacerClassAsTarget: true,
      sameGenderAsTarget: true,
    ),
  ),
  QuizQuestionFlowStep(
    weight: 20,
    targetCondition: QuizRacerCondition(
      racerClasses: <String>['A2', 'B1', 'B2'],
    ),
    optionCondition: QuizRacerCondition(
      racerClasses: <String>['A2', 'B1', 'B2'],
      sameRacerClassAsTarget: true,
      sameGenderAsTarget: true,
    ),
  ),
];
const List<QuizQuestionFlowStep> kChallengeFlowSteps = <QuizQuestionFlowStep>[
  QuizQuestionFlowStep(
    weight: 20,
    targetCondition: QuizRacerCondition(racerClasses: <String>['A1']),
    optionCondition: QuizRacerCondition(
      racerClasses: <String>['A1'],
      sameRacerClassAsTarget: true,
      sameGenderAsTarget: true,
    ),
  ),
  QuizQuestionFlowStep(
    weight: 30,
    targetCondition: QuizRacerCondition(racerClasses: <String>['A2']),
    optionCondition: QuizRacerCondition(
      racerClasses: <String>['A2'],
      sameRacerClassAsTarget: true,
      sameGenderAsTarget: true,
    ),
  ),
  QuizQuestionFlowStep(
    weight: 50,
    targetCondition: QuizRacerCondition(
      racerClasses: <String>['A2', 'B1', 'B2'],
    ),
    optionCondition: QuizRacerCondition(
      racerClasses: <String>['A2', 'B1', 'B2'],
      sameRacerClassAsTarget: true,
      sameGenderAsTarget: true,
    ),
  ),
];

const List<QuizSegment> kChallengeSegments = <QuizSegment>[
  QuizSegment(
    promptType: QuizPromptType.faceToName,
    count: 20,
    flowSteps: kChallengeFlowSteps,
  ),
  QuizSegment(
    promptType: QuizPromptType.nameToFace,
    count: 10,
    flowSteps: kChallengeFlowSteps,
  ),
  QuizSegment(
    promptType: QuizPromptType.partialFaceToName,
    count: 10,
    flowSteps: kChallengeFlowSteps,
  ),
  QuizSegment(
    promptType: QuizPromptType.registrationToFace,
    count: 5,
    flowSteps: kChallengeFlowSteps,
  ),
  QuizSegment(
    promptType: QuizPromptType.faceToRegistration,
    count: 5,
    flowSteps: kChallengeFlowSteps,
  ),
];

const List<QuizModeConfig> kQuizModes = <QuizModeConfig>[
  QuizModeConfig(
    id: 'quick',
    label: 'さくっと',
    description: '10問・A1級限定の顔 -> 選手名',
    timeLimitSeconds: 10,
    segments: <QuizSegment>[
      QuizSegment(
        promptType: QuizPromptType.faceToName,
        count: 10,
        flowSteps: <QuizQuestionFlowStep>[
          QuizQuestionFlowStep(
            weight: 100,
            targetCondition: QuizRacerCondition(racerClasses: <String>['A1']),
            optionCondition: QuizRacerCondition(
              racerClasses: <String>['A1'],
              sameRacerClassAsTarget: true,
              sameGenderAsTarget: true,
            ),
          ),
        ],
      ),
    ],
  ),
  QuizModeConfig(
    id: 'careful',
    label: 'じっくり',
    description: '30問・前半20問は顔 -> 選手名、後半10問は選手名 -> 顔',
    timeLimitSeconds: null,
    segments: <QuizSegment>[
      QuizSegment(
        promptType: QuizPromptType.faceToName,
        count: 20,
        flowSteps: kCarefulFlowSteps,
      ),
      QuizSegment(
        promptType: QuizPromptType.nameToFace,
        count: 10,
        flowSteps: kCarefulFlowSteps,
      ),
    ],
  ),
  QuizModeConfig(
    id: 'challenge',
    label: 'チャレンジ',
    description: '50問・複合形式（内訳は設定値で変更可能）',
    timeLimitSeconds: 10,
    segments: kChallengeSegments,
  ),
  QuizModeConfig(
    id: 'master',
    label: '達人',
    description: '最大4096問・全問 顔 -> 選手名',
    timeLimitSeconds: 10,
    segments: <QuizSegment>[
      QuizSegment(
        promptType: QuizPromptType.faceToName,
        count: kMasterQuestionCount,
      ),
    ],
  ),
  QuizModeConfig(
    id: 'custom',
    label: 'カスタム',
    description: '問題数と形式を自由設定',
    timeLimitSeconds: 10,
    segments: <QuizSegment>[
      QuizSegment(promptType: QuizPromptType.faceToName, count: 20),
    ],
    availableInMvp: true,
  ),
];

QuizModeConfig? quizModeById(String modeId) {
  for (final QuizModeConfig mode in kQuizModes) {
    if (mode.id == modeId) {
      return mode;
    }
  }

  return null;
}
