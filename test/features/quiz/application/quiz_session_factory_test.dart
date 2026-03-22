import 'package:flutter_test/flutter_test.dart';

import 'package:boatface/features/quiz/application/quiz_session.dart';
import 'package:boatface/features/quiz/domain/quiz_models.dart';
import 'package:boatface/features/quiz/domain/quiz_modes.dart';

void main() {
  group('QuizSessionFactory', () {
    test('builds image prompt questions for face based prompt types', () {
      final List<RacerProfile> racers = _buildRacers();

      final QuizSession faceToName = QuizSessionFactory.create(
        mode: const QuizModeConfig(
          id: 'face-name',
          label: '顔->名前',
          description: '',
          timeLimitSeconds: 10,
          segments: <QuizSegment>[
            QuizSegment(promptType: QuizPromptType.faceToName, count: 1),
          ],
        ),
        racers: racers,
      );
      final QuizSession faceToRegistration = QuizSessionFactory.create(
        mode: const QuizModeConfig(
          id: 'face-registration',
          label: '顔->登録番号',
          description: '',
          timeLimitSeconds: 10,
          segments: <QuizSegment>[
            QuizSegment(
              promptType: QuizPromptType.faceToRegistration,
              count: 1,
            ),
          ],
        ),
        racers: racers,
      );

      expect(faceToName.currentQuestion, isNotNull);
      expect(faceToName.currentQuestion!.hasPromptImage, true);
      expect(faceToName.currentQuestion!.promptImageReveal, isNull);
      expect(
        faceToName.currentQuestion!.options.every(
          (QuizOption option) => option.imageUrl == null,
        ),
        true,
      );

      expect(faceToRegistration.currentQuestion, isNotNull);
      expect(faceToRegistration.currentQuestion!.hasPromptImage, true);
      expect(faceToRegistration.currentQuestion!.promptImageReveal, isNull);
      expect(
        faceToRegistration.currentQuestion!.options.every(
          (QuizOption option) => option.imageUrl == null,
        ),
        true,
      );
    });

    test('builds image options for face selection prompt types', () {
      final List<RacerProfile> racers = _buildRacers();

      final QuizSession nameToFace = QuizSessionFactory.create(
        mode: const QuizModeConfig(
          id: 'name-face',
          label: '名前->顔',
          description: '',
          timeLimitSeconds: 10,
          segments: <QuizSegment>[
            QuizSegment(promptType: QuizPromptType.nameToFace, count: 1),
          ],
        ),
        racers: racers,
      );
      final QuizSession registrationToFace = QuizSessionFactory.create(
        mode: const QuizModeConfig(
          id: 'registration-face',
          label: '登録番号->顔',
          description: '',
          timeLimitSeconds: 10,
          segments: <QuizSegment>[
            QuizSegment(
              promptType: QuizPromptType.registrationToFace,
              count: 1,
            ),
          ],
        ),
        racers: racers,
      );

      expect(nameToFace.currentQuestion, isNotNull);
      expect(nameToFace.currentQuestion!.hasPromptImage, false);
      expect(
        nameToFace.currentQuestion!.options.every(
          (QuizOption option) => option.hasImage,
        ),
        true,
      );

      expect(registrationToFace.currentQuestion, isNotNull);
      expect(registrationToFace.currentQuestion!.hasPromptImage, false);
      expect(
        registrationToFace.currentQuestion!.options.every(
          (QuizOption option) => option.hasImage,
        ),
        true,
      );
    });

    test('builds animated partial face questions within safe ranges', () {
      final QuizSession session = QuizSessionFactory.create(
        mode: const QuizModeConfig(
          id: 'partial',
          label: '部分',
          description: '',
          timeLimitSeconds: 10,
          segments: <QuizSegment>[
            QuizSegment(promptType: QuizPromptType.partialFaceToName, count: 1),
          ],
        ),
        racers: _buildRacers(),
      );

      final QuizQuestion question = session.currentQuestion!;
      final QuizImageReveal reveal = question.promptImageReveal!;

      expect(question.hasPromptImage, true);
      expect(question.prompt, 'この顔の選手名は？');
      expect(reveal.startScale, inInclusiveRange(2.2, 3.0));
      expect(reveal.startAlignmentX, inInclusiveRange(-0.35, 0.35));
      expect(reveal.startAlignmentY, inInclusiveRange(-0.25, 0.2));
      expect(reveal.duration, const Duration(milliseconds: 6500));
      expect(
        question.options.every((QuizOption option) => option.imageUrl == null),
        true,
      );
    });

    test(
      'uses generic prompt text for name-to-face and keeps kana on target',
      () {
        final QuizSession session = QuizSessionFactory.create(
          mode: const QuizModeConfig(
            id: 'name-face',
            label: '名前->顔',
            description: '',
            timeLimitSeconds: 10,
            segments: <QuizSegment>[
              QuizSegment(promptType: QuizPromptType.nameToFace, count: 1),
            ],
          ),
          racers: _buildRacers(),
        );

        final QuizQuestion question = session.currentQuestion!;
        final QuizOption target = question.options[question.correctIndex];

        expect(question.prompt, 'この選手の顔はどれ？');
        expect(target.labelReading, isNotNull);
      },
    );

    test(
      'limits quick mode questions and options to A1 racers of same gender',
      () {
        final List<RacerProfile> racers = _buildRacers();
        final Map<String, RacerProfile> racerById = <String, RacerProfile>{
          for (final RacerProfile racer in racers) racer.id: racer,
        };

        final QuizSession session = QuizSessionFactory.create(
          mode: kQuizModes.firstWhere(
            (QuizModeConfig mode) => mode.id == 'quick',
          ),
          racers: racers,
        );

        for (final QuizQuestion question in session.questions) {
          final RacerProfile target = racerById[question.correctRacerId]!;
          expect(target.racerClass, 'A1');
          expect(
            question.options.every(
              (QuizOption option) =>
                  racerById[option.racerId]!.racerClass == 'A1',
            ),
            true,
          );
          expect(
            question.options.every(
              (QuizOption option) =>
                  racerById[option.racerId]!.gender == target.gender,
            ),
            true,
          );
        }
      },
    );

    test('applies careful mode flow steps per segment', () {
      final QuizModeConfig carefulMode = kQuizModes.firstWhere(
        (QuizModeConfig mode) => mode.id == 'careful',
      );
      final List<RacerProfile> racers = _buildFlowRacers();
      final Map<String, RacerProfile> racerById = <String, RacerProfile>{
        for (final RacerProfile racer in racers) racer.id: racer,
      };

      final QuizSession session = QuizSessionFactory.create(
        mode: carefulMode,
        racers: racers,
      );

      expect(session.questions, hasLength(30));
      _expectQuestionWindow(
        session.questions.sublist(0, 10),
        racerById,
        allowedTargetClasses: <String>['A1'],
        allowedOptionClasses: <String>['A1'],
      );
      _expectQuestionWindow(
        session.questions.sublist(10, 16),
        racerById,
        allowedTargetClasses: <String>['A2'],
        allowedOptionClasses: <String>['A2'],
      );
      _expectQuestionWindow(
        session.questions.sublist(16, 20),
        racerById,
        allowedTargetClasses: <String>['A2', 'B1', 'B2'],
        allowedOptionClasses: <String>['A2', 'B1', 'B2'],
      );
      _expectQuestionWindow(
        session.questions.sublist(20, 25),
        racerById,
        allowedTargetClasses: <String>['A1'],
        allowedOptionClasses: <String>['A1'],
      );
      _expectQuestionWindow(
        session.questions.sublist(25, 28),
        racerById,
        allowedTargetClasses: <String>['A2'],
        allowedOptionClasses: <String>['A2'],
      );
      _expectQuestionWindow(
        session.questions.sublist(28, 30),
        racerById,
        allowedTargetClasses: <String>['A2', 'B1', 'B2'],
        allowedOptionClasses: <String>['A2', 'B1', 'B2'],
      );
    });

    test('applies challenge mode flow steps per segment', () {
      final QuizModeConfig challengeMode = kQuizModes.firstWhere(
        (QuizModeConfig mode) => mode.id == 'challenge',
      );
      final List<RacerProfile> racers = _buildFlowRacers();
      final Map<String, RacerProfile> racerById = <String, RacerProfile>{
        for (final RacerProfile racer in racers) racer.id: racer,
      };

      final QuizSession session = QuizSessionFactory.create(
        mode: challengeMode,
        racers: racers,
      );

      expect(session.questions, hasLength(50));
      _expectQuestionWindow(
        session.questions.sublist(0, 4),
        racerById,
        allowedTargetClasses: <String>['A1'],
        allowedOptionClasses: <String>['A1'],
      );
      _expectQuestionWindow(
        session.questions.sublist(4, 10),
        racerById,
        allowedTargetClasses: <String>['A2'],
        allowedOptionClasses: <String>['A2'],
      );
      _expectQuestionWindow(
        session.questions.sublist(10, 20),
        racerById,
        allowedTargetClasses: <String>['A2', 'B1', 'B2'],
        allowedOptionClasses: <String>['A2', 'B1', 'B2'],
      );
      _expectQuestionWindow(
        session.questions.sublist(20, 22),
        racerById,
        allowedTargetClasses: <String>['A1'],
        allowedOptionClasses: <String>['A1'],
      );
      _expectQuestionWindow(
        session.questions.sublist(22, 25),
        racerById,
        allowedTargetClasses: <String>['A2'],
        allowedOptionClasses: <String>['A2'],
      );
      _expectQuestionWindow(
        session.questions.sublist(25, 30),
        racerById,
        allowedTargetClasses: <String>['A2', 'B1', 'B2'],
        allowedOptionClasses: <String>['A2', 'B1', 'B2'],
      );
      _expectQuestionWindow(
        session.questions.sublist(30, 32),
        racerById,
        allowedTargetClasses: <String>['A1'],
        allowedOptionClasses: <String>['A1'],
      );
      _expectQuestionWindow(
        session.questions.sublist(32, 35),
        racerById,
        allowedTargetClasses: <String>['A2'],
        allowedOptionClasses: <String>['A2'],
      );
      _expectQuestionWindow(
        session.questions.sublist(35, 40),
        racerById,
        allowedTargetClasses: <String>['A2', 'B1', 'B2'],
        allowedOptionClasses: <String>['A2', 'B1', 'B2'],
      );
      _expectQuestionWindow(
        session.questions.sublist(40, 41),
        racerById,
        allowedTargetClasses: <String>['A1'],
        allowedOptionClasses: <String>['A1'],
      );
      _expectQuestionWindow(
        session.questions.sublist(41, 43),
        racerById,
        allowedTargetClasses: <String>['A2'],
        allowedOptionClasses: <String>['A2'],
      );
      _expectQuestionWindow(
        session.questions.sublist(43, 45),
        racerById,
        allowedTargetClasses: <String>['A2', 'B1', 'B2'],
        allowedOptionClasses: <String>['A2', 'B1', 'B2'],
      );
      _expectQuestionWindow(
        session.questions.sublist(45, 46),
        racerById,
        allowedTargetClasses: <String>['A1'],
        allowedOptionClasses: <String>['A1'],
      );
      _expectQuestionWindow(
        session.questions.sublist(46, 48),
        racerById,
        allowedTargetClasses: <String>['A2'],
        allowedOptionClasses: <String>['A2'],
      );
      _expectQuestionWindow(
        session.questions.sublist(48, 50),
        racerById,
        allowedTargetClasses: <String>['A2', 'B1', 'B2'],
        allowedOptionClasses: <String>['A2', 'B1', 'B2'],
      );
    });

    test('prefers same class and gender for distractors', () {
      final List<RacerProfile> racers = <RacerProfile>[
        _buildRacer(0, racerClass: 'A1', gender: 'male'),
        _buildRacer(1, racerClass: 'A1', gender: 'male'),
        _buildRacer(2, racerClass: 'A1', gender: 'male'),
        _buildRacer(3, racerClass: 'A1', gender: 'male'),
        _buildRacer(4, racerClass: 'B2', gender: 'female'),
        _buildRacer(5, racerClass: 'B2', gender: 'female'),
        _buildRacer(6, racerClass: 'B2', gender: 'female'),
        _buildRacer(7, racerClass: 'B2', gender: 'female'),
      ];
      final Map<String, RacerProfile> racerById = <String, RacerProfile>{
        for (final RacerProfile racer in racers) racer.id: racer,
      };

      final QuizSession session = QuizSessionFactory.create(
        mode: QuizModeConfig(
          id: 'careful',
          label: 'じっくり',
          description: '',
          timeLimitSeconds: null,
          segments: <QuizSegment>[
            QuizSegment(promptType: QuizPromptType.faceToName, count: 1),
          ],
        ),
        racers: racers,
      );

      final QuizQuestion question = session.currentQuestion!;
      final RacerProfile target = racerById[question.correctRacerId]!;
      final List<RacerProfile> distractors = question.options
          .where(
            (QuizOption option) => option.racerId != question.correctRacerId,
          )
          .map((QuizOption option) => racerById[option.racerId]!)
          .toList(growable: false);

      expect(
        distractors.every(
          (RacerProfile racer) =>
              racer.racerClass == target.racerClass &&
              racer.gender == target.gender,
        ),
        true,
      );
    });
  });
}

