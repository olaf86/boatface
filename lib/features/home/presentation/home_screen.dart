import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation/app_route.dart';
import '../../quiz/application/racer_master_sync_controller.dart';
import '../../quiz/application/racer_master_sync_state.dart';
import '../../quiz/domain/quiz_modes.dart';
import '../../quiz/domain/quiz_models.dart';
import '../../quiz/presentation/quiz_rule_screen.dart';
import '../../ranking/presentation/ranking_screen.dart';
import '../../../shared/format/date_time_formatters.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static const double _modeButtonMaxWidth = 320;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(racerMasterSyncControllerProvider.notifier)
          .startBackgroundSyncIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final RacerMasterSyncState syncState = ref.watch(
      racerMasterSyncControllerProvider,
    );

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
            tooltip: '設定',
            onPressed: () {
              Navigator.of(context).push(
                buildAppRoute<void>(
                  page: const SettingsScreen(),
                  transition: AppRouteTransition.sharedAxisHorizontal,
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _HomeSummaryCard(syncState: syncState),
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
                        onTap: mode.availableInMvp
                            ? () => _startFlow(context, mode)
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ],
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

class _HomeSummaryCard extends StatelessWidget {
  const _HomeSummaryCard({required this.syncState});

  final RacerMasterSyncState syncState;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String datasetLabel = syncState.activeManifest == null
        ? '未取得'
        : '${syncState.activeManifest!.datasetId} '
              '${formatDateTimeYmdHm(syncState.activeManifest!.datasetUpdatedAt)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('モードを選択', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('詳細なルールは次の画面で確認できます。', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                Chip(label: Text(_statusLabel(syncState))),
                Chip(label: Text('使用中データ: $datasetLabel')),
              ],
            ),
            if (syncState.errorMessage != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                syncState.errorMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(RacerMasterSyncState state) {
    switch (state.phase) {
      case RacerMasterSyncPhase.idle:
        return state.hasUsableData ? '準備完了' : '未同期';
      case RacerMasterSyncPhase.checking:
        return state.hasUsableData ? '更新確認中' : '同期確認中';
      case RacerMasterSyncPhase.downloading:
        return state.hasUsableData ? '更新中' : '初回同期中';
      case RacerMasterSyncPhase.ready:
        return '準備完了';
      case RacerMasterSyncPhase.error:
        return state.hasUsableData ? 'ローカルデータで利用中' : '同期失敗';
    }
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
