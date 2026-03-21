import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import '../tool/icon/boatface_icon_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate boatface icon draft png', () async {
    const int size = 1024;
    final double canvasSize = size.toDouble();
    final ui.PictureRecorder recorder = ui.PictureRecorder();
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
      fail('Failed to encode PNG.');
    }

    final File output = File('design/generated/app_icon_casual_1024.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
  });
}
