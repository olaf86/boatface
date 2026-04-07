import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ad_privacy_consent_controller.dart';
import 'ad_privacy_consent_service.dart';
import 'tracking_transparency_controller.dart';
import 'tracking_transparency_service.dart';

final Provider<PrivacyPreferencesController>
privacyPreferencesControllerProvider = Provider<PrivacyPreferencesController>((
  Ref ref,
) {
  return PrivacyPreferencesController(ref);
});

class PrivacyPreferencesController {
  const PrivacyPreferencesController(this._ref);

  final Ref _ref;

  Future<void> preparePrivacyMessagingOnAppStart() async {
    AdPrivacyConsentInfo? consentInfo;
    try {
      consentInfo = await _ref
          .read(adPrivacyConsentControllerProvider.notifier)
          .gatherConsent();
    } catch (_) {
      // Privacy state remains available through the controller's error state.
    }
    if (consentInfo != null && !consentInfo.canRequestAds) {
      return;
    }

    final bool supportsTrackingTransparency = _ref.read(
      trackingTransparencySupportedProvider,
    );
    if (!supportsTrackingTransparency) {
      return;
    }

    TrackingTransparencyInfo info = await _ref
        .read(trackingTransparencyControllerProvider.notifier)
        .refresh();
    if (info.status == TrackingTransparencyStatus.notDetermined) {
      await _ref
          .read(trackingTransparencyControllerProvider.notifier)
          .requestAuthorization();
      await _ref
          .read(trackingTransparencyControllerProvider.notifier)
          .refresh();
    }
  }

  Future<void> refreshPrivacyState() async {
    await _ref.read(adPrivacyConsentControllerProvider.notifier).refresh();
    await _ref.read(trackingTransparencyControllerProvider.notifier).refresh();
  }

  Future<TrackingTransparencyInfo> requestTrackingAuthorization() {
    return _ref
        .read(trackingTransparencyControllerProvider.notifier)
        .requestAuthorization();
  }

  Future<void> openTrackingSettings() {
    return _ref
        .read(trackingTransparencyControllerProvider.notifier)
        .openSettings();
  }

  Future<AdPrivacyConsentInfo> showPrivacyOptions() async {
    final AdPrivacyConsentInfo info = await _ref
        .read(adPrivacyConsentControllerProvider.notifier)
        .showPrivacyOptionsForm();
    await _ref.read(trackingTransparencyControllerProvider.notifier).refresh();
    return info;
  }
}
