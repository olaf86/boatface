import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tracking_transparency_service.dart';

final AutoDisposeAsyncNotifierProvider<
  TrackingTransparencyController,
  TrackingTransparencyInfo
>
trackingTransparencyControllerProvider =
    AutoDisposeAsyncNotifierProvider<
      TrackingTransparencyController,
      TrackingTransparencyInfo
    >(TrackingTransparencyController.new);

class TrackingTransparencyController
    extends AutoDisposeAsyncNotifier<TrackingTransparencyInfo> {
  TrackingTransparencyService get _service =>
      ref.read(trackingTransparencyServiceProvider);

  @override
  Future<TrackingTransparencyInfo> build() {
    return _service.fetchInfo();
  }

  Future<TrackingTransparencyInfo> refresh() async {
    state = const AsyncLoading<TrackingTransparencyInfo>();
    state = await AsyncValue.guard<TrackingTransparencyInfo>(
      _service.fetchInfo,
    );
    return _requireValue();
  }

  Future<TrackingTransparencyInfo> requestAuthorization() async {
    state = const AsyncLoading<TrackingTransparencyInfo>();
    state = await AsyncValue.guard<TrackingTransparencyInfo>(
      _service.requestAuthorization,
    );
    return _requireValue();
  }

  Future<void> openSettings() {
    return _service.openSettings();
  }

  TrackingTransparencyInfo _requireValue() {
    final TrackingTransparencyInfo? value = state.valueOrNull;
    if (value != null) {
      return value;
    }
    throw StateError('ATT state is unavailable.');
  }
}
