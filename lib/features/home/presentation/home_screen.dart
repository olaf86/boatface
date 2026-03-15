import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
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
                  child: _ModeListItem(
                    mode: mode,
                    onTap: mode.availableInMvp
                        ? () => _startFlow(context, mode)
                        : null,
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

class _ModeListItem extends StatelessWidget {
  const _ModeListItem({required this.mode, this.onTap});

  final QuizModeConfig mode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final String subtitle = mode.availableInMvp
        ? _modeSummary(mode)
        : 'MVP 対象外';

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        enabled: mode.availableInMvp,
        onTap: onTap,
        title: Text(mode.label),
        subtitle: Text(subtitle),
        trailing: mode.availableInMvp
            ? const Icon(Icons.chevron_right)
            : const Chip(
                label: Text('準備中'),
                visualDensity: VisualDensity.compact,
              ),
      ),
    );
  }

  String _modeSummary(QuizModeConfig mode) {
    final String timeText = mode.timeLimitSeconds == null
        ? '時間無制限'
        : '1問 ${mode.timeLimitSeconds} 秒';
    return '${mode.questionCount}問 / $timeText';
  }
}
