import 'quiz_models.dart';

const int kMasterQuestionCount = 4096;
const List<QuizQuestionFlowStep> kCarefulA1FlowSteps = <QuizQuestionFlowStep>[
  QuizQuestionFlowStep(
    weight: 100,
    targetCondition: QuizRacerCondition(racerClasses: <String>['A1']),
    optionCondition: QuizRacerCondition(
      racerClasses: <String>['A1'],
      sameRacerClassAsTarget: true,
      sameGenderAsTarget: true,
    ),
  ),
];

const List<QuizQuestionFlowStep> kCarefulA2FlowSteps = <QuizQuestionFlowStep>[
  QuizQuestionFlowStep(
    weight: 100,
    targetCondition: QuizRacerCondition(racerClasses: <String>['A2']),
    optionCondition: QuizRacerCondition(
      racerClasses: <String>['A2'],
      sameRacerClassAsTarget: true,
      sameGenderAsTarget: true,
    ),
  ),
];

const List<QuizQuestionFlowStep> kCarefulBFlowSteps = <QuizQuestionFlowStep>[
  QuizQuestionFlowStep(
    weight: 100,
    targetCondition: QuizRacerCondition(racerClasses: <String>['B1', 'B2']),
    optionCondition: QuizRacerCondition(
      racerClasses: <String>['B1', 'B2'],
      sameGenderAsTarget: true,
    ),
  ),
];
const List<QuizQuestionFlowStep> kChallengeFlowSteps = <QuizQuestionFlowStep>[
  QuizQuestionFlowStep(
    weight: 60,
    targetCondition: QuizRacerCondition(racerClasses: <String>['A1']),
    optionCondition: QuizRacerCondition(
      racerClasses: <String>['A1'],
      sameRacerClassAsTarget: true,
      sameGenderAsTarget: true,
    ),
  ),
  QuizQuestionFlowStep(
    weight: 20,
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

const List<QuizSegment> kCarefulSegments = <QuizSegment>[
  QuizSegment(
    promptType: QuizPromptType.faceToName,
    count: 5,
    flowSteps: kCarefulA1FlowSteps,
  ),
  QuizSegment(
    promptType: QuizPromptType.nameToFace,
    count: 5,
    flowSteps: kCarefulA1FlowSteps,
  ),
  QuizSegment(
    promptType: QuizPromptType.faceToName,
    count: 5,
    flowSteps: kCarefulA2FlowSteps,
  ),
  QuizSegment(
    promptType: QuizPromptType.nameToFace,
    count: 5,
    flowSteps: kCarefulA2FlowSteps,
  ),
  QuizSegment(
    promptType: QuizPromptType.faceToName,
    count: 5,
    flowSteps: kCarefulBFlowSteps,
  ),
  QuizSegment(
    promptType: QuizPromptType.nameToFace,
    count: 5,
    flowSteps: kCarefulBFlowSteps,
  ),
];

const List<QuizSegment> kChallengeSegments = <QuizSegment>[
  QuizSegment(
    promptType: QuizPromptType.partialFaceToName,
    count: 50,
    flowSteps: kChallengeFlowSteps,
  ),
];

const List<QuizModeConfig> kQuizModes = <QuizModeConfig>[
  QuizModeConfig(
    id: 'quick',
    label: 'さくっと',
    description: '10問・A1級限定の顔 → 選手名',
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
    description: '30問・5問ずつ顔 → 選手名と選手名 → 顔が交互',
    timeLimitSeconds: null,
    segments: kCarefulSegments,
  ),
  QuizModeConfig(
    id: 'challenge',
    label: 'チャレンジ',
    description: '50問・全問 顔の一部 → 選手名',
    timeLimitSeconds: 10,
    segments: kChallengeSegments,
  ),
  QuizModeConfig(
    id: 'master',
    label: '達人',
    description: '最大4096問・全問 顔 → 選手名',
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
      QuizSegment(promptType: QuizPromptType.faceToName, count: 0),
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
