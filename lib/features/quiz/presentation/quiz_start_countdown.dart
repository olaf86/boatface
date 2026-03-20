import 'dart:async';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

class QuizStartCountdown extends StatefulWidget {
  const QuizStartCountdown({
    required this.modeLabel,
    required this.onCompleted,
    super.key,
  });

  final String modeLabel;
  final VoidCallback onCompleted;

  @override
  State<QuizStartCountdown> createState() => _QuizStartCountdownState();
}

class _QuizStartCountdownState extends State<QuizStartCountdown> {
  static const List<String> _steps = <String>['3', '2', '1', 'START!'];

  int _stepIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_stepIndex >= _steps.length - 1) {
        timer.cancel();
        widget.onCompleted();
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

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            theme.colorScheme.primaryContainer,
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerHighest,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: 320,
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
                  Text(widget.modeLabel, style: theme.textTheme.titleLarge),
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
        ),
      ),
    );
  }
}
