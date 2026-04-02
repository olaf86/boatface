import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation/app_route.dart';
import '../../profile/application/user_profile_controller.dart';
import '../../profile/domain/user_profile.dart';
import '../../quiz/domain/quiz_mode_unlocks.dart';
import '../../quiz/domain/quiz_modes.dart';
import '../../quiz/domain/quiz_models.dart';
import '../../quiz/presentation/quiz_rule_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static const double _modeButtonMaxWidth = 320;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final AsyncValue<UserProfile> profileAsync = ref.watch(userProfileProvider);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const _HomeSummaryCard(),
            const SizedBox(height: 12),
            ...profileAsync.when(
              data: (UserProfile profile) {
                return kQuizModes
                    .map((QuizModeConfig mode) {
                      final QuizModeAccess access = resolveQuizModeAccess(
                        mode,
                        quizProgress: profile.quizProgress,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: HomeScreen._modeButtonMaxWidth,
                            ),
                            child: _ModeListItem(
                              access: access,
                              onTap: access.canStart
                                  ? () => _startFlow(context, mode)
                                  : null,
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(growable: false);
              },
              loading: () => const <Widget>[_HomeLoadingCard()],
              error: (Object error, StackTrace stackTrace) {
                return kQuizModes
                    .map((QuizModeConfig mode) {
                      final QuizModeAccess access = resolveQuizModeAccess(
                        mode,
                        quizProgress: const UserQuizProgress.empty(),
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: HomeScreen._modeButtonMaxWidth,
                            ),
                            child: _ModeListItem(
                              access: access,
                              onTap: access.canStart
                                  ? () => _startFlow(context, mode)
                                  : null,
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(growable: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startFlow(BuildContext context, QuizModeConfig mode) async {
    await Navigator.of(context).push<void>(
      buildAppRoute<void>(
        page: QuizRuleScreen(baseMode: mode),
        transition: AppRouteTransition.sharedAxisHorizontal,
      ),
    );
  }
}

class _HomeSummaryCard extends StatelessWidget {
  const _HomeSummaryCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('クイズモードを選択', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('モードを選んでクイズにチャレンジしよう！', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _HomeLoadingCard extends StatelessWidget {
  const _HomeLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      ),
    );
  }
}

class _ModeListItem extends StatefulWidget {
  const _ModeListItem({required this.access, this.onTap});

  final QuizModeAccess access;
  final VoidCallback? onTap;

  @override
  State<_ModeListItem> createState() => _ModeListItemState();
}

class _ModeListItemState extends State<_ModeListItem>
    with SingleTickerProviderStateMixin {
  static const Duration _lockedHintDuration = Duration(milliseconds: 2200);

  late final AnimationController _shakeController;
  Timer? _lockedHintTimer;
  bool _showLockedHint = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _lockedHintTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  void _handleTap() {
    final QuizModeAccess access = widget.access;
    if (access.canStart) {
      widget.onTap?.call();
      return;
    }
    if (!access.isImplemented || access.lockedReason == null) {
      return;
    }

    _shakeController.forward(from: 0);
    _lockedHintTimer?.cancel();
    setState(() {
      _showLockedHint = true;
    });
    _lockedHintTimer = Timer(_lockedHintDuration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showLockedHint = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final QuizModeAccess access = widget.access;
    final QuizModeConfig mode = access.mode;
    final _DifficultyBadgeStyle? badge = _difficultyBadgeFor(mode.id);
    final bool enabled = access.canStart;
    final Widget? statusWidget = access.isImplemented
        ? (access.isUnlocked ? null : _ModeLockStatus(theme: theme))
        : _ModePreparingStatus(theme: theme);
    final bool showLockedHint = _showLockedHint && access.lockedReason != null;
    final String centerText = showLockedHint
        ? access.lockedReason!
        : mode.label;
    final TextStyle? centerTextStyle =
        (showLockedHint
                ? theme.textTheme.labelLarge
                : theme.textTheme.titleLarge)
            ?.copyWith(
              color: enabled
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: showLockedHint ? 12 : null,
              height: showLockedHint ? 1.15 : null,
            );

    return AnimatedBuilder(
      animation: _shakeController,
      builder: (BuildContext context, Widget? child) {
        final double shakeOffset =
            math.sin(_shakeController.value * math.pi * 5) *
            8 *
            (1 - _shakeController.value);
        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: child,
        );
      },
      child: Card(
        key: ValueKey<String>('mode-card-${mode.id}'),
        elevation: enabled ? 4 : 0,
        shadowColor: theme.colorScheme.primary.withValues(alpha: 0.12),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: access.isImplemented ? _handleTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: enabled
                  ? LinearGradient(
                      colors: <Color>[
                        Colors.white,
                        theme.colorScheme.surfaceContainerHighest,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
            ),
            child: SizedBox(
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  if (badge != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: badge.backgroundColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge.label,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontSize: 12,
                            color: badge.foregroundColor,
                          ),
                        ),
                      ),
                    ),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: badge != null || statusWidget != null
                            ? 66
                            : 0,
                      ),
                      child: ClipRect(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                                final Animation<Offset> slideAnimation =
                                    Tween<Offset>(
                                      begin: const Offset(0, 0.35),
                                      end: Offset.zero,
                                    ).animate(animation);
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: slideAnimation,
                                    child: child,
                                  ),
                                );
                              },
                          child: Text(
                            centerText,
                            key: ValueKey<String>(
                              '${mode.id}-${showLockedHint ? 'hint' : 'label'}',
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: centerTextStyle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (statusWidget != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: statusWidget,
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

class _ModeLockStatus extends StatelessWidget {
  const _ModeLockStatus({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      child: Center(
        child: Icon(
          Icons.lock_rounded,
          size: 18,
          color: theme.colorScheme.tertiary,
        ),
      ),
    );
  }
}

class _ModePreparingStatus extends StatelessWidget {
  const _ModePreparingStatus({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      child: Text(
        '準備中',
        textAlign: TextAlign.center,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

class _DifficultyBadgeStyle {
  const _DifficultyBadgeStyle({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
}

_DifficultyBadgeStyle? _difficultyBadgeFor(String modeId) {
  switch (modeId) {
    case 'quick':
      return const _DifficultyBadgeStyle(
        label: 'EASY',
        backgroundColor: Color(0xFFD7F7E9),
        foregroundColor: Color(0xFF0A7A4A),
      );
    case 'careful':
      return const _DifficultyBadgeStyle(
        label: 'NORMAL',
        backgroundColor: Color(0xFFE1F0FF),
        foregroundColor: Color(0xFF145E9C),
      );
    case 'challenge':
      return const _DifficultyBadgeStyle(
        label: 'HARD',
        backgroundColor: Color(0xFFFFE7D6),
        foregroundColor: Color(0xFFB45400),
      );
    case 'master':
      return const _DifficultyBadgeStyle(
        label: 'MASTER',
        backgroundColor: Color(0xFFFFE1E6),
        foregroundColor: Color(0xFFAF2343),
      );
    case 'custom':
      return const _DifficultyBadgeStyle(
        label: 'CUSTOM',
        backgroundColor: Color(0xFFF2EAFF),
        foregroundColor: Color(0xFF6942B4),
      );
    default:
      return null;
  }
}
