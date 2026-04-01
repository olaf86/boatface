import 'package:flutter/material.dart';

import '../navigation/learning_navigation.dart';

class LearningScreen extends StatelessWidget {
  const LearningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withValues(
                          alpha: 0.18,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'LEARNING HUB',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('学習メニュー', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 10),
                    Text(
                      'ミスした選手の振り返りと、今後追加する学習コンテンツの入口をこの画面にまとめます。',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _LearningActionCard(
              title: '振り返り',
              description: '最近ミスした問題を見直して、正解だった選手と誤答した選手を並べて確認します。',
              icon: Icons.history_edu_rounded,
              buttonLabel: '振り返りを開く',
              onPressed: () => pushLearningReviewPage(context),
            ),
            const SizedBox(height: 14),
            _LearningActionCard(
              title: '覚える',
              description: '将来的に、苦手な選手をまとめて覚えるための学習コンテンツをここに追加します。',
              icon: Icons.school_rounded,
              buttonLabel: '準備中',
              onPressed: null,
            ),
          ],
        ),
      ),
    );
  }
}

class _LearningActionCard extends StatelessWidget {
  const _LearningActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String description;
  final IconData icon;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(description, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 16),
                  if (onPressed != null)
                    FilledButton(onPressed: onPressed, child: Text(buttonLabel))
                  else
                    OutlinedButton(onPressed: null, child: Text(buttonLabel)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
