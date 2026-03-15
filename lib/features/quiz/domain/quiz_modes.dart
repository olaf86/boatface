import 'quiz_models.dart';

const int kMasterQuestionCount = 1600;

const List<QuizSegment> kChallengeSegments = <QuizSegment>[
  QuizSegment(promptType: QuizPromptType.faceToName, count: 20),
  QuizSegment(promptType: QuizPromptType.nameToFace, count: 10),
  QuizSegment(promptType: QuizPromptType.partialFaceToName, count: 10),
  QuizSegment(promptType: QuizPromptType.registrationToFace, count: 5),
  QuizSegment(promptType: QuizPromptType.faceToRegistration, count: 5),
];

const List<QuizModeConfig> kQuizModes = <QuizModeConfig>[
  QuizModeConfig(
    id: 'quick',
    label: 'さくっと',
    description: '10問・顔 -> 選手名',
    timeLimitSeconds: 10,
    segments: <QuizSegment>[
      QuizSegment(promptType: QuizPromptType.faceToName, count: 10),
    ],
  ),
  QuizModeConfig(
    id: 'careful',
    label: 'じっくり',
    description: '30問・前半20問は顔 -> 選手名、後半10問は選手名 -> 顔',
    timeLimitSeconds: null,
    segments: <QuizSegment>[
      QuizSegment(promptType: QuizPromptType.faceToName, count: 20),
      QuizSegment(promptType: QuizPromptType.nameToFace, count: 10),
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
    description: '約1600問・全問 顔 -> 選手名',
    timeLimitSeconds: 10,
    segments: <QuizSegment>[
      QuizSegment(
        promptType: QuizPromptType.faceToName,
        count: kMasterQuestionCount,
      ),
    ],
    availableInMvp: false,
  ),
  QuizModeConfig(
    id: 'custom',
    label: 'カスタム',
    description: '問題数と形式を自由設定',
    timeLimitSeconds: 10,
    segments: <QuizSegment>[
      QuizSegment(promptType: QuizPromptType.faceToName, count: 20),
    ],
    availableInMvp: false,
  ),
];
