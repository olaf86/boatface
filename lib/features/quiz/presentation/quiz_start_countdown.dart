import 'dart:async';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

Future<void> showQuizStartCountdown(BuildContext context, String modeLabel) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'quiz-start-countdown',
    barrierColor: Colors.black.withValues(alpha: 0.18),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (BuildContext context, _, _) {
      return _QuizStartCountdown(modeLabel: modeLabel);
    },
    transitionBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          return FadeScaleTransition(animation: animation, child: child);
        },
  );
}

class _QuizStartCountdown extends StatefulWidget {
  const _QuizStartCountdown({required this.modeLabel});

  final String modeLabel;

  @override
  State<_QuizStartCountdown> createState() => _QuizStartCountdownState();
}

class _QuizStartCountdownState extends State<_QuizStartCountdown> {
  static const List<String> _steps = <String>['3', '2', '1', 'START!'];
  int _stepIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1000), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_stepIndex >= _steps.length - 1) {
        timer.cancel();
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _stepIndex += 1;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 280,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(widget.modeLabel, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text('まもなくスタート', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 20),
              SizedBox(
                height: 92,
                child: PageTransitionSwitcher(
                  duration: const Duration(milliseconds: 320),
                  reverse: false,
                  transitionBuilder:
                      (
                        Widget child,
                        Animation<double> primaryAnimation,
                        Animation<double> secondaryAnimation,
                      ) {
                        return SharedAxisTransition(
                          animation: primaryAnimation,
                          secondaryAnimation: secondaryAnimation,
                          transitionType: SharedAxisTransitionType.scaled,
                          fillColor: Colors.transparent,
                          child: child,
                        );
                      },
                  child: Text(
                    _steps[_stepIndex],
                    key: ValueKey<int>(_stepIndex),
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: _stepIndex == _steps.length - 1
                          ? theme.colorScheme.tertiary
                          : theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
