import 'package:flutter/material.dart';

/// Displays the current question's time limit and remaining-time meter.
///
/// Keeping this independently of [QuizScreen] makes the session UI easier to
/// evolve without growing the screen's state and navigation concerns further.
class QuizSessionHudBar extends StatelessWidget {
  const QuizSessionHudBar({
    required this.timerText,
    required this.remainingRatio,
    required this.isTimeFrozen,
    required this.totalSeconds,
    super.key,
  });

  final String timerText;
  final double? remainingRatio;
  final bool isTimeFrozen;
  final int? totalSeconds;

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    final bool isTimed = totalSeconds != null;
    final Color accentColor = isTimed
        ? _timerAccentColor(
            remainingRatio: remainingRatio ?? 0,
            isTimeFrozen: isTimeFrozen,
          )
        : const Color(0xFF145E9C);

    if (!isTimed) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '∞',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'FREE',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final int segmentCount = totalSeconds! <= 8 ? totalSeconds! : 10;
    final double hudRatio = remainingRatio ?? 0;
    final int activeSegments = isTimeFrozen
        ? segmentCount
        : (hudRatio * segmentCount).ceil().clamp(0, segmentCount);

    return Row(
      children: <Widget>[
        _QuizHudCapsule(
          icon: isTimeFrozen
              ? Icons.pause_circle_filled_rounded
              : Icons.timer_rounded,
          label: isTimeFrozen ? 'STOP' : 'LIMIT',
          highlightColor: accentColor,
          foregroundColor: primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuizMeterStrip(
            segmentCount: segmentCount,
            activeSegments: activeSegments,
            activeColor: accentColor,
            isDanger: !isTimeFrozen && hudRatio <= 0.3,
          ),
        ),
        const SizedBox(width: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 68),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$timerText s',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: primary,
                fontWeight: FontWeight.w900,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                shadows: <Shadow>[
                  Shadow(
                    color: Colors.white.withValues(alpha: 0.25),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuizHudCapsule extends StatelessWidget {
  const _QuizHudCapsule({
    required this.icon,
    required this.label,
    required this.highlightColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final Color highlightColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: highlightColor.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 18, color: foregroundColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizMeterStrip extends StatelessWidget {
  const _QuizMeterStrip({
    required this.segmentCount,
    required this.activeSegments,
    required this.activeColor,
    required this.isDanger,
  });

  final int segmentCount;
  final int activeSegments;
  final Color activeColor;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(segmentCount, (int index) {
        final bool isActive = index < activeSegments;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == segmentCount - 1 ? 0 : 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: isActive ? 14 : 8,
              decoration: BoxDecoration(
                color: isActive
                    ? (isDanger
                          ? const Color(0xFFE9A4B4)
                          : activeColor.withValues(alpha: 0.9))
                    : activeColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
                boxShadow: isActive
                    ? <BoxShadow>[
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.18),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        );
      }),
    );
  }
}

Color _timerAccentColor({
  required double remainingRatio,
  required bool isTimeFrozen,
}) {
  if (isTimeFrozen) {
    return const Color(0xFF7CC8EA);
  }
  return Color.lerp(
    const Color(0xFFE9A4B4),
    const Color(0xFFB7D9F8),
    remainingRatio.clamp(0.0, 1.0),
  )!;
}
