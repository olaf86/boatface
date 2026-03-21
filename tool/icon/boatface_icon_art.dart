import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const Color _outerSky = Color(0xFFEAF7FF);
const Color _poolMint = Color(0xFF8BF3E0);
const Color _poolAqua = Color(0xFF4AD8F7);
const Color _lagoon = Color(0xFF22B7E8);
const Color _raceBlue = Color(0xFF1456C9);
const Color _deepBlue = Color(0xFF0A2F7A);

void paintBoatfaceIcon(Canvas canvas, Size size) {
  final Rect bounds = Offset.zero & size;
  final double unit = size.width / 1024;
  final RRect card = RRect.fromRectAndRadius(
    Rect.fromLTWH(88 * unit, 88 * unit, 848 * unit, 848 * unit),
    Radius.circular(212 * unit),
  );
  final Path cardPath = Path()..addRRect(card);

  canvas.drawRect(bounds, Paint()..color = _outerSky);
  canvas.drawShadow(
    cardPath,
    _deepBlue.withValues(alpha: 0.18),
    42 * unit,
    false,
  );

  canvas.drawRRect(
    card,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(180 * unit, 120 * unit),
        Offset(834 * unit, 890 * unit),
        const <Color>[
          Color(0xFFDFFFFB),
          _poolMint,
          _poolAqua,
          _lagoon,
          _raceBlue,
        ],
        const <double>[0.0, 0.18, 0.46, 0.74, 1.0],
      ),
  );

  canvas.save();
  canvas.clipRRect(card);

  canvas.drawCircle(
    Offset(730 * unit, 770 * unit),
    240 * unit,
    Paint()..color = _deepBlue.withValues(alpha: 0.22),
  );
  canvas.drawCircle(
    Offset(274 * unit, 246 * unit),
    186 * unit,
    Paint()..color = Colors.white.withValues(alpha: 0.12),
  );
  canvas.drawRect(
    Rect.fromLTWH(120 * unit, 190 * unit, 784 * unit, 72 * unit),
    Paint()..color = Colors.white.withValues(alpha: 0.12),
  );
  canvas.drawRect(
    Rect.fromLTWH(120 * unit, 612 * unit, 784 * unit, 118 * unit),
    Paint()..color = _deepBlue.withValues(alpha: 0.12),
  );

  final Path fPath = _buildFPath(unit);
  canvas.drawShadow(fPath, _deepBlue.withValues(alpha: 0.22), 30 * unit, false);
  canvas.drawPath(
    fPath,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(350 * unit, 250 * unit),
        Offset(650 * unit, 800 * unit),
        <Color>[
          Colors.white,
          const Color(0xFFFDF8FF),
          Colors.white.withValues(alpha: 0.94),
        ],
        const <double>[0.0, 0.5, 1.0],
      ),
  );
  canvas.drawPath(
    fPath,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8 * unit,
  );

  canvas.save();
  canvas.clipPath(fPath);
  final Rect glossRect = Rect.fromLTWH(
    326 * unit,
    236 * unit,
    414 * unit,
    220 * unit,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(glossRect, Radius.circular(80 * unit)),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(glossRect.left, glossRect.top),
        Offset(glossRect.left, glossRect.bottom),
        <Color>[
          Colors.white.withValues(alpha: 0.42),
          Colors.white.withValues(alpha: 0.0),
        ],
      ),
  );
  canvas.restore();

  _drawWaveCut(canvas, unit);
  _drawRippleArc(canvas, unit);

  canvas.drawRRect(
    card,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.46)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10 * unit,
  );

  canvas.restore();
}

Path _buildFPath(double unit) {
  final Path stem = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(334 * unit, 214 * unit, 166 * unit, 598 * unit),
        Radius.circular(84 * unit),
      ),
    );
  final Path topArm = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(334 * unit, 214 * unit, 384 * unit, 152 * unit),
        Radius.circular(76 * unit),
      ),
    );
  final Path midArm = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(334 * unit, 456 * unit, 300 * unit, 136 * unit),
        Radius.circular(68 * unit),
      ),
    );

  Path fPath = Path.combine(PathOperation.union, stem, topArm);
  fPath = Path.combine(PathOperation.union, fPath, midArm);
  return fPath;
}

void _drawWaveCut(Canvas canvas, double unit) {
  final Path wave = Path()
    ..moveTo(280 * unit, 668 * unit)
    ..quadraticBezierTo(430 * unit, 590 * unit, 560 * unit, 624 * unit)
    ..quadraticBezierTo(664 * unit, 652 * unit, 750 * unit, 600 * unit)
    ..quadraticBezierTo(732 * unit, 710 * unit, 614 * unit, 752 * unit)
    ..quadraticBezierTo(448 * unit, 802 * unit, 280 * unit, 736 * unit)
    ..close();

  canvas.drawPath(
    wave,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(292 * unit, 610 * unit),
        Offset(748 * unit, 748 * unit),
        const <Color>[_poolAqua, _lagoon, _raceBlue],
        const <double>[0.0, 0.55, 1.0],
      ),
  );

  final Paint foam = Paint()
    ..color = Colors.white.withValues(alpha: 0.94)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 18 * unit;
  final Path foamPath = Path()
    ..moveTo(306 * unit, 666 * unit)
    ..quadraticBezierTo(446 * unit, 606 * unit, 560 * unit, 638 * unit)
    ..quadraticBezierTo(654 * unit, 662 * unit, 726 * unit, 624 * unit);
  canvas.drawPath(foamPath, foam);
}

void _drawRippleArc(Canvas canvas, double unit) {
  final Paint ripple = Paint()
    ..color = Colors.white.withValues(alpha: 0.42)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 10 * unit;

  final Path backRipple = Path()
    ..moveTo(284 * unit, 724 * unit)
    ..quadraticBezierTo(466 * unit, 792 * unit, 674 * unit, 738 * unit)
    ..quadraticBezierTo(744 * unit, 718 * unit, 800 * unit, 678 * unit);
  canvas.drawPath(backRipple, ripple);

  final Path frontRipple = Path()
    ..moveTo(258 * unit, 766 * unit)
    ..quadraticBezierTo(470 * unit, 826 * unit, 688 * unit, 784 * unit);
  canvas.drawPath(frontRipple, ripple..strokeWidth = 8 * unit);
}
