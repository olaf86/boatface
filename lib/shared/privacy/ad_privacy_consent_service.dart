import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../environment/app_environment.dart';

final Provider<AdPrivacyConsentService> adPrivacyConsentServiceProvider =
    Provider<AdPrivacyConsentService>((Ref ref) {
      final AppEnvironment environment = ref.read(appEnvironmentProvider);
      return PlatformAdPrivacyConsentService(
        umpDebugGeography: environment.isStaging
            ? environment.umpDebugGeography
            : UmpDebugGeography.disabled,
        umpTestDeviceIds: environment.isStaging
            ? environment.umpTestDeviceIds
            : const <String>[],
      );
    });

enum AdPrivacyConsentStatus { unknown, notRequired, required, obtained }

enum AdPrivacyOptionsStatus { unknown, notRequired, required }

class AdPrivacyConsentInfo {
  const AdPrivacyConsentInfo({
    required this.consentStatus,
    required this.canRequestAds,
    required this.privacyOptionsStatus,
    required this.isConsentFormAvailable,
    this.lastFormErrorMessage,
  });

  const AdPrivacyConsentInfo.unsupported()
    : this(
        consentStatus: AdPrivacyConsentStatus.unknown,
        canRequestAds: false,
        privacyOptionsStatus: AdPrivacyOptionsStatus.notRequired,
        isConsentFormAvailable: false,
      );

  final AdPrivacyConsentStatus consentStatus;
  final bool canRequestAds;
  final AdPrivacyOptionsStatus privacyOptionsStatus;
  final bool isConsentFormAvailable;
  final String? lastFormErrorMessage;

  bool get privacyOptionsRequired =>
      privacyOptionsStatus == AdPrivacyOptionsStatus.required;

  bool get requiresConsentForAds =>
      consentStatus == AdPrivacyConsentStatus.required && !canRequestAds;

  String get consentStatusLabel => switch (consentStatus) {
    AdPrivacyConsentStatus.notRequired => '不要',
    AdPrivacyConsentStatus.required => '確認が必要',
    AdPrivacyConsentStatus.obtained => '同意済み',
    AdPrivacyConsentStatus.unknown => '未確認',
  };

  String get privacyOptionsStatusLabel => switch (privacyOptionsStatus) {
    AdPrivacyOptionsStatus.required => '見直し可能',
    AdPrivacyOptionsStatus.notRequired => '不要',
    AdPrivacyOptionsStatus.unknown => '未確認',
  };

  AdPrivacyConsentInfo copyWith({
    AdPrivacyConsentStatus? consentStatus,
    bool? canRequestAds,
    AdPrivacyOptionsStatus? privacyOptionsStatus,
    bool? isConsentFormAvailable,
    String? lastFormErrorMessage,
  }) {
    return AdPrivacyConsentInfo(
      consentStatus: consentStatus ?? this.consentStatus,
      canRequestAds: canRequestAds ?? this.canRequestAds,
      privacyOptionsStatus: privacyOptionsStatus ?? this.privacyOptionsStatus,
      isConsentFormAvailable:
          isConsentFormAvailable ?? this.isConsentFormAvailable,
      lastFormErrorMessage: lastFormErrorMessage,
    );
  }
}

abstract class AdPrivacyConsentService {
  Future<AdPrivacyConsentInfo> fetchInfo();
  Future<AdPrivacyConsentInfo> gatherConsent();
  Future<AdPrivacyConsentInfo> showPrivacyOptionsForm();
}

class PlatformAdPrivacyConsentService implements AdPrivacyConsentService {
  PlatformAdPrivacyConsentService({
    ConsentInformation? consentInformation,
    this.umpDebugGeography = UmpDebugGeography.disabled,
    this.umpTestDeviceIds = const <String>[],
    bool? supportsPrivacyMessagingOverride,
    Future<String?> Function()? loadAndShowConsentFormIfRequiredOverride,
  }) : _consentInformation = consentInformation ?? ConsentInformation.instance,
       _supportsPrivacyMessagingOverride = supportsPrivacyMessagingOverride,
       _loadAndShowConsentFormIfRequiredOverride =
           loadAndShowConsentFormIfRequiredOverride;

  final ConsentInformation _consentInformation;
  final UmpDebugGeography umpDebugGeography;
  final List<String> umpTestDeviceIds;
  final bool? _supportsPrivacyMessagingOverride;
  final Future<String?> Function()? _loadAndShowConsentFormIfRequiredOverride;

