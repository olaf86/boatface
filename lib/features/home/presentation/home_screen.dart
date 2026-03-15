import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../quiz/data/quiz_data_providers.dart';
import '../../quiz/domain/quiz_modes.dart';
import '../../quiz/domain/quiz_models.dart';
import '../../quiz/presentation/quiz_rule_screen.dart';
import '../../quiz/presentation/quiz_screen.dart';
import '../../ranking/presentation/ranking_screen.dart';
import '../../result/presentation/result_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String providerLabel =
        ref.watch(authControllerProvider).providerLabel ?? '-';
    final int racerCount = ref
        .watch(mockRacerRepositoryProvider)
        .fetchAll()
        .length;
    final ThemeData theme = Theme.of(context);
    final List<QuizModeConfig> playableModes = kQuizModes
        .where((QuizModeConfig mode) => mode.availableInMvp)
        .toList(growable: false);
    final List<QuizModeConfig> futureModes = kQuizModes
        .where((QuizModeConfig mode) => !mode.availableInMvp)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Boatface'),
        actions: <Widget>[
          IconButton(
            tooltip: 'ランキング',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const RankingScreen()),
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
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool twoColumn = constraints.maxWidth >= 900;
          final Widget summaryPanel = ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _HeroCard(
                providerLabel: providerLabel,
                playableModeCount: playableModes.length,
                racerCount: racerCount,
              ),
              const SizedBox(height: 16),
              Text('プレイ可能モード', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ...playableModes.map(
                (QuizModeConfig mode) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ModeSummaryCard(mode: mode),
                ),
              ),
              if (futureModes.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text('今後の追加予定', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                ...futureModes.map(
                  (QuizModeConfig mode) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ModeSummaryCard(mode: mode, compact: true),
                  ),
                ),
              ],
            ],
          );

          final Widget modeList = ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: kQuizModes.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(height: 12),
            itemBuilder: (BuildContext context, int index) {
              final QuizModeConfig mode = kQuizModes[index];
              return _ModeActionCard(
                mode: mode,
                onTap: mode.availableInMvp
                    ? () => _startFlow(context, mode)
                    : null,
              );
            },
          );

          if (!twoColumn) {
            return modeList;
          }

          return Row(
            children: <Widget>[
              SizedBox(width: 340, child: summaryPanel),
              VerticalDivider(
                width: 1,
                color: theme.colorScheme.outlineVariant,
              ),
              Expanded(child: modeList),
            ],
          );
        },
      ),
    );
  }

  Future<void> _startFlow(BuildContext context, QuizModeConfig mode) async {
    final QuizModeConfig? resolvedMode = await Navigator.of(context)
        .push<QuizModeConfig>(
          MaterialPageRoute(builder: (_) => QuizRuleScreen(baseMode: mode)),
        );
    if (!context.mounted || resolvedMode == null) {
      return;
    }

    final quizResult = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => QuizScreen(mode: resolvedMode)));
    if (context.mounted && quizResult != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ResultScreen(summary: quizResult),
        ),
      );
    }
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.providerLabel,
    required this.playableModeCount,
    required this.racerCount,
  });

  final String providerLabel;
  final int playableModeCount;
  final int racerCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              theme.colorScheme.primaryContainer,
              theme.colorScheme.surfaceContainerHighest,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('MVP Frontend', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Text('ログイン: $providerLabel', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _StatChip(label: '公開モード', value: '$playableModeCount'),
                _StatChip(label: 'モック選手', value: '$racerCount'),
                const _StatChip(label: 'ランキング', value: 'モック'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label  $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ModeSummaryCard extends StatelessWidget {
  const _ModeSummaryCard({required this.mode, this.compact = false});

  final QuizModeConfig mode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    mode.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (!mode.availableInMvp)
                  const Chip(
                    label: Text('準備中'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(mode.description),
            if (!compact) ...<Widget>[
              const SizedBox(height: 8),
              Text(_modeMeta(mode)),
            ],
          ],
        ),
      ),
    );
  }

  String _modeMeta(QuizModeConfig mode) {
    final String timeText = mode.timeLimitSeconds == null
        ? '時間無制限'
        : '制限 ${mode.timeLimitSeconds} 秒';
    return '${mode.questionCount} 問 / $timeText';
  }
}

class _ModeActionCard extends StatelessWidget {
  const _ModeActionCard({required this.mode, this.onTap});

  final QuizModeConfig mode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      mode.label,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  if (mode.availableInMvp)
                    const Icon(Icons.play_circle_outline)
                  else
                    const Chip(
                      label: Text('準備中'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(mode.description, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  Chip(
                    label: Text('${mode.questionCount} 問'),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: Text(
                      mode.timeLimitSeconds == null
                          ? '時間無制限'
                          : '1問 ${mode.timeLimitSeconds} 秒',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  ...mode.segments.map(
                    (QuizSegment segment) => Chip(
                      label: Text(
                        '${promptTypeLabel(segment.promptType)} ${segment.count}',
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
