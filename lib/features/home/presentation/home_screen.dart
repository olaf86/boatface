import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../quiz/domain/quiz_modes.dart';
import '../../quiz/domain/quiz_models.dart';
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
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool twoColumn = constraints.maxWidth >= 900;
          final int columns = twoColumn ? 2 : 1;
          return Column(
            children: <Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Text('ログイン: $providerLabel'),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: twoColumn ? 2.4 : 2.2,
                    ),
                    itemCount: kQuizModes.length,
                    itemBuilder: (BuildContext context, int index) {
                      final QuizModeConfig mode = kQuizModes[index];
                      return _ModeCard(mode: mode);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode});

  final QuizModeConfig mode;

  @override
  Widget build(BuildContext context) {
    final String timeText = mode.timeLimitSeconds == null
        ? '時間無制限'
        : '1問 ${mode.timeLimitSeconds} 秒';

    return Card(
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
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (!mode.availableInMvp)
                  const Chip(
                    label: Text('準備中'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(mode.description),
            const SizedBox(height: 6),
            Text('問題数: ${mode.questionCount}問 / $timeText'),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: FilledButton(
                onPressed: mode.availableInMvp
                    ? () async {
                        final quizResult = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => QuizScreen(mode: mode),
                          ),
                        );
                        if (context.mounted && quizResult != null) {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ResultScreen(summary: quizResult),
                            ),
                          );
                        }
                      }
                    : null,
                child: const Text('開始'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
