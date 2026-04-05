import 'package:boatface/shared/privacy/tracking_transparency_controller.dart';
import 'package:boatface/shared/privacy/tracking_transparency_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlatformTrackingTransparencyService', () {
    const MethodChannel channel = MethodChannel(
      'dev.asobo.boatface/tracking_transparency',
    );

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('returns unsupported on non-iOS platforms', () async {
      final service = PlatformTrackingTransparencyService(
        channel: channel,
        isIosPlatform: false,
      );

      final TrackingTransparencyInfo info = await service.fetchInfo();

      expect(info.status, TrackingTransparencyStatus.notSupported);
      expect(info.idfa, isNull);
    });

    test('parses ATT info from platform channel', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            expect(call.method, 'getTrackingInfo');
            return <String, Object?>{
              'status': 'authorized',
              'idfa': '12345678-1234-1234-1234-123456789ABC',
            };
          });

      final service = PlatformTrackingTransparencyService(
        channel: channel,
        isIosPlatform: true,
      );

      final TrackingTransparencyInfo info = await service.fetchInfo();

      expect(info.status, TrackingTransparencyStatus.authorized);
      expect(info.idfa, '12345678-1234-1234-1234-123456789ABC');
      expect(info.hasIdfa, isTrue);
    });
  });

  group('TrackingTransparencyController', () {
    test('refreshes and requests authorization through the service', () async {
      final FakeTrackingTransparencyService service =
          FakeTrackingTransparencyService();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          trackingTransparencyServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      await container.read(trackingTransparencyControllerProvider.future);
      expect(
        container.read(trackingTransparencyControllerProvider).value?.status,
        TrackingTransparencyStatus.notDetermined,
      );

      service.fetchResult = const TrackingTransparencyInfo(
        status: TrackingTransparencyStatus.denied,
      );
      final TrackingTransparencyInfo refreshed = await container
          .read(trackingTransparencyControllerProvider.notifier)
          .refresh();
      expect(refreshed.status, TrackingTransparencyStatus.denied);

      service.requestResult = const TrackingTransparencyInfo(
        status: TrackingTransparencyStatus.authorized,
        idfa: 'ABC',
      );
      final TrackingTransparencyInfo requested = await container
          .read(trackingTransparencyControllerProvider.notifier)
          .requestAuthorization();
      expect(requested.status, TrackingTransparencyStatus.authorized);
      expect(requested.idfa, 'ABC');
    });
  });
}

class FakeTrackingTransparencyService implements TrackingTransparencyService {
  TrackingTransparencyInfo fetchResult = const TrackingTransparencyInfo(
    status: TrackingTransparencyStatus.notDetermined,
  );
  TrackingTransparencyInfo requestResult = const TrackingTransparencyInfo(
    status: TrackingTransparencyStatus.authorized,
  );

  @override
  Future<TrackingTransparencyInfo> fetchInfo() async => fetchResult;

  @override
  Future<void> openSettings() async {}

  @override
  Future<TrackingTransparencyInfo> requestAuthorization() async =>
      requestResult;
}
