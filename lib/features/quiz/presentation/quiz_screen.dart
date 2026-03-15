import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/quiz_session_controller.dart';
import '../application/quiz_session_state.dart';
import '../domain/quiz_models.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({required this.mode, super.key});

  final QuizModeConfig mode;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen>
    with WidgetsBindingObserver {
  bool _didPop = false;
  bool _dialogVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      ref
          .read(quizSessionControllerProvider(widget.mode).notifier)
          .handleLifecyclePause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = quizSessionControllerProvider(widget.mode);
    ref.listen<QuizSessionState>(provider, (
      QuizSessionState? previous,
      QuizSessionState next,
    ) {
      if (!mounted || _didPop) {
        return;
      }

      if (next.gameOver && !(previous?.gameOver ?? false) && !_dialogVisible) {
        _showGameOverDialog(canContinue: next.canContinueWithAd);
        return;
      }

      if (next.isCompleted &&
          !next.gameOver &&
          !(previous?.isCompleted ?? false) &&
          !_dialogVisible) {
        _goToResult();
      }

      if (next.endReason == QuizEndReason.abandoned &&
          previous?.endReason != QuizEndReason.abandoned) {
        _goToResult();
      }
    });

    final QuizSessionState state = ref.watch(provider);
    final QuizQuestion? question = state.currentQuestion;

    if (question == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToResult());
      return const Scaffold(body: SizedBox.shrink());
    }

    final int questionNumber = state.currentQuestionIndex + 1;
    final String timerText = state.remainingForCurrentQuestion == null
        ? '--'
        : (state.remainingForCurrentQuestion!.inMilliseconds / 1000)
              .toStringAsFixed(1);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }
        final bool? leave = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
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
        if (leave == true && mounted) {
          ref.read(provider.notifier).abandon();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '${widget.mode.label}  $questionNumber/${state.totalQuestions}',
          ),
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
                        onPressed: state.isProcessing
                            ? null
                            : () => ref.read(provider.notifier).submitAnswer(i),
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

  Future<void> _showGameOverDialog({required bool canContinue}) async {
    _dialogVisible = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('ゲームオーバー'),
        content: Text(canContinue ? '広告を見て1回だけ続行できます。' : 'セッションを終了します。'),
        actions: <Widget>[
          if (canContinue)
            TextButton(
              onPressed: () {
                ref
                    .read(quizSessionControllerProvider(widget.mode).notifier)
                    .continueAfterAd();
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
    _dialogVisible = false;

    if (!mounted || _didPop) {
      return;
    }

    final QuizSessionState state = ref.read(
      quizSessionControllerProvider(widget.mode),
    );
    if (state.gameOver || state.isCompleted) {
      _goToResult();
    }
  }

  void _goToResult() {
    if (!mounted || _didPop) {
      return;
    }
    _didPop = true;
    final summary = ref
        .read(quizSessionControllerProvider(widget.mode).notifier)
        .summary;
    Navigator.of(context).pop(summary);
  }
}
