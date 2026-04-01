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
    final UserQuizProgress? quizProgress =
        profileAsync.valueOrNull?.quizProgress;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _HomeSummaryCard(profileAsync: profileAsync),
            const SizedBox(height: 12),
            ...kQuizModes.map((QuizModeConfig mode) {
              final QuizModeAccess access = resolveQuizModeAccess(
                mode,
                quizProgress: quizProgress,
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
            }),
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
  const _HomeSummaryCard({required this.profileAsync});

  final AsyncValue<UserProfile> profileAsync;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final UserQuizProgress? quizProgress =
        profileAsync.valueOrNull?.quizProgress;
    final int clearedModeCount = kQuizModes
        .where(
          (QuizModeConfig mode) =>
              !kAlwaysUnlockedQuizModeIds.contains(mode.id),
        )
        .where(
          (QuizModeConfig mode) =>
              quizProgress?.hasClearedMode(mode.id) ?? false,
        )
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('クイズモードを選択', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('モードを選んでクイズにチャレンジしよう！', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            profileAsync.when(
              data: (UserProfile profile) => Text(
                '開放状況: $clearedModeCount / 3 モードをクリア済み',
                style: theme.textTheme.labelLarge,
              ),
              loading: () =>
                  Text('開放状況を確認しています…', style: theme.textTheme.bodyMedium),
              error: (Object error, StackTrace stackTrace) => Text(
                '開放状況を取得できなかったため、基本モードのみ表示しています。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeListItem extends StatelessWidget {
  const _ModeListItem({required this.access, this.onTap});

  final QuizModeAccess access;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final QuizModeConfig mode = access.mode;
    final _DifficultyBadgeStyle? badge = _difficultyBadgeFor(mode.id);
    final bool enabled = access.canStart;
    final String? statusText = access.isImplemented
        ? (access.isUnlocked ? null : '未開放')
        : '準備中';
    final String supportingText = !access.isImplemented
        ? 'このモードはまだ実装準備中です。'
        : (access.lockedReason ?? mode.description);

    return Card(
      elevation: enabled ? 4 : 0,
      shadowColor: theme.colorScheme.primary.withValues(alpha: 0.12),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  if (badge != null)
                    Container(
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
                  if (badge != null) const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      mode.label,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: enabled
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                      ),
                    ),
                  ),
                  if (statusText != null)
                    Text(
                      statusText,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: access.isImplemented
                            ? theme.colorScheme.tertiary
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.55,
                              ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                supportingText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: enabled
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.68),
                ),
              ),
            ],
          ),
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
