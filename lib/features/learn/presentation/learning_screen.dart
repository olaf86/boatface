import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation/app_shell.dart';

class LearningScreen extends ConsumerWidget {
  const LearningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                      'COMING SOON',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('学習モードを準備中です', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 10),
                  Text(
                    'ミスした選手を繰り返し見直したり、条件別にまとめて覚えたりできる画面をここに追加していきます。',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      ref
                          .read(appShellTabControllerProvider.notifier)
                          .select(AppShellTab.review);
                    },
                    icon: const Icon(Icons.history_edu_rounded),
                    label: const Text('先に振り返りを見る'),
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