  @override
  Future<AdPrivacyConsentInfo> fetchInfo() async {
    if (!_supportsPrivacyMessaging) {
      return const AdPrivacyConsentInfo.unsupported();
    }
    final ConsentStatus consentStatus = await _consentInformation
        .getConsentStatus();
    final bool canRequestAds = await _consentInformation.canRequestAds();
    final PrivacyOptionsRequirementStatus privacyOptionsRequirementStatus =
        await _consentInformation.getPrivacyOptionsRequirementStatus();
    final bool isConsentFormAvailable = await _consentInformation
        .isConsentFormAvailable();
    return AdPrivacyConsentInfo(
      consentStatus: _mapConsentStatus(consentStatus),
      canRequestAds: canRequestAds,
      privacyOptionsStatus: _mapPrivacyOptionsStatus(
        privacyOptionsRequirementStatus,
      ),
      isConsentFormAvailable: isConsentFormAvailable,
    );
  }

  @override
  Future<AdPrivacyConsentInfo> gatherConsent() async {
    if (!_supportsPrivacyMessaging) {
      return const AdPrivacyConsentInfo.unsupported();
    }

    String? lastFormErrorMessage;
    try {
      await _requestConsentInfoUpdate();
      lastFormErrorMessage = await _loadAndShowConsentFormIfRequired();
    } catch (error) {
      lastFormErrorMessage = error.toString();
    }

    final AdPrivacyConsentInfo info = await fetchInfo();
    return info.copyWith(lastFormErrorMessage: lastFormErrorMessage);
  }

  @override
  Future<AdPrivacyConsentInfo> showPrivacyOptionsForm() async {
    if (!_supportsPrivacyMessaging) {
      return const AdPrivacyConsentInfo.unsupported();
    }

    final Completer<FormError?> completer = Completer<FormError?>();
    await ConsentForm.showPrivacyOptionsForm((FormError? formError) {
      if (!completer.isCompleted) {
        completer.complete(formError);
      }
    });
    final FormError? formError = await completer.future;
    final AdPrivacyConsentInfo info = await fetchInfo();
    return info.copyWith(lastFormErrorMessage: formError?.message);
  }

  Future<void> _requestConsentInfoUpdate() {
    final Completer<void> completer = Completer<void>();
    _consentInformation.requestConsentInfoUpdate(
      ConsentRequestParameters(
        consentDebugSettings: _buildConsentDebugSettings(),
      ),
      () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      (FormError error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );
    return completer.future;
  }

  ConsentDebugSettings? _buildConsentDebugSettings() {
    final DebugGeography debugGeography = _mapDebugGeography(
      umpDebugGeography,
    );
    if (debugGeography == DebugGeography.debugGeographyDisabled &&
        umpTestDeviceIds.isEmpty) {
      return null;
    }
    return ConsentDebugSettings(
      debugGeography: debugGeography,
      testIdentifiers: umpTestDeviceIds.isEmpty ? null : umpTestDeviceIds,
    );
  }

  Future<String?> _loadAndShowConsentFormIfRequired() {
    final Future<String?> Function()? override =
        _loadAndShowConsentFormIfRequiredOverride;
    if (override != null) {
      return override();
    }
    final Completer<String?> completer = Completer<String?>();
    ConsentForm.loadAndShowConsentFormIfRequired((FormError? formError) {
      if (!completer.isCompleted) {
        completer.complete(formError?.message);
      }
    });
    return completer.future;
  }

  bool get _supportsPrivacyMessaging =>
      _supportsPrivacyMessagingOverride ?? (Platform.isAndroid || Platform.isIOS);

  AdPrivacyConsentStatus _mapConsentStatus(ConsentStatus status) {
    return switch (status) {
      ConsentStatus.notRequired => AdPrivacyConsentStatus.notRequired,
      ConsentStatus.required => AdPrivacyConsentStatus.required,
      ConsentStatus.obtained => AdPrivacyConsentStatus.obtained,
      ConsentStatus.unknown => AdPrivacyConsentStatus.unknown,
    };
  }

  AdPrivacyOptionsStatus _mapPrivacyOptionsStatus(
    PrivacyOptionsRequirementStatus status,
  ) {
    return switch (status) {
      PrivacyOptionsRequirementStatus.required =>
        AdPrivacyOptionsStatus.required,
      PrivacyOptionsRequirementStatus.notRequired =>
        AdPrivacyOptionsStatus.notRequired,
      PrivacyOptionsRequirementStatus.unknown => AdPrivacyOptionsStatus.unknown,
    };
  }

  DebugGeography _mapDebugGeography(UmpDebugGeography geography) {
    return switch (geography) {
      UmpDebugGeography.eea => DebugGeography.debugGeographyEea,
      UmpDebugGeography.regulatedUsState =>
        DebugGeography.debugGeographyRegulatedUsState,
      UmpDebugGeography.other => DebugGeography.debugGeographyOther,
      UmpDebugGeography.disabled => DebugGeography.debugGeographyDisabled,
    };
  }
}
