import 'package:boatface/features/quiz/data/quiz_data_providers.dart';
import 'package:boatface/features/quiz/data/racer_master_models.dart';
import 'package:boatface/features/quiz/data/racer_repository.dart';
import 'package:boatface/features/quiz/domain/quiz_models.dart';
import 'package:boatface/features/review/data/review_repository.dart';
import 'package:boatface/features/review/domain/review_models.dart';
import 'package:boatface/features/review/presentation/review_screen.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows correct and selected racer cards', (
    WidgetTester tester,
  ) async {
    _setMobileSurfaceSize(tester);

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

    expect(find.text('正解レーサーかな'), findsOneWidget);
    expect(find.text('誤答レーサーかな'), findsOneWidget);
    expect(find.text('さくっと'), findsOneWidget);
    expect(find.text('顔 → 選手名'), findsOneWidget);
    expect(find.textContaining('生年月日'), findsNWidgets(2));
    expect(find.textContaining('出身'), findsNWidgets(2));
    expect(find.textContaining('支部'), findsNWidgets(2));
    expect(find.textContaining('登録期'), findsNWidgets(2));
    expect(find.text('所属'), findsNothing);
    expect(find.text('問題のおさらい'), findsNothing);
    expect(find.textContaining('回答時間'), findsNothing);
  });

  testWidgets('can move to older mistakes with vertical swipe', (
    WidgetTester tester,
  ) async {
    _setMobileSurfaceSize(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          reviewRepositoryProvider.overrideWithValue(_MultiReviewRepository()),
          racerRepositoryProvider.overrideWithValue(_FakeRacerRepository()),
        ],
        child: const MaterialApp(home: Scaffold(body: ReviewScreen())),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('さくっと'), findsOneWidget);

    await tester.drag(find.byType(CarouselSlider), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.textContaining('じっくり'), findsOneWidget);
  });

  testWidgets('shows stylized empty state for no answer', (
    WidgetTester tester,
  ) async {
    _setMobileSurfaceSize(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          reviewRepositoryProvider.overrideWithValue(
            _NoAnswerReviewRepository(),
          ),
          racerRepositoryProvider.overrideWithValue(_FakeRacerRepository()),
        ],
        child: const MaterialApp(home: Scaffold(body: ReviewScreen())),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('NO ANSWER'), findsOneWidget);
    expect(find.text('画像なし'), findsNothing);
    expect(find.text('情報なし'), findsNothing);
  });

  testWidgets('limits progress indicators and shows overflow hints', (
    WidgetTester tester,
  ) async {
    _setMobileSurfaceSize(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          reviewRepositoryProvider.overrideWithValue(_ManyReviewRepository()),
          racerRepositoryProvider.overrideWithValue(_FakeRacerRepository()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ReviewScreen(initialIndex: 10)),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(_reviewIndicatorDots(), findsNWidgets(5));
    expect(
      find.byKey(const ValueKey<String>('review-indicator-overflow-before')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('review-indicator-overflow-after')),
      findsOneWidget,
    );
  });
}

Finder _reviewIndicatorDots() {
  return find.byWidgetPredicate((Widget widget) {
    final Key? key = widget.key;
    return key is ValueKey<String> && key.value.startsWith('review-indicator-dot-');
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

class _MultiReviewRepository implements ReviewRepository {
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
      ReviewMistakeEntry(
        mistakeId: 'mistake-2',
        resultId: 'result-2',
        sessionId: 'session-2',
        modeId: 'deep',
        modeLabel: 'じっくり',
        questionIndex: 5,
        mistakeSequence: 1,
        promptType: QuizPromptType.registrationToFace,
        prompt: 'この登録番号の選手は誰？',
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
        elapsedMs: 2140,
        outcome: QuizMistakeOutcome.wrongAnswer,
        createdAt: DateTime.utc(2026, 3, 30, 10),
      ),
    ];
  }
}

class _NoAnswerReviewRepository implements ReviewRepository {
  @override
  Future<List<ReviewMistakeEntry>> fetchMyMistakes() async {
    return <ReviewMistakeEntry>[
      ReviewMistakeEntry(
        mistakeId: 'mistake-no-answer',
        resultId: 'result-no-answer',
        sessionId: 'session-no-answer',
        modeId: 'quick',
        modeLabel: 'さくっと',
        questionIndex: 1,
        mistakeSequence: 0,
        promptType: QuizPromptType.faceToName,
        prompt: 'この選手は誰？',
        options: const <ReviewMistakeOption>[
          ReviewMistakeOption(racerId: 'correct', label: '正解レーサー'),
          ReviewMistakeOption(racerId: 'wrong', label: '誤答レーサー'),
        ],
        correctIndex: 0,
        selectedIndex: null,
        correctRacerId: 'correct',
        selectedRacerId: null,
        correctOption: const ReviewMistakeOption(
          racerId: 'correct',
          label: '正解レーサー',
        ),
        selectedOption: null,
        elapsedMs: 5000,
        outcome: QuizMistakeOutcome.timeout,
        createdAt: DateTime.utc(2026, 3, 31, 11),
      ),
    ];
  }
}

class _ManyReviewRepository implements ReviewRepository {
  @override
  Future<List<ReviewMistakeEntry>> fetchMyMistakes() async {
    return List<ReviewMistakeEntry>.generate(
      20,
      (int index) => ReviewMistakeEntry(
        mistakeId: 'mistake-$index',
        resultId: 'result-$index',
        sessionId: 'session-$index',
        modeId: 'quick',
        modeLabel: 'さくっと',
        questionIndex: index,
        mistakeSequence: index,
        promptType: QuizPromptType.faceToName,
        prompt: 'この選手は誰？ #$index',
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
        elapsedMs: 1000 + index,
        outcome: QuizMistakeOutcome.wrongAnswer,
        createdAt: DateTime.utc(2026, 3, 31, 10).subtract(
          Duration(minutes: index),
        ),
      ),
      growable: false,
    );
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
    registrationTerm: 98,
    racerClass: 'A1',
    gender: gender,
    imageUrl: 'https://example.com/$id.png',
    imageSource: 'seed',
    updatedAt: DateTime.utc(2026, 3, 31),
    isActive: true,
    birthDate: DateTime.utc(1990, 4, 2),
    birthPlace: '福岡県',
    homeBranch: '東京',
    affiliationBranch: '東京',
  );
}

void _setMobileSurfaceSize(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 932);
}
