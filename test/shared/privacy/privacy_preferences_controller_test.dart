import 'package:boatface/shared/privacy/ad_privacy_consent_service.dart';
import 'package:boatface/shared/privacy/privacy_preferences_controller.dart';
import 'package:boatface/shared/privacy/tracking_transparency_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'preparePrivacyMessagingOnAppStart requests ATT only when ads can be requested',
    () async {
      final _FakeAdPrivacyConsentService adPrivacyService =
          _FakeAdPrivacyConsentService(
            gatherResult: const AdPrivacyConsentInfo(
              consentStatus: AdPrivacyConsentStatus.obtained,
              canRequestAds: true,
              privacyOptionsStatus: AdPrivacyOptionsStatus.required,
              isConsentFormAvailable: true,
            ),
          );
      final _FakeTrackingTransparencyService trackingService =
          _FakeTrackingTransparencyService(
            fetchResult: const TrackingTransparencyInfo(
              status: TrackingTransparencyStatus.notDetermined,
            ),
            requestResult: const TrackingTransparencyInfo(
              status: TrackingTransparencyStatus.authorized,
              idfa: 'ABC',
            ),
          );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          adPrivacyConsentServiceProvider.overrideWithValue(adPrivacyService),
          trackingTransparencyServiceProvider.overrideWithValue(
            trackingService,
          ),
          trackingTransparencySupportedProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(privacyPreferencesControllerProvider)
          .preparePrivacyMessagingOnAppStart();

      expect(adPrivacyService.gatherCallCount, 1);
      expect(trackingService.fetchCallCount, greaterThanOrEqualTo(2));
      expect(trackingService.requestCallCount, 1);
    },
  );

  test(
    'preparePrivacyMessagingOnAppStart skips ATT when UMP disallows ads',
    () async {
      final _FakeAdPrivacyConsentService adPrivacyService =
          _FakeAdPrivacyConsentService(
            gatherResult: const AdPrivacyConsentInfo(
              consentStatus: AdPrivacyConsentStatus.required,
              canRequestAds: false,
              privacyOptionsStatus: AdPrivacyOptionsStatus.required,
              isConsentFormAvailable: true,
            ),
          );
      final _FakeTrackingTransparencyService trackingService =
          _FakeTrackingTransparencyService(
            fetchResult: const TrackingTransparencyInfo(
              status: TrackingTransparencyStatus.notDetermined,
            ),
            requestResult: const TrackingTransparencyInfo(
              status: TrackingTransparencyStatus.authorized,
              idfa: 'ABC',
            ),
          );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          adPrivacyConsentServiceProvider.overrideWithValue(adPrivacyService),
          trackingTransparencyServiceProvider.overrideWithValue(
            trackingService,
          ),
          trackingTransparencySupportedProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(privacyPreferencesControllerProvider)
          .preparePrivacyMessagingOnAppStart();

      expect(adPrivacyService.gatherCallCount, 1);
      expect(trackingService.fetchCallCount, 0);
      expect(trackingService.requestCallCount, 0);
    },
  );

  test(
    'refresh and settings actions are delegated through the controller',
    () async {
      final _FakeAdPrivacyConsentService adPrivacyService =
          _FakeAdPrivacyConsentService(
            gatherResult: const AdPrivacyConsentInfo(
              consentStatus: AdPrivacyConsentStatus.obtained,
              canRequestAds: true,
              privacyOptionsStatus: AdPrivacyOptionsStatus.required,
              isConsentFormAvailable: true,
            ),
            fetchResult: const AdPrivacyConsentInfo(
              consentStatus: AdPrivacyConsentStatus.obtained,
              canRequestAds: true,
              privacyOptionsStatus: AdPrivacyOptionsStatus.required,
              isConsentFormAvailable: true,
            ),
            privacyOptionsResult: const AdPrivacyConsentInfo(
              consentStatus: AdPrivacyConsentStatus.obtained,
              canRequestAds: true,
              privacyOptionsStatus: AdPrivacyOptionsStatus.notRequired,
              isConsentFormAvailable: false,
            ),
          );
      final _FakeTrackingTransparencyService trackingService =
          _FakeTrackingTransparencyService(
            fetchResult: const TrackingTransparencyInfo(
              status: TrackingTransparencyStatus.authorized,
              idfa: 'ABC',
            ),
            requestResult: const TrackingTransparencyInfo(
              status: TrackingTransparencyStatus.authorized,
              idfa: 'ABC',
            ),
          );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          adPrivacyConsentServiceProvider.overrideWithValue(adPrivacyService),
          trackingTransparencyServiceProvider.overrideWithValue(
            trackingService,
          ),
          trackingTransparencySupportedProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      final PrivacyPreferencesController controller = container.read(
        privacyPreferencesControllerProvider,
      );

      await controller.refreshPrivacyState();
      await controller.requestTrackingAuthorization();
      await controller.openTrackingSettings();
      final AdPrivacyConsentInfo info = await controller.showPrivacyOptions();

      expect(adPrivacyService.fetchCallCount, greaterThanOrEqualTo(2));
      expect(trackingService.fetchCallCount, greaterThanOrEqualTo(2));
      expect(trackingService.requestCallCount, 1);
      expect(trackingService.openSettingsCallCount, 1);
      expect(adPrivacyService.showPrivacyOptionsCallCount, 1);
      expect(info.privacyOptionsStatus, AdPrivacyOptionsStatus.notRequired);
    },
  );
}

class _FakeAdPrivacyConsentService implements AdPrivacyConsentService {
  _FakeAdPrivacyConsentService({
    required this.gatherResult,
    AdPrivacyConsentInfo? fetchResult,
    AdPrivacyConsentInfo? privacyOptionsResult,
  }) : fetchResult = fetchResult ?? gatherResult,
       privacyOptionsResult = privacyOptionsResult ?? gatherResult;

  final AdPrivacyConsentInfo gatherResult;
  final AdPrivacyConsentInfo fetchResult;
  final AdPrivacyConsentInfo privacyOptionsResult;
  int gatherCallCount = 0;
  int fetchCallCount = 0;
  int showPrivacyOptionsCallCount = 0;

  @override
  Future<AdPrivacyConsentInfo> fetchInfo() async {
    fetchCallCount += 1;
    return fetchResult;
  }

  @override
  Future<AdPrivacyConsentInfo> gatherConsent() async {
    gatherCallCount += 1;
    return gatherResult;
  }

  @override
  Future<AdPrivacyConsentInfo> showPrivacyOptionsForm() async {
    showPrivacyOptionsCallCount += 1;
    return privacyOptionsResult;
  }
}

class _FakeTrackingTransparencyService implements TrackingTransparencyService {
  _FakeTrackingTransparencyService({
    required this.fetchResult,
    required this.requestResult,
  });

  final TrackingTransparencyInfo fetchResult;
  final TrackingTransparencyInfo requestResult;
  int fetchCallCount = 0;
  int requestCallCount = 0;
  int openSettingsCallCount = 0;

  @override
  Future<TrackingTransparencyInfo> fetchInfo() async {
    fetchCallCount += 1;
    return fetchResult;
  }

  @override
  Future<void> openSettings() async {
    openSettingsCallCount += 1;
  }

  @override
  Future<TrackingTransparencyInfo> requestAuthorization() async {
    requestCallCount += 1;
    return requestResult;
  }
}
