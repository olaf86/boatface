import 'package:boatface/shared/privacy/ad_privacy_consent_controller.dart';
import 'package:boatface/shared/privacy/ad_privacy_consent_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('refreshes, gathers consent, and shows privacy options', () async {
    final FakeAdPrivacyConsentService service = FakeAdPrivacyConsentService();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        adPrivacyConsentServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    await container.read(adPrivacyConsentControllerProvider.future);
    expect(
      container.read(adPrivacyConsentControllerProvider).value?.consentStatus,
      AdPrivacyConsentStatus.required,
    );

    service.fetchResult = const AdPrivacyConsentInfo(
      consentStatus: AdPrivacyConsentStatus.obtained,
      canRequestAds: true,
      privacyOptionsStatus: AdPrivacyOptionsStatus.required,
      isConsentFormAvailable: true,
    );
    final AdPrivacyConsentInfo refreshed = await container
        .read(adPrivacyConsentControllerProvider.notifier)
        .refresh();
    expect(refreshed.consentStatus, AdPrivacyConsentStatus.obtained);

    service.gatherResult = const AdPrivacyConsentInfo(
      consentStatus: AdPrivacyConsentStatus.obtained,
      canRequestAds: true,
      privacyOptionsStatus: AdPrivacyOptionsStatus.notRequired,
      isConsentFormAvailable: false,
    );
    final AdPrivacyConsentInfo gathered = await container
        .read(adPrivacyConsentControllerProvider.notifier)
        .gatherConsent();
    expect(gathered.privacyOptionsStatus, AdPrivacyOptionsStatus.notRequired);

    service.privacyOptionsResult = const AdPrivacyConsentInfo(
      consentStatus: AdPrivacyConsentStatus.obtained,
      canRequestAds: true,
      privacyOptionsStatus: AdPrivacyOptionsStatus.required,
      isConsentFormAvailable: true,
      lastFormErrorMessage: 'noop',
    );
    final AdPrivacyConsentInfo updated = await container
        .read(adPrivacyConsentControllerProvider.notifier)
        .showPrivacyOptionsForm();
    expect(updated.lastFormErrorMessage, 'noop');
  });
}

class FakeAdPrivacyConsentService implements AdPrivacyConsentService {
  AdPrivacyConsentInfo fetchResult = const AdPrivacyConsentInfo(
    consentStatus: AdPrivacyConsentStatus.required,
    canRequestAds: false,
    privacyOptionsStatus: AdPrivacyOptionsStatus.required,
    isConsentFormAvailable: true,
  );
  AdPrivacyConsentInfo gatherResult = const AdPrivacyConsentInfo(
    consentStatus: AdPrivacyConsentStatus.obtained,
    canRequestAds: true,
    privacyOptionsStatus: AdPrivacyOptionsStatus.notRequired,
    isConsentFormAvailable: false,
  );
  AdPrivacyConsentInfo privacyOptionsResult = const AdPrivacyConsentInfo(
    consentStatus: AdPrivacyConsentStatus.obtained,
    canRequestAds: true,
    privacyOptionsStatus: AdPrivacyOptionsStatus.required,
    isConsentFormAvailable: true,
  );

  @override
  Future<AdPrivacyConsentInfo> fetchInfo() async => fetchResult;

  @override
  Future<AdPrivacyConsentInfo> gatherConsent() async => gatherResult;

  @override
  Future<AdPrivacyConsentInfo> showPrivacyOptionsForm() async =>
      privacyOptionsResult;
}
