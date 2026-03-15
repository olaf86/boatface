import 'dart:async';

import 'package:flutter/material.dart';

import '../application/quiz_session.dart';
import '../data/mock_racer_repository.dart';
import '../domain/quiz_models.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({required this.mode, required this.repository, super.key});

  final QuizModeConfig mode;
  final MockRacerRepository repository;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with WidgetsBindingObserver {
  late final QuizSession _session;
  late final Stopwatch _stopwatch;
  Timer? _ticker;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _session = QuizSessionFactory.create(
      mode: widget.mode,
      racers: widget.repository.fetchAll(),
      problemSetVersion: '2026H1',
    );
    _stopwatch = Stopwatch()..start();
    _startTicker();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (!_session.gameOver && !_session.isCompleted) {
        _session.submitTimeout(elapsed: _stopwatch.elapsed);
        _goToResult();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final QuizQuestion? question = _session.currentQuestion;
    if (_session.isCompleted || _session.gameOver || question == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToResult());
      return const Scaffold(body: SizedBox.shrink());
    }

    final int questionNumber = _session.currentIndex + 1;
    final int total = _session.questions.length;
    final String timerText = _timerLabel();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        final bool? leave = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('クイズを終了'),
            content: const Text('途中離脱としてスコアはランキングに反映されません。終了しますか？'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('続ける'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('終了する'),
              ),
            ],
          ),
        );
        if (leave == true) {
          _session.abandon();
          _goToResult();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.mode.label}  $questionNumber/$total'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                widget.mode.timeLimitSeconds == null
                    ? '制限時間: 無制限'
                    : '残り時間: $timerText',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    question.prompt,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: question.options.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (BuildContext context, int i) =>
                      FilledButton.tonal(
                        onPressed: _processing ? null : () => _submit(i),
                        style: FilledButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.all(16),
                        ),
                        child: Text(question.options[i]),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || _session.isCompleted || _session.gameOver) {
        return;
      }

      final int? limitSeconds = widget.mode.timeLimitSeconds;
      if (limitSeconds != null) {
        final Duration limit = Duration(seconds: limitSeconds);
        if (_stopwatch.elapsed >= limit) {
          _session.submitTimeout(elapsed: _stopwatch.elapsed);
          _showGameOverDialog();
          return;
        }
      }
      setState(() {});
    });
  }

  Future<void> _submit(int selectedIndex) async {
    setState(() {
      _processing = true;
    });
    _session.submitAnswer(
      selectedIndex: selectedIndex,
      elapsed: _stopwatch.elapsed,
    );
    if (_session.gameOver) {
      await _showGameOverDialog();
      return;
    }

    if (_session.isCompleted) {
      _goToResult();
      return;
    }

    _stopwatch
      ..reset()
      ..start();
    setState(() {
      _processing = false;
    });
  }

  Future<void> _showGameOverDialog() async {
    _stopwatch.stop();
    final bool canContinue = _session.canContinueWithAd;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('ゲームオーバー'),
        content: Text(canContinue ? '広告を見て1回だけ続行できます。' : 'セッションを終了します。'),
        actions: <Widget>[
          if (canContinue)
            TextButton(
              onPressed: () {
                _session.continueAfterAd();
                Navigator.of(context).pop();
              },
              child: const Text('広告を見て続行'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('結果へ'),
          ),
        ],
      ),
    );

    if (!mounted) {
      return;
    }

    if (_session.gameOver) {
      _goToResult();
      return;
    }

    if (_session.isCompleted) {
      _goToResult();
      return;
    }

    _stopwatch
      ..reset()
      ..start();
    setState(() {
      _processing = false;
    });
  }

  String _timerLabel() {
    final int? limitSeconds = widget.mode.timeLimitSeconds;
    if (limitSeconds == null) {
      return '--';
    }
    final int leftMs =
        (Duration(seconds: limitSeconds).inMilliseconds -
                _stopwatch.elapsedMilliseconds)
            .clamp(0, 99999999);
    return (leftMs / 1000).toStringAsFixed(1);
  }

  void _goToResult() {
    if (!mounted) {
      return;
    }
    _ticker?.cancel();
    _stopwatch.stop();
    Navigator.of(context).pop(_session.toSummary());
  }
}
