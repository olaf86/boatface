import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../quiz/domain/quiz_models.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({required this.summary, super.key});

  final QuizResultSummary summary;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confettiController;

  bool get _showCelebration =>
      widget.summary.endReason == QuizEndReason.completed;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    if (_showCelebration) {
      _confettiController.forward();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final QuizResultSummary summary = widget.summary;
    final String endReasonText = switch (summary.endReason) {
      QuizEndReason.completed => '全問クリア',
      QuizEndReason.wrongAnswer => '不正解で終了',
      QuizEndReason.timeout => '時間切れで終了',
      QuizEndReason.abandoned => '途中離脱',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('リザルト'),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: <Widget>[
                  Text(
                    summary.modeLabel,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    endReasonText,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_showCelebration) ...<Widget>[
                    const SizedBox(height: 16),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: <Color>[Color(0xFFFFD54F), Color(0xFFFF8A65)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'MODE CLEAR',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '紙吹雪と一緒にリザルトを表示しています。',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _MetricRow(label: 'スコア', value: '${summary.score}'),
                  _MetricRow(
                    label: '正解数',
                    value:
                        '${summary.correctAnswers} / ${summary.totalQuestions}',
                  ),
                  _MetricRow(
                    label: '総回答時間',
                    value:
                        '${(summary.totalAnswerTime.inMilliseconds / 1000).toStringAsFixed(1)} 秒',
                  ),
                  _MetricRow(
                    label: '広告続行',
                    value: summary.continuedByAd ? 'あり（1回）' : 'なし',
                  ),
                  _MetricRow(
                    label: 'ランキング反映',
                    value: summary.rankingEligible ? '反映対象' : '反映対象外',
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).popUntil((Route<dynamic> route) => route.isFirst),
                    child: const Text('ホームに戻る'),
                  ),
                ],
              ),
            ),
          ),
          if (_showCelebration)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _confettiController,
                  builder: (BuildContext context, Widget? child) {
                    return CustomPaint(
                      key: const ValueKey<String>('mode-clear-confetti'),
                      painter: _ConfettiPainter(
                        progress: _confettiController.value,
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.progress});

  final double progress;

  static const List<Color> _colors = <Color>[
    Color(0xFFFF6B6B),
    Color(0xFFFFD166),
    Color(0xFF06D6A0),
    Color(0xFF118AB2),
    Color(0xFFEF476F),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) {
      return;
    }

    final Paint paint = Paint()..style = PaintingStyle.fill;
    final double opacity = (1 - Curves.easeIn.transform(progress)).clamp(
      0.0,
      1.0,
    );

    for (int i = 0; i < 42; i++) {
      final double seed = i + 1;
      final double lane = _noise(seed * 1.37);
      final double burst = _noise(seed * 2.41);
      final double swing = math.sin(
        progress * math.pi * (2.2 + burst * 1.8) + seed,
      );
      final double x =
          lerpDouble(
            size.width * (burst < 0.5 ? 0.1 : 0.9),
            size.width * (0.08 + lane * 0.84),
            Curves.easeOutCubic.transform(progress),
          )! +
          swing * (12 + burst * 18);
      final double y =
          (-28 - burst * 120) +
          (size.height + 180) * Curves.easeIn.transform(progress);
      final double width = 7 + _noise(seed * 3.73) * 8;
      final double height = 10 + _noise(seed * 4.91) * 10;
      final double rotation =
          progress * math.pi * (3 + burst * 4) + _noise(seed * 5.17) * math.pi;

      paint.color = _colors[i % _colors.length].withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  double _noise(double value) {
    final double sine = math.sin(value * 12.9898) * 43758.5453;
    return sine - sine.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
