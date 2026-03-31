import 'package:boatface/features/quiz/data/quiz_data_providers.dart';
import 'package:boatface/features/quiz/data/racer_master_models.dart';
import 'package:boatface/features/quiz/data/racer_repository.dart';
import 'package:boatface/features/quiz/domain/quiz_models.dart';
import 'package:boatface/features/review/data/review_repository.dart';
import 'package:boatface/features/review/domain/review_models.dart';
import 'package:boatface/features/review/presentation/review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows correct and selected racer cards', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          reviewRepositoryProvider.overrideWithValue(_FakeReviewRepository()),
          racerRepositoryProvider.overrideWithValue(_FakeRacerRepository()),
        ],
        child: const MaterialApp(home: Scaffold(body: ReviewScreen())),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('最近のミス 10 件'), findsOneWidget);
    expect(find.text('正解だった選手'), findsOneWidget);
    expect(find.text('選んでしまった選手'), findsOneWidget);
    expect(find.text('正解レーサー'), findsOneWidget);
    expect(find.text('誤答レーサー'), findsOneWidget);
    expect(find.text('顔 -> 選手名'), findsOneWidget);
  });
}

class _FakeReviewRepository implements ReviewRepository {
  @override
  Future<List<ReviewMistakeEntry>> fetchMyMistakes() async {
    return <ReviewMistakeEntry>[
      ReviewMistakeEntry(
        mistakeId: 'mistake-1',
        resultId: 'result-1',
        sessionId: 'session-1',
        modeId: 'quick',
        modeLabel: 'さくっと',
        questionIndex: 2,
        mistakeSequence: 0,
        promptType: QuizPromptType.faceToName,
        prompt: 'この選手は誰？',
        options: const <ReviewMistakeOption>[
          ReviewMistakeOption(racerId: 'correct', label: '正解レーサー'),
          ReviewMistakeOption(racerId: 'wrong', label: '誤答レーサー'),
        ],
        correctIndex: 0,
        selectedIndex: 1,
        correctRacerId: 'correct',
        selectedRacerId: 'wrong',
        correctOption: const ReviewMistakeOption(
          racerId: 'correct',
          label: '正解レーサー',
        ),
        selectedOption: const ReviewMistakeOption(
          racerId: 'wrong',
          label: '誤答レーサー',
        ),
        elapsedMs: 1320,
        outcome: QuizMistakeOutcome.wrongAnswer,
        createdAt: DateTime.utc(2026, 3, 31, 10),
      ),
    ];
  }
}

class _FakeRacerRepository implements RacerRepository {
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
  Future<RacerSyncResult> syncIfNeeded() => initialize();

  @override
  RacerDatasetManifest? get currentManifest => null;

  @override
  bool get hasUsableData => true;

  @override
  bool get hasUsableSnapshot => true;

  @override
  List<RacerProfile> requireCachedAll() {
    return <RacerProfile>[
      _buildRacer(id: 'correct', name: '正解レーサー', gender: 'male'),
      _buildRacer(id: 'wrong', name: '誤答レーサー', gender: 'female'),
      _buildRacer(id: 'other-1', name: 'その他一', gender: 'male'),
      _buildRacer(id: 'other-2', name: 'その他二', gender: 'male'),
    ];
  }
}

RacerProfile _buildRacer({
  required String id,
  required String name,
  required String gender,
}) {
  return RacerProfile(
    id: id,
    name: name,
    nameKana: '$nameかな',
    registrationNumber: 4321,
    racerClass: 'A1',
    gender: gender,
    imageUrl: 'https://example.com/$id.png',
    imageSource: 'seed',
    updatedAt: DateTime.utc(2026, 3, 31),
    isActive: true,
    homeBranch: '東京',
    affiliationBranch: '東京',
  );
}
