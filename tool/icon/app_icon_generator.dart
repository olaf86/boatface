import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'boatface_icon_art.dart';

class AppIconSpec {
  const AppIconSpec({required this.path, required this.size});

  final String path;
  final int size;
}

const List<AppIconSpec> appIconSpecs = <AppIconSpec>[
  AppIconSpec(path: 'design/generated/app_icon_casual_1024.png', size: 1024),
  AppIconSpec(path: 'design/generated/app_icon_casual_512.png', size: 512),
  AppIconSpec(
    path: 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png',
    size: 20,
  ),
  AppIconSpec(
    path: 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png',
    size: 40,
  ),
  AppIconSpec(
    path: 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png',
    size: 60,
  ),
  AppIconSpec(
    path: 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png',
    size: 29,
  ),
  AppIconSpec(
    path: 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png',
    size: 58,
  ),
  AppIconSpec(
    path: 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png',
    size: 87,
  ),
  AppIconSpec(
    path: 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png',
    size: 40,
  ),
  AppIconSpec(
    path: 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png',
    size: 80,
  ),
  AppIconSpec(
    path: 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png',
    size: 120,
  ),
  AppIconSpec(
    path: 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png',
    size: 120,
  ),
  AppIconSpec(
    path: 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png',
    size: 180,
  ),
  AppIconSpec(
    path: 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png',
    size: 76,
  ),
  AppIconSpec(
    path: 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png',
    size: 152,
  ),
  AppIconSpec(
    path:
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png',
    size: 167,
  ),
  AppIconSpec(
    path:
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
    size: 1024,
  ),
  AppIconSpec(
    path: 'android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
    size: 48,
  ),
  AppIconSpec(
    path: 'android/app/src/main/res/mipmap-hdpi/ic_launcher.png',
    size: 72,
  ),
  AppIconSpec(
    path: 'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png',
    size: 96,
  ),
  AppIconSpec(
    path: 'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
    size: 144,
  ),
  AppIconSpec(
    path: 'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
    size: 192,
  ),
];

Future<void> generateBoatfaceAppIcons({
  List<AppIconSpec> specs = appIconSpecs,
}) async {
  final Map<int, Future<Uint8List>> pngCache = <int, Future<Uint8List>>{};

  for (final AppIconSpec spec in specs) {
    final Uint8List pngBytes = await pngCache.putIfAbsent(
      spec.size,
      () => _renderIconPng(spec.size),
    );
    final File output = File(spec.path);
    await output.parent.create(recursive: true);
    await output.writeAsBytes(pngBytes, flush: true);
  }
}

Future<Uint8List> _renderIconPng(int size) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final double canvasSize = size.toDouble();
  final ui.Canvas canvas = ui.Canvas(
    recorder,
    ui.Rect.fromLTWH(0, 0, canvasSize, canvasSize),
  );

  paintBoatfaceIcon(canvas, ui.Size(canvasSize, canvasSize));

  final ui.Image image = await recorder.endRecording().toImage(size, size);
  final ByteData? byteData = await image.toByteData(
    format: ui.ImageByteFormat.png,
  );
  if (byteData == null) {
    throw StateError('Failed to encode PNG for ${size}x$size.');
  }
  return byteData.buffer.asUint8List();
}
