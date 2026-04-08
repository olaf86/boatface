import 'dart:async';

import 'package:boatface/features/quiz/data/quiz_backend_repository.dart';
import 'package:boatface/features/quiz/data/quiz_data_providers.dart';
import 'package:boatface/features/quiz/data/racer_master_models.dart';
import 'package:boatface/features/quiz/data/racer_repository.dart';
import 'package:boatface/features/quiz/domain/quiz_backend_models.dart';
import 'package:boatface/features/quiz/domain/quiz_models.dart';
import 'package:boatface/features/quiz/domain/quiz_modes.dart';
import 'package:boatface/features/quiz/presentation/quiz_rule_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('aggregates repeated prompt types for careful mode', (
    WidgetTester tester,
  ) async {
    final QuizModeConfig carefulMode = kQuizModes.firstWhere(
      (QuizModeConfig mode) => mode.id == 'careful',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          racerRepositoryProvider.overrideWithValue(_FakeRacerRepository()),
          quizBackendRepositoryProvider.overrideWithValue(
            _FakeQuizBackendRepository(),
          ),
        ],
        child: MaterialApp(home: QuizRuleScreen(baseMode: carefulMode)),
      ),
    );

    await tester.pump();

    expect(find.text('30 問'), findsOneWidget);
    expect(find.text('15 問'), findsNWidgets(2));
  });

  testWidgets('keeps start button loading while route transition begins', (
    WidgetTester tester,
  ) async {
    final _FakeQuizBackendRepository backend = _FakeQuizBackendRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          racerRepositoryProvider.overrideWithValue(_FakeRacerRepository()),
          quizBackendRepositoryProvider.overrideWithValue(backend),
        ],
        child: MaterialApp(home: QuizRuleScreen(baseMode: kQuizModes.first)),
      ),
    );

    await tester.pump();
    expect(find.text('スタート'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'スタート'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    backend.completeSession();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('スタート'), findsNothing);
  });
}

class _FakeQuizBackendRepository implements QuizBackendRepository {
  final Completer<QuizSessionLease> _sessionCompleter =
      Completer<QuizSessionLease>();

  void completeSession() {
    if (_sessionCompleter.isCompleted) {
      return;
    }
    _sessionCompleter.complete(
      QuizSessionLease(
        sessionId: 'session-1',
        expiresAt: DateTime.utc(2026, 3, 24, 12),
      ),
    );
  }

  @override
  Future<QuizSessionLease> createQuizSession({required String modeId}) {
    return _sessionCompleter.future;
  }

  @override
  Future<QuizResultSubmissionReceipt> submitQuizResult({
    required String sessionId,
    required QuizResultSummary summary,
  }) {
    throw UnimplementedError();
  }
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
        nameKana: 'センシュ$index',
        registrationNumber: 5000 + index,
        registrationTerm: 90 + index,
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
