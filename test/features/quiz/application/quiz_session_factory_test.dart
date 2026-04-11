import 'dart:math';

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
          label: '顔→名前',
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
          label: '顔→登録番号',
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
      expect(faceToName.currentQuestion!.promptVisualSpec, isNull);
      expect(
        faceToName.currentQuestion!.options.every(
          (QuizOption option) => option.imageUrl == null,
        ),
        true,
      );

      expect(faceToRegistration.currentQuestion, isNotNull);
      expect(faceToRegistration.currentQuestion!.hasPromptImage, true);
      expect(faceToRegistration.currentQuestion!.promptVisualSpec, isNull);
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
          label: '名前→顔',
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
          label: '登録番号→顔',
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

    test('builds partial face questions with all visual variants', () {
      final Set<PartialFaceVariant> seenVariants = <PartialFaceVariant>{};

      for (int seed = 0; seed < 8; seed += 1) {
        final QuizSession session = QuizSessionFactory.create(
          mode: const QuizModeConfig(
            id: 'partial',
            label: '部分',
            description: '',
            timeLimitSeconds: 10,
            segments: <QuizSegment>[
              QuizSegment(
                promptType: QuizPromptType.partialFaceToName,
                count: 12,
              ),
            ],
          ),
          racers: _buildRacers(),
          random: Random(seed),
        );

        for (final QuizQuestion question in _collectQuestions(session)) {
          expect(question.hasPromptImage, true);
          expect(question.prompt, 'この顔の選手名は？');
          expect(
            question.options.every(
              (QuizOption option) => option.imageUrl == null,
            ),
            true,
          );

          final PartialFaceVariant variant = question.partialFaceVariant!;
          final QuizPromptVisualSpec spec = question.promptVisualSpec!;
          seenVariants.add(variant);

          switch ((variant, spec)) {
            case (
              PartialFaceVariant.zoomOutCenter,
              QuizZoomOutCenterVisualSpec zoomSpec,
            ):
              expect(zoomSpec.startScale, inInclusiveRange(1.9, 2.4));
              expect(zoomSpec.startAlignmentX, inInclusiveRange(-0.12, 0.12));
              expect(zoomSpec.startAlignmentY, inInclusiveRange(-0.09, 0.09));
            case (
              PartialFaceVariant.spotlights,
              QuizSpotlightsVisualSpec windowSpec,
            ):
              expect(
                PartialFaceMaskPattern.values,
                contains(windowSpec.maskPattern),
              );
              expect(windowSpec.spotlightCount, anyOf(equals(2), equals(3)));
              expect(
                windowSpec.startRadiusFactor,
                inInclusiveRange(0.18, 0.22),
              );
              expect(windowSpec.endRadiusFactor, inInclusiveRange(0.28, 0.34));
              expect(
                windowSpec.endRadiusFactor,
                greaterThan(windowSpec.startRadiusFactor),
              );
              expect(
                windowSpec.horizontalTravelFactor,
                inInclusiveRange(0.46, 0.64),
              );
              expect(
                windowSpec.verticalTravelFactor,
                inInclusiveRange(0.34, 0.52),
              );
              expect(windowSpec.horizontalTurns, inInclusiveRange(1.15, 1.55));
              expect(windowSpec.verticalTurns, inInclusiveRange(1.7, 2.25));
              expect(windowSpec.phaseOffsetTurns, inInclusiveRange(0, 1));
            case (
              PartialFaceVariant.tileReveal,
              QuizTileRevealVisualSpec tileSpec,
            ):
              expect(
                PartialFaceMaskPattern.values,
                contains(tileSpec.maskPattern),
              );
              expect(tileSpec.tileRows, anyOf(equals(3), equals(4)));
              expect(tileSpec.tileColumns, 4);
              expect(
                tileSpec.revealOrder,
                hasLength(tileSpec.tileRows * tileSpec.tileColumns),
              );
              expect(
                tileSpec.revealOrder.toSet(),
                hasLength(tileSpec.tileRows * tileSpec.tileColumns),
              );
              expect(tileSpec.initialVisibleTileCount, equals(0));
            case _:
              fail(
                'Unexpected partial face visual combination: $variant / $spec',
              );
          }
        }
      }

      expect(seenVariants, containsAll(PartialFaceVariant.values));
    });

    test('increases partial face difficulty as the session progresses', () {
      int earlyZoomOutCount = 0;
      int lateZoomOutCount = 0;
      int earlyTileRevealCount = 0;
      int midTileRevealCount = 0;
      int lateTileRevealCount = 0;

      for (int seed = 0; seed < 48; seed += 1) {
        final QuizSession session = QuizSessionFactory.create(
          mode: const QuizModeConfig(
            id: 'partial',
            label: '部分',
            description: '',
            timeLimitSeconds: 10,
            segments: <QuizSegment>[
              QuizSegment(
                promptType: QuizPromptType.partialFaceToName,
                count: 18,
              ),
            ],
          ),
          racers: _buildRacers(),
          random: Random(seed),
        );
        final List<QuizQuestion> questions = _collectQuestions(session);

        for (int index = 0; index < questions.length; index += 1) {
          final PartialFaceVariant variant =
              questions[index].partialFaceVariant!;
          if (index < 6) {
            if (variant == PartialFaceVariant.zoomOutCenter) {
              earlyZoomOutCount += 1;
            }
            if (variant == PartialFaceVariant.tileReveal) {
              earlyTileRevealCount += 1;
            }
          } else if (index < 12) {
            if (variant == PartialFaceVariant.tileReveal) {
              midTileRevealCount += 1;
            }
          } else {
            if (variant == PartialFaceVariant.zoomOutCenter) {
              lateZoomOutCount += 1;
            }
            if (variant == PartialFaceVariant.tileReveal) {
              lateTileRevealCount += 1;
            }
          }
        }
      }

      expect(earlyZoomOutCount, greaterThan(lateZoomOutCount));
      expect(midTileRevealCount, greaterThan(earlyTileRevealCount));
      expect(lateTileRevealCount, greaterThan(midTileRevealCount));
    });

    test('keeps kana on target for name-to-face questions', () {
      final QuizSession session = QuizSessionFactory.create(
        mode: const QuizModeConfig(
          id: 'name-face',
          label: '名前→顔',
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

      expect(question.prompt, 'の顔はどれ？');
      expect(target.labelReading, isNotNull);
    });

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

        final List<QuizQuestion> questions = _collectQuestions(session);

        for (final QuizQuestion question in questions) {
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

    test('alternates careful mode with segment-based difficulty ramps', () {
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
      final List<QuizQuestion> questions = _collectQuestions(session);

      expect(questions, hasLength(30));
      _expectPromptTypeWindow(
        questions.sublist(0, 5),
        QuizPromptType.faceToName,
      );
      _expectQuestionWindow(
        questions.sublist(0, 5),
        racerById,
        allowedTargetClasses: <String>['A1'],
        allowedOptionClasses: <String>['A1'],
      );
      _expectPromptTypeWindow(
        questions.sublist(5, 10),
        QuizPromptType.nameToFace,
      );
      _expectQuestionWindow(
        questions.sublist(5, 10),
        racerById,
        allowedTargetClasses: <String>['A1'],
        allowedOptionClasses: <String>['A1'],
      );
      _expectPromptTypeWindow(
        questions.sublist(10, 15),
        QuizPromptType.faceToName,
      );
      _expectQuestionWindow(
        questions.sublist(10, 15),
        racerById,
        allowedTargetClasses: <String>['A2'],
        allowedOptionClasses: <String>['A2'],
      );
      _expectPromptTypeWindow(
        questions.sublist(15, 20),
        QuizPromptType.nameToFace,
      );
      _expectQuestionWindow(
        questions.sublist(15, 20),
        racerById,
        allowedTargetClasses: <String>['A2'],
        allowedOptionClasses: <String>['A2'],
      );
      _expectPromptTypeWindow(
        questions.sublist(20, 25),
        QuizPromptType.faceToName,
      );
      _expectQuestionWindow(
        questions.sublist(24, 25),
        racerById,
        allowedTargetClasses: <String>['B1', 'B2'],
        allowedOptionClasses: <String>['B1', 'B2'],
      );
      _expectQuestionWindow(
        questions.sublist(20, 24),
        racerById,
        allowedTargetClasses: <String>['B1', 'B2'],
        allowedOptionClasses: <String>['B1', 'B2'],
      );
      _expectPromptTypeWindow(
        questions.sublist(25, 30),
        QuizPromptType.nameToFace,
      );
      _expectQuestionWindow(
        questions.sublist(25, 30),
        racerById,
        allowedTargetClasses: <String>['B1', 'B2'],
        allowedOptionClasses: <String>['B1', 'B2'],
      );
    });

    test('applies challenge mode flow steps across partial-face questions', () {
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
      final List<QuizQuestion> questions = _collectQuestions(session);

      expect(questions, hasLength(50));
      _expectPromptTypeWindow(questions, QuizPromptType.partialFaceToName);
      _expectQuestionWindow(
        questions.sublist(0, 10),
        racerById,
        allowedTargetClasses: <String>['A1'],
        allowedOptionClasses: <String>['A1'],
      );
      _expectQuestionWindow(
        questions.sublist(10, 25),
        racerById,
        allowedTargetClasses: <String>['A2'],
        allowedOptionClasses: <String>['A2'],
      );
      _expectQuestionWindow(
        questions.sublist(25, 50),
        racerById,
        allowedTargetClasses: <String>['A2', 'B1', 'B2'],
        allowedOptionClasses: <String>['A2', 'B1', 'B2'],
      );
    });

    test('records repeated attempts under the same slot index', () {
      final QuizSession session = QuizSessionFactory.create(
        mode: const QuizModeConfig(
          id: 'retry',
          label: '再挑戦',
          description: '',
          timeLimitSeconds: 10,
          segments: <QuizSegment>[
            QuizSegment(promptType: QuizPromptType.faceToName, count: 2),
          ],
        ),
        racers: _buildRacers(),
      );

      final QuizQuestion firstQuestion = session.currentQuestion!;
      final int wrongIndex =
          (firstQuestion.correctIndex + 1) % firstQuestion.options.length;

      session.submitAnswer(
        selectedIndex: wrongIndex,
        elapsed: const Duration(seconds: 2),
        remaining: const Duration(seconds: 8),
      );
      session.completePendingAnswerFeedback();
      session.continueAfterAd();

      expect(session.questionHistory, hasLength(2));
      expect(session.questionHistory[0].slotIndex, 0);
      expect(
        session.questionHistory[0].outcome,
        QuizQuestionOutcome.wrongAnswer,
      );
      expect(session.questionHistory[1].slotIndex, 0);
      expect(session.questionHistory[1].outcome, isNull);
      expect(
        session.questionHistory[1].question.correctRacerId,
        isNot(firstQuestion.correctRacerId),
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

List<QuizQuestion> _collectQuestions(QuizSession session) {
  final List<QuizQuestion> questions = <QuizQuestion>[];

  while (!session.isCompleted) {
    final QuizQuestion question = session.currentQuestion!;
    questions.add(question);
    session.submitAnswer(
      selectedIndex: question.correctIndex,
      elapsed: Duration.zero,
      remaining: null,
    );
    session.completePendingAnswerFeedback();
  }

  return questions;
}

void _expectPromptTypeWindow(
  List<QuizQuestion> questions,
  QuizPromptType promptType,
) {
  expect(
    questions.every(
      (QuizQuestion question) => question.promptType == promptType,
    ),
    true,
  );
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
    registrationTerm: 70 + index,
    racerClass: racerClass,
    gender: gender,
    imageUrl: 'https://example.com/racer-$index.jpg',
    imageSource: 'test',
    updatedAt: DateTime.utc(2026, 3, 21),
    isActive: true,
  );
}
