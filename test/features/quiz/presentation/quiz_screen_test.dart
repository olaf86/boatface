import 'package:boatface/features/quiz/data/quiz_data_providers.dart';
import 'package:boatface/features/quiz/data/racer_master_models.dart';
import 'package:boatface/features/quiz/data/racer_repository.dart';
import 'package:boatface/features/quiz/domain/quiz_models.dart';
import 'package:boatface/features/quiz/presentation/quiz_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows hint buttons and freezes time in timed mode', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildApp(mode: _buildMode(timeLimitSeconds: 10)));

    expect(
      find.byKey(const ValueKey<String>('quiz-hint-fifty-fifty')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('quiz-hint-time-freeze')),
      findsOneWidget,
    );
    expect(find.byTooltip('2択に絞る'), findsOneWidget);
    expect(find.byTooltip('時間を停止する'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('quiz-hint-time-freeze')),
    );
    await tester.pump();

    expect(find.text('時間停止中'), findsOneWidget);
    expect(find.byTooltip('時間停止ヒントは使用済み'), findsOneWidget);
  });

  testWidgets('hides time-freeze hint in unlimited mode', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildApp(mode: _buildMode(timeLimitSeconds: null)),
    );

    expect(
      find.byKey(const ValueKey<String>('quiz-hint-fifty-fifty')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('quiz-hint-time-freeze')),
      findsNothing,
    );
    expect(find.byTooltip('2択に絞る'), findsOneWidget);
    expect(find.byTooltip('時間を停止する'), findsNothing);
    expect(find.text('制限時間: 無制限'), findsOneWidget);
  });
}

Widget _buildApp({required QuizModeConfig mode}) {
  return ProviderScope(
    overrides: <Override>[
      racerRepositoryProvider.overrideWithValue(_FakeRacerRepository()),
    ],
    child: MaterialApp(home: QuizScreen(mode: mode)),
  );
}

QuizModeConfig _buildMode({required int? timeLimitSeconds}) {
  return QuizModeConfig(
    id: 'test',
    label: 'テスト',
    description: 'screen test mode',
    timeLimitSeconds: timeLimitSeconds,
    segments: const <QuizSegment>[
      QuizSegment(promptType: QuizPromptType.faceToName, count: 1),
    ],
  );
}

class _FakeRacerRepository implements RacerRepository {
  @override
  RacerDatasetManifest? get currentManifest => null;

  @override
  bool get hasUsableData => true;

  @override
  bool get hasUsableSnapshot => true;

  @override
  Future<RacerSyncResult> initialize() async {
    return const RacerSyncResult(
      activeManifest: null,
      remoteManifest: null,
      downloadedSnapshot: false,
      downloadedImagePack: false,
      usedLocalSnapshot: true,
    );
  }

  @override
  List<RacerProfile> requireCachedAll() {
    return List<RacerProfile>.generate(8, (int index) {
      return RacerProfile(
        id: 'racer-$index',
        name: '選手$index',
        registrationNumber: 5000 + index,
        racerClass: index.isEven ? 'A1' : 'A2',
        gender: index.isEven ? 'male' : 'female',
        imageUrl: 'https://example.com/racer-$index.jpg',
        imageSource: 'test',
        updatedAt: DateTime.utc(2026, 3, 21),
        isActive: true,
      );
    });
  }

  @override
  Future<RacerSyncResult> syncIfNeeded() async {
    return const RacerSyncResult(
      activeManifest: null,
      remoteManifest: null,
      downloadedSnapshot: false,
      downloadedImagePack: false,
      usedLocalSnapshot: true,
    );
  }
}
