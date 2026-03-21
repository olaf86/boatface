import 'dart:ui' show lerpDouble;
import 'dart:io';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation/app_route.dart';
import '../application/quiz_session_controller.dart';
import '../application/quiz_session_state.dart';
import '../domain/quiz_models.dart';
import '../../result/presentation/result_screen.dart';
import 'quiz_start_countdown.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({
    required this.mode,
    this.showIntroCountdown = false,
    super.key,
  });

  final QuizModeConfig mode;
  final bool showIntroCountdown;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen>
    with WidgetsBindingObserver {
  bool _didPop = false;
  bool _dialogVisible = false;
  late bool _isIntroCountdownActive;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isIntroCountdownActive = widget.showIntroCountdown;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isIntroCountdownActive) {
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      ref
          .read(quizSessionControllerProvider(widget.mode).notifier)
          .handleLifecyclePause();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isIntroCountdownActive) {
      return Scaffold(
        body: PageTransitionSwitcher(
          duration: const Duration(milliseconds: 360),
          reverse: false,
          transitionBuilder:
              (
                Widget child,
                Animation<double> primaryAnimation,
                Animation<double> secondaryAnimation,
              ) {
                return FadeThroughTransition(
                  animation: primaryAnimation,
                  secondaryAnimation: secondaryAnimation,
                  fillColor: Colors.transparent,
                  child: child,
                );
              },
          child: QuizStartCountdown(
            key: const ValueKey<String>('quiz-start-countdown'),
            modeLabel: widget.mode.label,
            onCompleted: () {
              if (!mounted) {
                return;
              }
              setState(() {
                _isIntroCountdownActive = false;
              });
            },
          ),
        ),
      );
    }

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
              Card(child: _QuizPromptCard(question: question)),
              const SizedBox(height: 12),
              Expanded(
                child: question.hasImageOptions
                    ? _QuizImageOptionGrid(
                        options: question.options,
                        enabled: !state.isProcessing,
                        onSelected: (int index) =>
                            ref.read(provider.notifier).submitAnswer(index),
                      )
                    : _QuizTextOptionList(
                        options: question.options,
                        enabled: !state.isProcessing,
                        onSelected: (int index) =>
                            ref.read(provider.notifier).submitAnswer(index),
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
    Navigator.of(context).pushReplacement(
      buildAppRoute<void>(
        page: ResultScreen(summary: summary),
        transition: AppRouteTransition.fadeThrough,
      ),
    );
  }
}

class _QuizPromptCard extends StatelessWidget {
  const _QuizPromptCard({required this.question});

  final QuizQuestion question;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final double promptImageHeight = (screenHeight * 0.24).clamp(180.0, 220.0);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(question.prompt, style: textTheme.headlineSmall),
          if (question.hasPromptImage) ...<Widget>[
            const SizedBox(height: 16),
            SizedBox(
              height: promptImageHeight,
              child: _QuizImagePanel(
                imageUrl: question.promptImageUrl!,
                localImagePath: question.promptImageLocalPath,
                semanticLabel: question.prompt,
                reveal: question.promptImageReveal,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuizTextOptionList extends StatelessWidget {
  const _QuizTextOptionList({
    required this.options,
    required this.enabled,
    required this.onSelected,
  });

  final List<QuizOption> options;
  final bool enabled;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: options.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 8),
      itemBuilder: (BuildContext context, int i) => FilledButton.tonal(
        onPressed: enabled ? () => onSelected(i) : null,
        style: FilledButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(16),
        ),
        child: Text(options[i].label),
      ),
    );
  }
}

class _QuizImageOptionGrid extends StatelessWidget {
  const _QuizImageOptionGrid({
    required this.options,
    required this.enabled,
    required this.onSelected,
  });

  final List<QuizOption> options;
  final bool enabled;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: options.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (BuildContext context, int index) {
        final QuizOption option = options[index];

        return Semantics(
          button: true,
          label: option.label,
          child: FilledButton.tonal(
            onPressed: enabled ? () => onSelected(index) : null,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: _QuizImagePanel(
                    imageUrl: option.imageUrl ?? '',
                    localImagePath: option.localImagePath,
                    semanticLabel: option.label,
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuizImagePanel extends StatefulWidget {
  const _QuizImagePanel({
    required this.imageUrl,
    required this.semanticLabel,
    this.localImagePath,
    this.reveal,
  });

  final String imageUrl;
  final String semanticLabel;
  final String? localImagePath;
  final QuizImageReveal? reveal;

  @override
  State<_QuizImagePanel> createState() => _QuizImagePanelState();
}

class _QuizImagePanelState extends State<_QuizImagePanel>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _configureAnimation();
  }

  @override
  void didUpdateWidget(covariant _QuizImagePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.localImagePath != widget.localImagePath ||
        oldWidget.reveal != widget.reveal) {
      _configureAnimation();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget image = _buildImage();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: widget.reveal == null || _controller == null
            ? image
            : AnimatedBuilder(
                animation: _controller!,
                child: image,
                builder: (BuildContext context, Widget? child) {
                  final QuizImageReveal reveal = widget.reveal!;
                  final double progress = Curves.easeOutCubic.transform(
                    _controller!.value,
                  );
                  final Alignment alignment = Alignment.lerp(
                    Alignment(reveal.startAlignmentX, reveal.startAlignmentY),
                    Alignment.center,
                    progress,
                  )!;
                  final double scale =
                      lerpDouble(reveal.startScale, 1, progress) ?? 1;

                  return Transform.scale(
                    scale: scale,
                    alignment: alignment,
                    child: child,
                  );
                },
              ),
      ),
    );
  }

  void _configureAnimation() {
    _controller?.dispose();
    final QuizImageReveal? reveal = widget.reveal;
    if (reveal == null) {
      _controller = null;
      return;
    }

    _controller = AnimationController(vsync: this, duration: reveal.duration)
      ..forward();
  }

  Widget _buildImage() {
    final String? localImagePath = widget.localImagePath;
    if (localImagePath != null && localImagePath.isNotEmpty) {
      final File localImageFile = File(localImagePath);
      return Image.file(
        localImageFile,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (BuildContext context, Object error, StackTrace? trace) {
          return _QuizImageFallback(label: widget.semanticLabel);
        },
      );
    }

    return _QuizImageFallback(label: widget.semanticLabel);
  }
}

class _QuizImageFallback extends StatelessWidget {
  const _QuizImageFallback({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.broken_image_outlined,
              size: 36,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              '$label の画像を読み込めませんでした',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
