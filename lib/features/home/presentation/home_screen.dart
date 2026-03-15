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
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Text('ログイン: $providerLabel'),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: kQuizModes.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(height: 8),
              itemBuilder: (BuildContext context, int index) {
                final QuizModeConfig mode = kQuizModes[index];
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  title: Text(mode.label),
                  subtitle: Text(mode.description),
                  trailing: !mode.availableInMvp
                      ? const Chip(
                          label: Text('準備中'),
                          visualDensity: VisualDensity.compact,
                        )
                      : const Icon(Icons.chevron_right),
                  enabled: mode.availableInMvp,
                  onTap: mode.availableInMvp
                      ? () => _startFlow(context, mode)
                      : null,
                );
              },
            ),
          ),
        ],
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
