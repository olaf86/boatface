import 'package:flutter/material.dart';

import '../../quiz/domain/quiz_models.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({required this.summary, super.key});

  final QuizResultSummary summary;

  @override
  Widget build(BuildContext context) {
    final String endReasonText = switch (summary.endReason) {
      QuizEndReason.completed => '全問クリア',
      QuizEndReason.wrongAnswer => '不正解で終了',
      QuizEndReason.timeout => '時間切れで終了',
      QuizEndReason.abandoned => '途中離脱',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('リザルト')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              Text(
                summary.modeLabel,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                endReasonText,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              _MetricRow(label: 'スコア', value: '${summary.score}'),
              _MetricRow(
                label: '正解数',
                value: '${summary.correctAnswers} / ${summary.totalQuestions}',
              ),
              _MetricRow(
                label: '総回答時間',
                value:
                    '${(summary.totalAnswerTime.inMilliseconds / 1000).toStringAsFixed(1)} 秒',
              ),
              _MetricRow(
                label: '広告続行',
                value: summary.continuedByAd ? 'あり（1回）' : 'なし',
              ),
              _MetricRow(
                label: 'ランキング反映',
                value: summary.rankingEligible ? '反映対象' : '反映対象外',
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ホームに戻る'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