List<RacerProfile> _buildRacers() {
  return <RacerProfile>[
    _buildRacer(0, racerClass: 'A1', gender: 'male'),
    _buildRacer(1, racerClass: 'A1', gender: 'male'),
    _buildRacer(2, racerClass: 'A1', gender: 'male'),
    _buildRacer(3, racerClass: 'A1', gender: 'male'),
    _buildRacer(4, racerClass: 'A1', gender: 'male'),
    _buildRacer(5, racerClass: 'A2', gender: 'female'),
    _buildRacer(6, racerClass: 'B1', gender: 'female'),
    _buildRacer(7, racerClass: 'B2', gender: 'male'),
  ];
}

List<RacerProfile> _buildFlowRacers() {
  return <RacerProfile>[
    for (int index = 0; index < 4; index += 1)
      _buildRacer(index, racerClass: 'A1', gender: 'male'),
    for (int index = 4; index < 8; index += 1)
      _buildRacer(index, racerClass: 'A2', gender: 'female'),
    for (int index = 8; index < 12; index += 1)
      _buildRacer(index, racerClass: 'B1', gender: 'male'),
    for (int index = 12; index < 16; index += 1)
      _buildRacer(index, racerClass: 'B2', gender: 'female'),
  ];
}

void _expectQuestionWindow(
  List<QuizQuestion> questions,
  Map<String, RacerProfile> racerById, {
  required List<String> allowedTargetClasses,
  required List<String> allowedOptionClasses,
}) {
  for (final QuizQuestion question in questions) {
    final RacerProfile target = racerById[question.correctRacerId]!;
    expect(allowedTargetClasses, contains(target.racerClass));
    expect(
      question.options.every(
        (QuizOption option) => allowedOptionClasses.contains(
          racerById[option.racerId]!.racerClass,
        ),
      ),
      true,
    );
  }
}

RacerProfile _buildRacer(
  int index, {
  required String racerClass,
  required String gender,
}) {
  return RacerProfile(
    id: 'racer-$index',
    name: '選手$index',
    nameKana: 'センシュ$index',
    registrationNumber: 4000 + index,
    racerClass: racerClass,
    gender: gender,
    imageUrl: 'https://example.com/racer-$index.jpg',
    imageSource: 'test',
    updatedAt: DateTime.utc(2026, 3, 21),
    isActive: true,
  );
}
