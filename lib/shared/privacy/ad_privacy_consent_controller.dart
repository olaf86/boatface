import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ad_privacy_consent_service.dart';

final AutoDisposeAsyncNotifierProvider<
  AdPrivacyConsentController,
  AdPrivacyConsentInfo
>
adPrivacyConsentControllerProvider =
    AutoDisposeAsyncNotifierProvider<
      AdPrivacyConsentController,
      AdPrivacyConsentInfo
    >(AdPrivacyConsentController.new);

class AdPrivacyConsentController
    extends AutoDisposeAsyncNotifier<AdPrivacyConsentInfo> {
  AdPrivacyConsentService get _service =>
      ref.read(adPrivacyConsentServiceProvider);

  @override
  Future<AdPrivacyConsentInfo> build() {
    return _service.fetchInfo();
  }

  Future<AdPrivacyConsentInfo> refresh() async {
    state = const AsyncLoading<AdPrivacyConsentInfo>();
    state = await AsyncValue.guard<AdPrivacyConsentInfo>(_service.fetchInfo);
    return _requireValue();
  }

  Future<AdPrivacyConsentInfo> gatherConsent() async {
    state = const AsyncLoading<AdPrivacyConsentInfo>();
    state = await AsyncValue.guard<AdPrivacyConsentInfo>(
      _service.gatherConsent,
    );
    return _requireValue();
  }

  Future<AdPrivacyConsentInfo> showPrivacyOptionsForm() async {
    state = const AsyncLoading<AdPrivacyConsentInfo>();
    state = await AsyncValue.guard<AdPrivacyConsentInfo>(
      _service.showPrivacyOptionsForm,
    );
    return _requireValue();
  }

  AdPrivacyConsentInfo _requireValue() {
    final AdPrivacyConsentInfo? value = state.valueOrNull;
    if (value != null) {
      return value;
    }
    throw StateError('Ad privacy consent state is unavailable.');
  }
}
