import 'package:boatface/features/auth/application/auth_controller.dart';
import 'package:boatface/features/auth/domain/auth_state.dart';
import 'package:boatface/features/home/presentation/settings_screen.dart';
import 'package:boatface/features/profile/application/user_profile_controller.dart';
import 'package:boatface/features/profile/domain/user_profile.dart';
import 'package:boatface/features/quiz/data/racer_master_models.dart';
import 'package:boatface/features/quiz/data/racer_repository.dart';
import 'package:boatface/features/quiz/data/quiz_data_providers.dart';
import 'package:boatface/features/quiz/domain/quiz_models.dart';
import 'package:boatface/shared/environment/app_environment.dart';
import 'package:boatface/shared/privacy/tracking_transparency_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows IDFA controls in staging', (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildSettingsScreen(
        appEnvironment: const AppEnvironment(isProduction: false),
        trackingService: _FakeTrackingTransparencyService(
          const TrackingTransparencyInfo(
            status: TrackingTransparencyStatus.authorized,
            idfa: 'ABC-123',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('広告とプライバシー'), findsOneWidget);
    expect(find.text('IDFA'), findsOneWidget);
    expect(find.text('ABC-123'), findsOneWidget);
    expect(find.text('IDFA をコピー'), findsOneWidget);
  });

  testWidgets('hides IDFA controls in production', (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildSettingsScreen(
        appEnvironment: const AppEnvironment(isProduction: true),
        trackingService: _FakeTrackingTransparencyService(
          const TrackingTransparencyInfo(
            status: TrackingTransparencyStatus.authorized,
            idfa: 'ABC-123',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('広告とプライバシー'), findsOneWidget);
    expect(find.text('IDFA'), findsNothing);
    expect(find.text('ABC-123'), findsNothing);
    expect(find.text('IDFA をコピー'), findsNothing);
    expect(find.text('ATT 状態'), findsOneWidget);
  });
}

Widget _buildSettingsScreen({
  required AppEnvironment appEnvironment,
  required TrackingTransparencyService trackingService,
}) {
  return ProviderScope(
    overrides: <Override>[
      authStateProvider.overrideWith(
        (Ref ref) => Stream<AuthState>.value(const AuthState.signedOut()),
      ),
      userProfileProvider.overrideWith((Ref ref) async => _testProfile),
      racerRepositoryProvider.overrideWithValue(_FakeRacerRepository()),
      appEnvironmentProvider.overrideWithValue(appEnvironment),
      trackingTransparencyServiceProvider.overrideWithValue(trackingService),
    ],
    child: const MaterialApp(home: SettingsScreen()),
  );
}

const UserProfile _testProfile = UserProfile(
  uid: 'user-1',
  displayName: 'Tester',
  nickname: null,
  rankingDisplayName: 'Tester',
  region: null,
  quizProgress: UserQuizProgress.empty(),
);

class _FakeTrackingTransparencyService implements TrackingTransparencyService {
  _FakeTrackingTransparencyService(this._info);

  final TrackingTransparencyInfo _info;

  @override
  Future<TrackingTransparencyInfo> fetchInfo() async => _info;

  @override
  Future<void> openSettings() async {}

  @override
  Future<TrackingTransparencyInfo> requestAuthorization() async => _info;
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
  List<RacerProfile> requireCachedAll() => const <RacerProfile>[];

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
