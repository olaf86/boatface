import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const Color _outerSky = Color(0xFFEAF7FF);
const Color _poolMint = Color(0xFF8BF3E0);
const Color _poolAqua = Color(0xFF4AD8F7);
const Color _lagoon = Color(0xFF22B7E8);
const Color _raceBlue = Color(0xFF1456C9);
const Color _deepBlue = Color(0xFF0A2F7A);
const double _iconArtworkScale = 1.22;
const double _iconDesignSize = 1024;
const double _iconDesignCenter = _iconDesignSize / 2;

void paintBoatfaceIcon(Canvas canvas, Size size) {
  final Rect bounds = Offset.zero & size;
  final double unit = size.width / _iconDesignSize;
  final RRect card = RRect.fromRectAndRadius(
    _scaledRect(88, 88, 848, 848, unit),
    _scaledRadius(212, unit),
  );
  final Path cardPath = Path()..addRRect(card);

  canvas.drawRect(bounds, Paint()..color = _outerSky);
  canvas.drawShadow(
    cardPath,
    _deepBlue.withValues(alpha: 0.18),
    _scaledLength(42, unit),
    false,
  );

  canvas.drawRRect(
    card,
    Paint()
      ..shader = ui.Gradient.linear(
        _scaledOffset(180, 120, unit),
        _scaledOffset(834, 890, unit),
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
    _scaledOffset(730, 770, unit),
    _scaledLength(240, unit),
    Paint()..color = _deepBlue.withValues(alpha: 0.22),
  );
  canvas.drawCircle(
    _scaledOffset(274, 246, unit),
    _scaledLength(186, unit),
    Paint()..color = Colors.white.withValues(alpha: 0.12),
  );
  canvas.drawRect(
    _scaledRect(120, 190, 784, 72, unit),
    Paint()..color = Colors.white.withValues(alpha: 0.12),
  );
  canvas.drawRect(
    _scaledRect(120, 612, 784, 118, unit),
    Paint()..color = _deepBlue.withValues(alpha: 0.12),
  );

  final Path fPath = _buildFPath(unit);
  canvas.drawShadow(
    fPath,
    _deepBlue.withValues(alpha: 0.22),
    _scaledLength(30, unit),
    false,
  );
  canvas.drawPath(
    fPath,
    Paint()
      ..shader = ui.Gradient.linear(
        _scaledOffset(350, 250, unit),
        _scaledOffset(650, 800, unit),
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
      ..strokeWidth = _scaledLength(8, unit),
  );

  canvas.save();
  canvas.clipPath(fPath);
  final Rect glossRect = _scaledRect(326, 236, 414, 220, unit);
  canvas.drawRRect(
    RRect.fromRectAndRadius(glossRect, _scaledRadius(80, unit)),
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
      ..strokeWidth = _scaledLength(10, unit),
  );

  canvas.restore();
}

Path _buildFPath(double unit) {
  final Path stem = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        _scaledRect(334, 214, 166, 598, unit),
        _scaledRadius(84, unit),
      ),
    );
  final Path topArm = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        _scaledRect(334, 214, 384, 152, unit),
        _scaledRadius(76, unit),
      ),
    );
  final Path midArm = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        _scaledRect(334, 456, 300, 136, unit),
        _scaledRadius(68, unit),
      ),
    );

  Path fPath = Path.combine(PathOperation.union, stem, topArm);
  fPath = Path.combine(PathOperation.union, fPath, midArm);
  return fPath;
}

void _drawWaveCut(Canvas canvas, double unit) {
  final Path wave = Path()
    ..moveTo(_scaledX(280, unit), _scaledY(668, unit))
    ..quadraticBezierTo(
      _scaledX(430, unit),
      _scaledY(590, unit),
      _scaledX(560, unit),
      _scaledY(624, unit),
    )
    ..quadraticBezierTo(
      _scaledX(664, unit),
      _scaledY(652, unit),
      _scaledX(750, unit),
      _scaledY(600, unit),
    )
    ..quadraticBezierTo(
      _scaledX(732, unit),
      _scaledY(710, unit),
      _scaledX(614, unit),
      _scaledY(752, unit),
    )
    ..quadraticBezierTo(
      _scaledX(448, unit),
      _scaledY(802, unit),
      _scaledX(280, unit),
      _scaledY(736, unit),
    )
    ..close();

  canvas.drawPath(
    wave,
    Paint()
      ..shader = ui.Gradient.linear(
        _scaledOffset(292, 610, unit),
        _scaledOffset(748, 748, unit),
        const <Color>[_poolAqua, _lagoon, _raceBlue],
        const <double>[0.0, 0.55, 1.0],
      ),
  );

  final Paint foam = Paint()
    ..color = Colors.white.withValues(alpha: 0.94)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = _scaledLength(18, unit);
  final Path foamPath = Path()
    ..moveTo(_scaledX(306, unit), _scaledY(666, unit))
    ..quadraticBezierTo(
      _scaledX(446, unit),
      _scaledY(606, unit),
      _scaledX(560, unit),
      _scaledY(638, unit),
    )
    ..quadraticBezierTo(
      _scaledX(654, unit),
      _scaledY(662, unit),
      _scaledX(726, unit),
      _scaledY(624, unit),
    );
  canvas.drawPath(foamPath, foam);
}

void _drawRippleArc(Canvas canvas, double unit) {
  final Paint ripple = Paint()
    ..color = Colors.white.withValues(alpha: 0.42)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = _scaledLength(10, unit);

  final Path backRipple = Path()
    ..moveTo(_scaledX(284, unit), _scaledY(724, unit))
    ..quadraticBezierTo(
      _scaledX(466, unit),
      _scaledY(792, unit),
      _scaledX(674, unit),
      _scaledY(738, unit),
    )
    ..quadraticBezierTo(
      _scaledX(744, unit),
      _scaledY(718, unit),
      _scaledX(800, unit),
      _scaledY(678, unit),
    );
  canvas.drawPath(backRipple, ripple);

  final Path frontRipple = Path()
    ..moveTo(_scaledX(258, unit), _scaledY(766, unit))
    ..quadraticBezierTo(
      _scaledX(470, unit),
      _scaledY(826, unit),
      _scaledX(688, unit),
      _scaledY(784, unit),
    );
  canvas.drawPath(frontRipple, ripple..strokeWidth = _scaledLength(8, unit));
}

double _scaledX(double value, double unit) =>
    (_iconDesignCenter + (value - _iconDesignCenter) * _iconArtworkScale) *
    unit;

double _scaledY(double value, double unit) =>
    (_iconDesignCenter + (value - _iconDesignCenter) * _iconArtworkScale) *
    unit;

double _scaledLength(double value, double unit) =>
    value * _iconArtworkScale * unit;

Offset _scaledOffset(double dx, double dy, double unit) =>
    Offset(_scaledX(dx, unit), _scaledY(dy, unit));

Rect _scaledRect(
  double left,
  double top,
  double width,
  double height,
  double unit,
) => Rect.fromLTWH(
  _scaledX(left, unit),
  _scaledY(top, unit),
  _scaledLength(width, unit),
  _scaledLength(height, unit),
);

Radius _scaledRadius(double radius, double unit) =>
    Radius.circular(_scaledLength(radius, unit));
