import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation/app_route.dart';
import '../../auth/application/auth_controller.dart';
import '../../quiz/data/quiz_data_providers.dart';
import '../../quiz/domain/quiz_modes.dart';
import '../../quiz/domain/quiz_models.dart';
import '../../quiz/presentation/quiz_rule_screen.dart';
import '../../ranking/presentation/ranking_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const double _modeButtonMaxWidth = 320;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider).valueOrNull;
    final racerMasterInit = ref.watch(racerRepositoryInitializationProvider);
    final String providerLabel = authState?.providerLabel ?? '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text('BoatFace'),
        actions: <Widget>[
          IconButton(
            tooltip: 'ランキング',
            onPressed: () {
              Navigator.of(context).push(
                buildAppRoute<void>(
                  page: const RankingScreen(),
                  transition: AppRouteTransition.fadeScale,
                ),
              );
            },
            icon: const Icon(Icons.leaderboard_outlined),
          ),
          IconButton(
            tooltip: 'ログアウト',
            onPressed: () async {
              final bool? confirmed = await showDialog<bool>(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  title: const Text('ログアウト確認'),
                  content: const Text('ログアウトしますか？'),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('キャンセル'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('ログアウト'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                ref.read(authControllerProvider.notifier).signOut();
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: racerMasterInit.when(
            data: (_) => _HomeContent(
              providerLabel: providerLabel,
              onStartMode: (QuizModeConfig mode) => _startFlow(context, mode),
            ),
            loading: () =>
                _RacerMasterPreparingView(providerLabel: providerLabel),
            error: (Object error, StackTrace stackTrace) =>
                _RacerMasterErrorView(
                  providerLabel: providerLabel,
                  onRetry: () =>
                      ref.invalidate(racerRepositoryInitializationProvider),
                ),
          ),
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

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.providerLabel, required this.onStartMode});

  final String providerLabel;
  final ValueChanged<QuizModeConfig> onStartMode;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'モードを選択',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text('ログイン: $providerLabel'),
                const SizedBox(height: 4),
                Text(
                  '詳細なルールは次の画面で確認できます。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...kQuizModes.map(
          (QuizModeConfig mode) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: HomeScreen._modeButtonMaxWidth,
                ),
                child: _ModeListItem(
                  mode: mode,
                  onTap: mode.availableInMvp ? () => onStartMode(mode) : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RacerMasterPreparingView extends StatelessWidget {
  const _RacerMasterPreparingView({required this.providerLabel});

  final String providerLabel;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'クイズデータを準備中',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text('ログイン: $providerLabel'),
                const SizedBox(height: 12),
                const Text(
                  '初回起動時のみ、選手データを端末に保存します。完了するとオフラインでもクイズを開始しやすくなります。',
                ),
                const SizedBox(height: 20),
                const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RacerMasterErrorView extends StatelessWidget {
  const _RacerMasterErrorView({
    required this.providerLabel,
    required this.onRetry,
  });

  final String providerLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'クイズデータを取得できませんでした',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text('ログイン: $providerLabel'),
                const SizedBox(height: 12),
                const Text(
                  '通信状態を確認してから再試行してください。既存のローカルデータがある場合は次回以降この待機は短くなります。',
                ),
                const SizedBox(height: 20),
                FilledButton(onPressed: onRetry, child: const Text('再試行')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeListItem extends StatelessWidget {
  const _ModeListItem({required this.mode, this.onTap});

  final QuizModeConfig mode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final _DifficultyBadgeStyle? badge = _difficultyBadgeFor(mode.id);
    final bool enabled = mode.availableInMvp;

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
          child: SizedBox(
            height: 32,
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
                      horizontal: badge != null ? 72 : 0,
                    ),
                    child: Text(
                      mode.label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: enabled
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                      ),
                    ),
                  ),
                ),
                if (!enabled)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '準備中',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _DifficultyBadgeStyle? _difficultyBadgeFor(String modeId) {
    switch (modeId) {
      case 'quick':
        return const _DifficultyBadgeStyle(
          label: 'かんたん',
          backgroundColor: Color(0xFFDFF7E7),
          foregroundColor: Color(0xFF217A3C),
        );
      case 'careful':
        return const _DifficultyBadgeStyle(
          label: 'ふつう',
          backgroundColor: Color(0xFFFFF0C9),
          foregroundColor: Color(0xFF8A5A00),
        );
      case 'challenge':
        return const _DifficultyBadgeStyle(
          label: '難しい',
          backgroundColor: Color(0xFFFFDFD8),
          foregroundColor: Color(0xFFB33A2B),
        );
      case 'master':
        return const _DifficultyBadgeStyle(
          label: '激ムズ',
          backgroundColor: Color(0xFFE5DDFF),
          foregroundColor: Color(0xFF5A33B3),
        );
      case 'custom':
        return null;
      default:
        return const _DifficultyBadgeStyle(
          label: 'モード',
          backgroundColor: Color(0xFFDDF4FF),
          foregroundColor: Color(0xFF0B4F9C),
        );
    }
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
