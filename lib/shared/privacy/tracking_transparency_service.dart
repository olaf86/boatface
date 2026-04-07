import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TrackingTransparencyStatus {
  notSupported,
  notDetermined,
  restricted,
  denied,
  authorized,
}

class TrackingTransparencyInfo {
  const TrackingTransparencyInfo({required this.status, this.idfa});

  const TrackingTransparencyInfo.unsupported()
    : status = TrackingTransparencyStatus.notSupported,
      idfa = null;

  final TrackingTransparencyStatus status;
  final String? idfa;

  bool get canRequestAuthorization =>
      status == TrackingTransparencyStatus.notDetermined;

  bool get canOpenSettings =>
      status == TrackingTransparencyStatus.denied ||
      status == TrackingTransparencyStatus.restricted;

  bool get hasIdfa => idfa != null && idfa!.isNotEmpty;

  String get statusLabel {
    return switch (status) {
      TrackingTransparencyStatus.notSupported => '利用不可',
      TrackingTransparencyStatus.notDetermined => '未確認',
      TrackingTransparencyStatus.restricted => '制限中',
      TrackingTransparencyStatus.denied => '未許可',
      TrackingTransparencyStatus.authorized => '許可済み',
    };
  }
}

abstract class TrackingTransparencyService {
  Future<TrackingTransparencyInfo> fetchInfo();
  Future<TrackingTransparencyInfo> requestAuthorization();
  Future<void> openSettings();
}

final Provider<TrackingTransparencyService>
trackingTransparencyServiceProvider = Provider<TrackingTransparencyService>((
  Ref ref,
) {
  return PlatformTrackingTransparencyService();
});

final Provider<bool> trackingTransparencySupportedProvider = Provider<bool>((
  Ref ref,
) {
  return Platform.isIOS;
});

class PlatformTrackingTransparencyService
    implements TrackingTransparencyService {
  PlatformTrackingTransparencyService({
    MethodChannel? channel,
    bool? isIosPlatform,
  }) : _channel = channel ?? _kChannel,
       _isIosPlatform = isIosPlatform ?? Platform.isIOS;

  static const MethodChannel _kChannel = MethodChannel(
    'dev.asobo.boatface/tracking_transparency',
  );

  final MethodChannel _channel;
  final bool _isIosPlatform;

  @override
  Future<TrackingTransparencyInfo> fetchInfo() async {
    return _invokeInfoMethod('getTrackingInfo');
  }

  @override
  Future<TrackingTransparencyInfo> requestAuthorization() async {
    return _invokeInfoMethod('requestTrackingAuthorization');
  }

  @override
  Future<void> openSettings() async {
    if (!_isIosPlatform) {
      return;
    }
    await _channel.invokeMethod<void>('openAppSettings');
  }

  Future<TrackingTransparencyInfo> _invokeInfoMethod(String method) async {
    if (!_isIosPlatform) {
      return const TrackingTransparencyInfo.unsupported();
    }
    final Map<Object?, Object?>? raw = await _channel
        .invokeMapMethod<Object?, Object?>(method);
    if (raw == null) {
      return const TrackingTransparencyInfo.unsupported();
    }
    return TrackingTransparencyInfo(
      status: _parseStatus(raw['status'] as String?),
      idfa: raw['idfa'] as String?,
    );
  }

  TrackingTransparencyStatus _parseStatus(String? rawStatus) {
    return switch (rawStatus) {
      'notDetermined' => TrackingTransparencyStatus.notDetermined,
      'restricted' => TrackingTransparencyStatus.restricted,
      'denied' => TrackingTransparencyStatus.denied,
      'authorized' => TrackingTransparencyStatus.authorized,
      _ => TrackingTransparencyStatus.notSupported,
    };
  }
}
