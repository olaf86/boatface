import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation/app_shell.dart';
import '../../learn/navigation/learning_navigation.dart';
import '../../profile/application/user_profile_controller.dart';
import '../../quiz/data/quiz_backend_repository.dart';
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
  late final ConfettiController _confettiController;
  bool _isSubmitting = true;
  String? _submissionErrorMessage;

  bool get _showCelebration =>
      widget.summary.endReason == QuizEndReason.completed;

  String get _celebrationMessage {
    if (widget.summary.modeId == 'master') {
      return 'ここまで来たあなたは、もう達人。次は自己ベスト更新を狙いましょう。';
    }
    final String modeName = widget.summary.modeLabel.endsWith('モード')
        ? widget.summary.modeLabel
        : '${widget.summary.modeLabel}モード';
    return '$modeNameクリアおめでとうございます！次のモードにも挑戦してみましょう！';
  }

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(milliseconds: 2400),
    );
    if (_showCelebration) {
      _confettiController.play();
    }
    _submitResult();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final QuizResultSummary summary = widget.summary;
    final ThemeData theme = Theme.of(context);
    final bool hasMistakes = widget.summary.mistakes.isNotEmpty;
    final String endReasonText = switch (summary.endReason) {
      QuizEndReason.completed => '全問クリア',
      QuizEndReason.wrongAnswer => '不正解で終了',
      QuizEndReason.timeout => '時間切れで終了',
      QuizEndReason.abandoned => '途中離脱',
    };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '遊ぶ',
          onPressed: () =>
              navigateToAppShellTab(context, ref, AppShellTab.home),
          icon: const Icon(Icons.home_rounded),
        ),
        title: const Text('リザルト'),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Center(
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
                  if (_showCelebration) ...<Widget>[
                    const SizedBox(height: 16),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: <Color>[Color(0xFFFFD54F), Color(0xFFFF8A65)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'MODE CLEAR',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _celebrationMessage,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _MetricRow(label: 'スコア', value: '${summary.score}'),
                  _MetricRow(
                    label: '正解数',
                    value:
                        '${summary.correctAnswers} / ${summary.totalQuestions}',
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
                  _SubmissionStatusCard(
                    isSubmitting: _isSubmitting,
                    errorMessage: _submissionErrorMessage,
                    onRetry: _isSubmitting ? null : _submitResult,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondary,
                      foregroundColor: theme.colorScheme.onSecondary,
                      disabledBackgroundColor: theme.colorScheme.secondary
                          .withValues(alpha: 0.48),
                      disabledForegroundColor: theme.colorScheme.onSecondary
                          .withValues(alpha: 0.72),
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () => navigateToAppShellTab(
                            context,
                            ref,
                            AppShellTab.ranking,
                          ),
                    icon: const Icon(Icons.leaderboard_rounded),
                    label: const Text('ランキングを見る'),
                  ),
                  const SizedBox(height: 16),
                  if (hasMistakes) ...<Widget>[
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF22B7E8),
                        foregroundColor: theme.colorScheme.primary,
                        disabledBackgroundColor: const Color(
                          0xFF22B7E8,
                        ).withValues(alpha: 0.42),
                        disabledForegroundColor: theme.colorScheme.primary
                            .withValues(alpha: 0.58),
                      ),
                      onPressed: _isSubmitting
                          ? null
                          : () => openLearningReviewFlow(context, ref),
                      icon: const Icon(Icons.history_edu_rounded),
                      label: const Text('ミスを振り返る'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurface.withValues(
                        alpha: 0.76,
                      ),
                      backgroundColor: theme.colorScheme.surface.withValues(
                        alpha: 0.72,
                      ),
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    onPressed: () =>
                        navigateToAppShellTab(context, ref, AppShellTab.home),
                    child: const Text('ホームに戻る'),
                  ),
                ],
              ),
            ),
          ),
          if (_showCelebration)
            Positioned.fill(
              child: IgnorePointer(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Align(
                      alignment: Alignment.topLeft,
                      child: ConfettiWidget(
                        key: const ValueKey<String>('mode-clear-confetti'),
                        confettiController: _confettiController,
                        blastDirection: 0.9,
                        blastDirectionality: BlastDirectionality.directional,
                        emissionFrequency: 0.055,
                        numberOfParticles: 14,
                        maxBlastForce: 22,
                        minBlastForce: 10,
                        gravity: 0.22,
                        shouldLoop: false,
                        colors: const <Color>[
                          Color(0xFFFF6B6B),
                          Color(0xFFFFD166),
                          Color(0xFF06D6A0),
                          Color(0xFF118AB2),
                          Color(0xFFEF476F),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: ConfettiWidget(
                        confettiController: _confettiController,
                        blastDirection: 2.24,
                        blastDirectionality: BlastDirectionality.directional,
                        emissionFrequency: 0.055,
                        numberOfParticles: 14,
                        maxBlastForce: 22,
                        minBlastForce: 10,
                        gravity: 0.22,
                        shouldLoop: false,
                        colors: const <Color>[
                          Color(0xFFFF6B6B),
                          Color(0xFFFFD166),
                          Color(0xFF06D6A0),
                          Color(0xFF118AB2),
                          Color(0xFFEF476F),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _submitResult() async {
    setState(() {
      _isSubmitting = true;
      _submissionErrorMessage = null;
    });

    try {
      await ref
          .read(quizBackendRepositoryProvider)
          .submitQuizResult(
            sessionId: widget.sessionId,
            summary: widget.summary,
          );
      if (!mounted) {
        return;
      }
      ref.invalidate(userProfileProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存しました。')));
      setState(() {
        _isSubmitting = false;
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
    required this.onRetry,
  });

  final bool isSubmitting;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: errorMessage != null
          ? Padding(
              key: const ValueKey<String>('submission-error'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: <Widget>[
                  Text(
                    'サーバー保存',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage!,
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: onRetry, child: const Text('再送信')),
                ],
              ),
            )
          : SizedBox(
              key: ValueKey<String>(
                isSubmitting ? 'submission-loading' : 'submission-success',
              ),
              height: 32,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('サーバー保存', style: theme.textTheme.titleMedium),
                    const SizedBox(width: 10),
                    if (isSubmitting)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(
                        Icons.cloud_done_rounded,
                        color: Color(0xFF0A7A4A),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
