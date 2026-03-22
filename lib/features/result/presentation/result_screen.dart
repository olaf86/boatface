import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../quiz/data/quiz_backend_repository.dart';
import '../../quiz/domain/quiz_backend_models.dart';
import '../../quiz/domain/quiz_models.dart';

class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({
    required this.summary,
    required this.sessionId,
    super.key,
  });

  final QuizResultSummary summary;
  final String sessionId;

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _isSubmitting = true;
  String? _submissionErrorMessage;
  QuizResultSubmissionReceipt? _submissionReceipt;

  @override
  void initState() {
    super.initState();
    _submitResult();
  }

  @override
  Widget build(BuildContext context) {
    final String endReasonText = switch (widget.summary.endReason) {
      QuizEndReason.completed => '全問クリア',
      QuizEndReason.wrongAnswer => '不正解で終了',
      QuizEndReason.timeout => '時間切れで終了',
      QuizEndReason.abandoned => '途中離脱',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('リザルト'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              Text(
                widget.summary.modeLabel,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                endReasonText,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              _MetricRow(label: 'スコア', value: '${widget.summary.score}'),
              _MetricRow(
                label: '正解数',
                value:
                    '${widget.summary.correctAnswers} / ${widget.summary.totalQuestions}',
              ),
              _MetricRow(
                label: '総回答時間',
                value:
                    '${(widget.summary.totalAnswerTime.inMilliseconds / 1000).toStringAsFixed(1)} 秒',
              ),
              _MetricRow(
                label: '広告続行',
                value: widget.summary.continuedByAd ? 'あり（1回）' : 'なし',
              ),
              _MetricRow(
                label: 'ランキング反映',
                value: widget.summary.rankingEligible ? '反映対象' : '反映対象外',
              ),
              const SizedBox(height: 24),
              _SubmissionStatusCard(
                isSubmitting: _isSubmitting,
                errorMessage: _submissionErrorMessage,
                submissionReceipt: _submissionReceipt,
                onRetry: _isSubmitting ? null : _submitResult,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSubmitting
                    ? null
                    : () => Navigator.of(
                        context,
                      ).popUntil((Route<dynamic> route) => route.isFirst),
                child: Text(_isSubmitting ? '結果を保存中…' : 'ホームに戻る'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitResult() async {
    setState(() {
      _isSubmitting = true;
      _submissionErrorMessage = null;
    });

    try {
      final QuizResultSubmissionReceipt receipt = await ref
          .read(quizBackendRepositoryProvider)
          .submitQuizResult(
            sessionId: widget.sessionId,
            summary: widget.summary,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _submissionReceipt = receipt;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final String message = switch (error) {
        final Exception exception => exception.toString(),
        _ => 'クイズ結果の送信に失敗しました。',
      };
      setState(() {
        _isSubmitting = false;
        _submissionErrorMessage = message;
        _submissionReceipt = null;
      });
    }
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

class _SubmissionStatusCard extends StatelessWidget {
  const _SubmissionStatusCard({
    required this.isSubmitting,
    required this.errorMessage,
    required this.submissionReceipt,
    required this.onRetry,
  });

  final bool isSubmitting;
  final String? errorMessage;
  final QuizResultSubmissionReceipt? submissionReceipt;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('サーバー保存', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (isSubmitting)
              Row(
                children: const <Widget>[
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Expanded(child: Text('クイズ結果を送信しています。')),
                ],
              )
            else if (errorMessage != null) ...<Widget>[
              Text(
                errorMessage!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('再送信')),
            ] else ...<Widget>[
              const Text('クイズ結果を保存しました。'),
              if (submissionReceipt != null) ...<Widget>[
                const SizedBox(height: 8),
                Text('結果ID: ${submissionReceipt!.resultId}'),
                Text('日次キー: ${submissionReceipt!.periodKeyDaily}'),
                Text('期別キー: ${submissionReceipt!.periodKeyTerm}'),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
