import 'package:flutter_test/flutter_test.dart';

import 'package:boatface/features/quiz/application/quiz_session.dart';
import 'package:boatface/features/quiz/domain/quiz_models.dart';

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
      expect(reveal.startScale, inInclusiveRange(2.2, 3.0));
      expect(reveal.startAlignmentX, inInclusiveRange(-0.35, 0.35));
      expect(reveal.startAlignmentY, inInclusiveRange(-0.25, 0.2));
      expect(reveal.duration, const Duration(milliseconds: 6500));
      expect(
        question.options.every((QuizOption option) => option.imageUrl == null),
        true,
      );
    });
  });
}

List<RacerProfile> _buildRacers() {
  return List<RacerProfile>.generate(8, (int index) {
    return RacerProfile(
      id: 'racer-$index',
      name: '選手$index',
      registrationNumber: 4000 + index,
      imageUrl: 'https://example.com/racer-$index.jpg',
      imageSource: 'test',
      updatedAt: DateTime.utc(2026, 3, 21),
      isActive: true,
    );
  });
}
