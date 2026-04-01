import 'package:boatface/app/navigation/app_shell.dart';
import 'package:boatface/features/auth/application/auth_controller.dart';
import 'package:boatface/features/auth/domain/auth_state.dart';
import 'package:boatface/features/quiz/data/racer_master_models.dart';
import 'package:boatface/features/quiz/data/racer_repository.dart';
import 'package:boatface/features/quiz/data/quiz_data_providers.dart';
import 'package:boatface/features/quiz/domain/quiz_models.dart';
import 'package:boatface/features/ranking/data/ranking_repository.dart';
import 'package:boatface/features/ranking/domain/ranking_models.dart';
import 'package:boatface/features/profile/domain/user_profile.dart';
import 'package:boatface/features/review/data/review_repository.dart';
import 'package:boatface/features/review/domain/review_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('switches between bottom navigation tabs', (
    WidgetTester tester,
  ) async {
    _setMobileSurfaceSize(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          racerRepositoryProvider.overrideWithValue(_FakeRacerRepository()),
          reviewRepositoryProvider.overrideWithValue(_EmptyReviewRepository()),
          rankingRepositoryProvider.overrideWithValue(_FakeRankingRepository()),
          authStateProvider.overrideWith(
            (Ref ref) => Stream<AuthState>.value(
              const AuthState(
                uid: 'current-user',
                providerIds: <String>['anonymous'],
                providerLabel: '匿名ログイン',
                isAnonymous: true,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: AppShellScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('クイズモードを選択'), findsOneWidget);
    expect(find.text('モードを選んでクイズにチャレンジしよう！'), findsOneWidget);

    await tester.tap(find.text('学習'));
    await tester.pumpAndSettle();
    expect(find.text('振り返りを開く'), findsOneWidget);

    await tester.tap(find.text('振り返りを開く'));
    await tester.pumpAndSettle();
    expect(find.text('まだ振り返りデータがありません'), findsOneWidget);

    await tester.tap(find.text('ホームへ戻る'));
    await tester.pumpAndSettle();
    expect(find.text('クイズモードを選択'), findsOneWidget);

    await tester.tap(find.text('ランキング'));
    await tester.pumpAndSettle();
    expect(find.text('SCORE'), findsOneWidget);
  });
}

void _setMobileSurfaceSize(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 932);
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
      _buildRacer(id: 'r1', name: '一号'),
      _buildRacer(id: 'r2', name: '二号'),
      _buildRacer(id: 'r3', name: '三号'),
      _buildRacer(id: 'r4', name: '四号'),
    ];
  }
}

class _EmptyReviewRepository implements ReviewRepository {
  @override
  Future<List<ReviewMistakeEntry>> fetchMyMistakes() async {
    return const <ReviewMistakeEntry>[];
  }
}

class _FakeRankingRepository implements RankingRepository {
  @override
  Future<RankingSnapshot> fetchRankings({
    required String modeId,
    required RankingPeriod period,
    int limit = 50,
  }) async {
    return RankingSnapshot(
      modeId: modeId,
      period: period,
      generatedAt: DateTime.utc(2026, 3, 22, 12),
      entries: <RankingEntry>[
        const RankingEntry(
          rank: 1,
          userId: 'user-1',
          displayName: '一位ユーザー',
          region: _tokyo,
          score: 1200,
          totalAnswerTimeMs: 32100,
        ),
      ],
    );
  }
}

RacerProfile _buildRacer({required String id, required String name}) {
  return RacerProfile(
    id: id,
    name: name,
    nameKana: '$nameかな',
    registrationNumber: 1000,
    registrationTerm: 99,
    racerClass: 'A1',
    gender: 'male',
    imageUrl: 'https://example.com/$id.png',
    imageSource: 'seed',
    updatedAt: DateTime.utc(2026, 3, 31),
    isActive: true,
  );
}

const UserRegion _tokyo = UserRegion(
  category: UserRegionCategory.prefecture,
  code: 'tokyo',
  label: '東京都',
);
