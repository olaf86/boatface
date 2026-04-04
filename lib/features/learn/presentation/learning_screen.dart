import 'package:flutter/material.dart';

import '../navigation/learning_navigation.dart';

class LearningScreen extends StatelessWidget {
  const LearningScreen({super.key});

  static const Color _reviewButtonColor = Color(0xFF22B7E8);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Text('学習メニュー', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'ミスした問題の振り返りや、今後追加する学習コンテンツをここから開けます。',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _reviewButtonColor,
                  foregroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                onPressed: () => pushLearningReviewPage(context),
                icon: const Icon(Icons.history_edu_rounded),
                label: const Text('ミスを振り返る'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                onPressed: null,
                icon: const Icon(Icons.school_rounded),
                label: const Text('覚える'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
