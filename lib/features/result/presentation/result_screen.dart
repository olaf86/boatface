import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../quiz/domain/quiz_models.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({required this.summary, super.key});

  final QuizResultSummary summary;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final ConfettiController _confettiController;

  bool get _showCelebration =>
      widget.summary.endReason == QuizEndReason.completed;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(milliseconds: 2400),
    );
    if (_showCelebration) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final QuizResultSummary summary = widget.summary;
    final String endReasonText = switch (summary.endReason) {
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
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'MODE CLEAR',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '紙吹雪と一緒にリザルトを表示しています。',
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
                  FilledButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).popUntil((Route<dynamic> route) => route.isFirst),
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
