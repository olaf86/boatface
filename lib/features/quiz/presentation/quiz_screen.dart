import 'dart:ui' show lerpDouble;
import 'dart:io';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation/app_route.dart';
import '../application/quiz_answer_feedback.dart';
import '../application/quiz_session_controller.dart';
import '../application/quiz_session_state.dart';
import '../domain/quiz_models.dart';
import '../../result/presentation/result_screen.dart';
import 'racer_name_text.dart';
import 'quiz_start_countdown.dart';

const Duration _kCorrectFeedbackDuration = Duration(milliseconds: 780);
const Duration _kIncorrectFeedbackDuration = Duration(milliseconds: 980);

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({
    required this.mode,
    required this.sessionId,
    this.showIntroCountdown = false,
    super.key,
  });

  final QuizModeConfig mode;
  final String sessionId;
  final bool showIntroCountdown;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _didPop = false;
  bool _dialogVisible = false;
  late bool _isIntroCountdownActive;
  late final AnimationController _backgroundFlowController;
  QuizAnswerFeedback? _activeFeedback;
  bool _isFeedbackOverlayVisible = false;
  int _hintConsumptionTick = 0;
  String? _lastConsumedHintLabel;
  String? _lastConsumedHintId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isIntroCountdownActive = widget.showIntroCountdown;
    _backgroundFlowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backgroundFlowController.dispose();
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
    final QuizAnswerFeedback? activeFeedback = _activeFeedback;
    final QuizQuestion? question =
        activeFeedback?.question ?? state.currentQuestion;

    if (question == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToResult());
      return const Scaffold(body: SizedBox.shrink());
    }

    final int questionNumber =
        (activeFeedback?.questionIndex ?? state.currentQuestionIndex) + 1;
    final Duration? remainingForDisplay =
        activeFeedback?.remainingForQuestion ??
        state.remainingForCurrentQuestion;
    final String timerText = remainingForDisplay == null
        ? '--'
        : (remainingForDisplay.inMilliseconds / 1000).toStringAsFixed(1);
    final bool inputsEnabled = !state.isProcessing && activeFeedback == null;
    final bool isTimedMode = widget.mode.timeLimitSeconds != null;
    final double? remainingRatio = _buildRemainingRatio(
      remaining: remainingForDisplay,
      totalSeconds: widget.mode.timeLimitSeconds,
    );
    final List<Color> backgroundColors = _quizBackgroundGradient(
      modeId: widget.mode.id,
      remainingRatio: remainingRatio,
      isTimeFrozen: state.timeFreezeActive,
    );
    final Color headerForegroundColor = Theme.of(context).colorScheme.primary;

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
      child: AnimatedBuilder(
        animation: _backgroundFlowController,
        builder: (BuildContext context, Widget? child) {
          return _AnimatedQuizBackdrop(
            progress: _backgroundFlowController.value,
            colors: backgroundColors,
            emphasizeMotion: !isTimedMode,
            child: child!,
          );
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            foregroundColor: headerForegroundColor,
            title: Text(
              '${widget.mode.label}  $questionNumber/${state.totalQuestions}',
            ),
          ),
          body: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Stack(
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _QuizSessionHudBar(
                          timerText: timerText,
                          remainingRatio: remainingRatio,
                          isTimeFrozen: state.timeFreezeActive,
                          totalSeconds: widget.mode.timeLimitSeconds,
                        ),
                        const SizedBox(height: 10),
                        Card(
                          color: Colors.white.withValues(alpha: 0.92),
                          child: _QuizPromptCard(
                            question: question,
                            availableHeight: constraints.maxHeight,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _QuizHintPanel(
                          showTimeFreeze: isTimedMode,
                          inputsEnabled: inputsEnabled,
                          fiftyFiftyHintUsed: state.fiftyFiftyHintUsed,
                          canUseFiftyFiftyHint: state.canUseFiftyFiftyHint,
                          timeFreezeHintUsed: state.timeFreezeHintUsed,
                          canUseTimeFreezeHint: state.canUseTimeFreezeHint,
                          hintConsumptionTick: _hintConsumptionTick,
                          consumedHintLabel: _lastConsumedHintLabel,
                          consumedHintId: _lastConsumedHintId,
                          onUseFiftyFiftyHint: _handleUseFiftyFiftyHint,
                          onUseTimeFreezeHint: _handleUseTimeFreezeHint,
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: question.hasImageOptions
                              ? _QuizImageOptionGrid(
                                  options: question.options,
                                  enabled: inputsEnabled,
                                  feedback: activeFeedback,
                                  removedOptionIndexes:
                                      state.removedOptionIndexes,
                                  onSelected: _handleAnswerSelected,
                                )
                              : _QuizTextOptionList(
                                  options: question.options,
                                  enabled: inputsEnabled,
                                  feedback: activeFeedback,
                                  removedOptionIndexes:
                                      state.removedOptionIndexes,
                                  onSelected: _handleAnswerSelected,
                                ),
                        ),
                      ],
                    ),
                    if (activeFeedback != null && _isFeedbackOverlayVisible)
                      Positioned.fill(
                        child: _QuizAnswerFeedbackOverlay(
                          key: ValueKey<String>(
                            'answer-feedback-${activeFeedback.questionIndex}-${activeFeedback.selectedIndex}-${activeFeedback.isCorrect}',
                          ),
                          feedback: activeFeedback,
                          onCompleted: _completeAnswerFeedback,
                        ),
                      ),
                  ],
                ),
              );
            },
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
        key: const ValueKey<String>('game-over-dialog'),
        title: const Text('ゲームオーバー'),
        content: Text(canContinue ? '広告を見て1回だけ続行できます。' : 'セッションを終了します。'),
        actions: <Widget>[
          if (canContinue)
            TextButton(
              onPressed: () {
                if (mounted) {
                  setState(() {
                    _activeFeedback = null;
                  });
                }
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
      return;
    }

    if (mounted) {
      setState(() {
        _activeFeedback = null;
      });
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
        page: ResultScreen(summary: summary, sessionId: widget.sessionId),
        transition: AppRouteTransition.fadeThrough,
      ),
    );
  }

  void _handleAnswerSelected(int index) {
    if (_activeFeedback != null) {
      return;
    }

    final QuizAnswerFeedback? feedback = ref
        .read(quizSessionControllerProvider(widget.mode).notifier)
        .submitAnswer(index);
    if (feedback == null || !mounted) {
      return;
    }

    setState(() {
      _activeFeedback = feedback;
      _isFeedbackOverlayVisible = true;
    });
  }

  void _handleUseFiftyFiftyHint() {
    if (_activeFeedback != null) {
      return;
    }
    final bool used = ref
        .read(quizSessionControllerProvider(widget.mode).notifier)
        .useFiftyFiftyHint();
    if (used && mounted) {
      setState(() {
        _hintConsumptionTick += 1;
        _lastConsumedHintLabel = '2択ヒント';
        _lastConsumedHintId = 'fifty-fifty';
      });
      _clearHintConsumptionEffectAfterDelay(_hintConsumptionTick);
    }
  }

  void _handleUseTimeFreezeHint() {
    if (_activeFeedback != null) {
      return;
    }
    final bool used = ref
        .read(quizSessionControllerProvider(widget.mode).notifier)
        .useTimeFreezeHint();
    if (used && mounted) {
      setState(() {
        _hintConsumptionTick += 1;
        _lastConsumedHintLabel = '時間停止';
        _lastConsumedHintId = 'time-freeze';
      });
      _clearHintConsumptionEffectAfterDelay(_hintConsumptionTick);
    }
  }

  void _clearHintConsumptionEffectAfterDelay(int tick) {
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted || _hintConsumptionTick != tick) {
        return;
      }
      setState(() {
        _lastConsumedHintLabel = null;
        _lastConsumedHintId = null;
      });
    });
  }

  void _completeAnswerFeedback() {
    if (!mounted || _activeFeedback == null) {
      return;
    }

    final bool isCorrect = _activeFeedback!.isCorrect;
    setState(() {
      _isFeedbackOverlayVisible = false;
      if (isCorrect) {
        _activeFeedback = null;
      }
    });
    ref
        .read(quizSessionControllerProvider(widget.mode).notifier)
        .completeAnswerFeedback();
  }
}

class _QuizPromptCard extends StatelessWidget {
  const _QuizPromptCard({
    required this.question,
    required this.availableHeight,
  });

  final QuizQuestion question;
  final double availableHeight;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final bool isFacePrompt =
        question.promptType == QuizPromptType.faceToName ||
        question.promptType == QuizPromptType.faceToRegistration;
    final double promptImageHeight = isFacePrompt
        ? (availableHeight * 0.29).clamp(234.0, 324.0)
        : (screenHeight * 0.42).clamp(286.0, 380.0);

    return Padding(
      padding: EdgeInsets.all(isFacePrompt ? 10 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (question.promptType == QuizPromptType.nameToFace)
            _NameToFacePrompt(question: question)
          else
            Text(question.prompt, style: textTheme.headlineSmall),
          if (question.hasPromptImage) ...<Widget>[
            const SizedBox(height: 12),
            SizedBox(
              height: promptImageHeight,
              child: _QuizImagePanel(
                imageUrl: question.promptImageUrl ?? '',
                localImagePath: question.promptImageLocalPath,
                semanticLabel: question.prompt,
                reveal: question.promptImageReveal,
                fit: question.promptImageReveal == null
                    ? BoxFit.contain
                    : BoxFit.cover,
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
    required this.feedback,
    required this.removedOptionIndexes,
    required this.onSelected,
  });

  final List<QuizOption> options;
  final bool enabled;
  final QuizAnswerFeedback? feedback;
  final Set<int> removedOptionIndexes;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      itemCount: options.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 2),
      itemBuilder: (BuildContext context, int i) {
        final bool isRemoved = removedOptionIndexes.contains(i);
        return _QuizTextOptionButton(
          buttonKey: ValueKey<String>('quiz-option-$i'),
          label: options[i].label,
          labelReading: options[i].labelReading,
          visualState: _visualStateForOption(
            index: i,
            feedback: feedback,
            eliminated: isRemoved,
          ),
          enabled: enabled && !isRemoved,
          onPressed: () => onSelected(i),
        );
      },
    );
  }
}

class _QuizImageOptionGrid extends StatelessWidget {
  const _QuizImageOptionGrid({
    required this.options,
    required this.enabled,
    required this.feedback,
    required this.removedOptionIndexes,
    required this.onSelected,
  });

  final List<QuizOption> options;
  final bool enabled;
  final QuizAnswerFeedback? feedback;
  final Set<int> removedOptionIndexes;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      itemCount: options.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (BuildContext context, int index) {
        final QuizOption option = options[index];
        final bool isRemoved = removedOptionIndexes.contains(index);
        final _QuizOptionVisualState visualState = _visualStateForOption(
          index: index,
          feedback: feedback,
          eliminated: isRemoved,
        );

        return Semantics(
          button: true,
          label: option.label,
          child: _QuizImageOptionButton(
            buttonKey: ValueKey<String>('quiz-option-$index'),
            indexLabel: '${index + 1}',
            visualState: visualState,
            enabled: enabled && !isRemoved,
            onPressed: () => onSelected(index),
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
                  child: _QuizOptionIndexChip(
                    label: '${index + 1}',
                    accentColor: _accentColorFor(context, visualState),
                    highlighted: _isHighlighted(visualState),
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

class _NameToFacePrompt extends StatelessWidget {
  const _NameToFacePrompt({required this.question});

  final QuizQuestion question;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final QuizOption target = question.options[question.correctIndex];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        RacerNameText(
          name: target.label,
          nameKana: target.labelReading,
          style: textTheme.headlineSmall,
          kanaStyle: textTheme.titleSmall?.copyWith(
            color: textTheme.headlineSmall?.color?.withValues(alpha: 0.78),
          ),
        ),
        const SizedBox(height: 6),
        Text(question.prompt, style: textTheme.titleMedium),
      ],
    );
  }
}

enum _QuizOptionVisualState {
  idle,
  dimmed,
  eliminated,
  selectedCorrect,
  selectedWrong,
  correctReveal,
}

_QuizOptionVisualState _visualStateForOption({
  required int index,
  required QuizAnswerFeedback? feedback,
  required bool eliminated,
}) {
  if (feedback == null) {
    return eliminated
        ? _QuizOptionVisualState.eliminated
        : _QuizOptionVisualState.idle;
  }
  if (feedback.isCorrect) {
    return index == feedback.selectedIndex
        ? _QuizOptionVisualState.selectedCorrect
        : _QuizOptionVisualState.dimmed;
  }
  if (index == feedback.selectedIndex) {
    return _QuizOptionVisualState.selectedWrong;
  }
  if (index == feedback.correctIndex) {
    return _QuizOptionVisualState.correctReveal;
  }
  return _QuizOptionVisualState.dimmed;
}

class _QuizTextOptionButton extends StatelessWidget {
  const _QuizTextOptionButton({
    required this.buttonKey,
    required this.label,
    this.labelReading,
    required this.visualState,
    required this.enabled,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final String? labelReading;
  final _QuizOptionVisualState visualState;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color accentColor = _accentColorFor(context, visualState);
    final bool highlighted = _isHighlighted(visualState);
    const TextStyle optionNameStyle = TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 0.92,
    );
    const TextStyle optionKanaStyle = TextStyle(
      color: Colors.white,
      fontSize: 5.5,
      fontWeight: FontWeight.w700,
      height: 1,
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: _opacityFor(visualState),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutBack,
        scale: _scaleFor(visualState),
        child: FilledButton.tonal(
          key: buttonKey,
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            alignment: Alignment.center,
            backgroundColor: _backgroundColorFor(context, visualState),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            side: highlighted
                ? BorderSide(
                    color: accentColor.withValues(alpha: 0.9),
                    width: 2,
                  )
                : null,
          ),
          child: SizedBox(
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: highlighted ? 44 : 0,
                  ),
                  child: RacerNameText(
                    name: label,
                    nameKana: labelReading,
                    style: optionNameStyle,
                    kanaStyle: optionKanaStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
                if (highlighted)
                  Positioned(
                    top: 4,
                    right: 2,
                    child: _QuizOptionResultBadge(
                      visualState: visualState,
                      accentColor: accentColor,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizImageOptionButton extends StatelessWidget {
  const _QuizImageOptionButton({
    required this.buttonKey,
    required this.indexLabel,
    required this.visualState,
    required this.enabled,
    required this.onPressed,
    required this.child,
  });

  final Key buttonKey;
  final String indexLabel;
  final _QuizOptionVisualState visualState;
  final bool enabled;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Color accentColor = _accentColorFor(context, visualState);
    final bool highlighted = _isHighlighted(visualState);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: _opacityFor(visualState),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutBack,
        scale: _scaleFor(visualState),
        child: FilledButton.tonal(
          key: buttonKey,
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: _backgroundColorFor(context, visualState),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: highlighted
                  ? BorderSide(
                      color: accentColor.withValues(alpha: 0.9),
                      width: 2,
                    )
                  : BorderSide.none,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              child,
              if (highlighted)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _QuizOptionResultBadge(
                    visualState: visualState,
                    accentColor: accentColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizOptionIndexChip extends StatelessWidget {
  const _QuizOptionIndexChip({
    required this.label,
    required this.accentColor,
    required this.highlighted,
  });

  final String label;
  final Color accentColor;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlighted
            ? accentColor.withValues(alpha: 0.14)
            : Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(label, style: Theme.of(context).textTheme.labelLarge),
      ),
    );
  }
}

class _QuizOptionResultBadge extends StatelessWidget {
  const _QuizOptionResultBadge({
    required this.visualState,
    required this.accentColor,
  });

  final _QuizOptionVisualState visualState;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final _IconAndLabel iconAndLabel = switch (visualState) {
      _QuizOptionVisualState.selectedCorrect => const _IconAndLabel(
        icon: Icons.check_rounded,
        label: 'GOOD',
      ),
      _QuizOptionVisualState.selectedWrong => const _IconAndLabel(
        icon: Icons.close_rounded,
        label: 'MISS',
      ),
      _QuizOptionVisualState.correctReveal => const _IconAndLabel(
        icon: Icons.lightbulb_rounded,
        label: 'ANSWER',
      ),
      _ => const _IconAndLabel(icon: Icons.circle, label: ''),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(iconAndLabel.icon, size: 13, color: Colors.white),
            const SizedBox(width: 2),
            Text(
              iconAndLabel.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                height: 0.95,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconAndLabel {
  const _IconAndLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

bool _isHighlighted(_QuizOptionVisualState visualState) {
  return visualState == _QuizOptionVisualState.selectedCorrect ||
      visualState == _QuizOptionVisualState.selectedWrong ||
      visualState == _QuizOptionVisualState.correctReveal;
}

double _opacityFor(_QuizOptionVisualState visualState) {
  return switch (visualState) {
    _QuizOptionVisualState.dimmed => 0.42,
    _QuizOptionVisualState.eliminated => 0.2,
    _ => 1,
  };
}

double _scaleFor(_QuizOptionVisualState visualState) {
  return switch (visualState) {
    _QuizOptionVisualState.selectedCorrect => 1.02,
    _QuizOptionVisualState.selectedWrong => 0.985,
    _QuizOptionVisualState.correctReveal => 1.01,
    _ => 1,
  };
}

Color _accentColorFor(
  BuildContext context,
  _QuizOptionVisualState visualState,
) {
  return visualState == _QuizOptionVisualState.selectedWrong
      ? Theme.of(context).colorScheme.error
      : const Color(0xFF18A56B);
}

Color? _backgroundColorFor(
  BuildContext context,
  _QuizOptionVisualState visualState,
) {
  final Color accentColor = _accentColorFor(context, visualState);
  return switch (visualState) {
    _QuizOptionVisualState.selectedCorrect => accentColor.withValues(
      alpha: 0.16,
    ),
    _QuizOptionVisualState.selectedWrong => accentColor.withValues(alpha: 0.16),
    _QuizOptionVisualState.correctReveal => accentColor.withValues(alpha: 0.16),
    _QuizOptionVisualState.eliminated => Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest,
    _ => null,
  };
}

class _AnimatedQuizBackdrop extends StatelessWidget {
  const _AnimatedQuizBackdrop({
    required this.progress,
    required this.colors,
    required this.emphasizeMotion,
    required this.child,
  });

  final double progress;
  final List<Color> colors;
  final bool emphasizeMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double animatedProgress = emphasizeMotion
        ? Curves.easeInOutSine.transform(progress)
        : progress;
    final Alignment begin = Alignment.lerp(
      emphasizeMotion
          ? const Alignment(-0.22, -1.35)
          : const Alignment(0, -1.2),
      emphasizeMotion
          ? const Alignment(0.3, -0.65)
          : const Alignment(-0.18, -0.95),
      animatedProgress,
    )!;
    final Alignment end = Alignment.lerp(
      emphasizeMotion
          ? const Alignment(-0.12, 1.22)
          : const Alignment(0.12, 1.15),
      emphasizeMotion
          ? const Alignment(0.55, 0.72)
          : const Alignment(0.32, 1.0),
      animatedProgress,
    )!;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors, begin: begin, end: end),
          ),
        ),
        IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Align(
                alignment: Alignment.lerp(
                  emphasizeMotion
                      ? const Alignment(-1.2, -1.0)
                      : const Alignment(-1.15, -0.9),
                  emphasizeMotion
                      ? const Alignment(0.85, -0.05)
                      : const Alignment(0.65, -0.25),
                  animatedProgress,
                )!,
                child: _BackdropOrb(
                  color: colors.first.withValues(
                    alpha: emphasizeMotion ? 0.34 : 0.26,
                  ),
                  size: emphasizeMotion ? 260 : 240,
                ),
              ),
              Align(
                alignment: Alignment.lerp(
                  emphasizeMotion
                      ? const Alignment(1.2, 0.15)
                      : const Alignment(1.1, 0.3),
                  emphasizeMotion
                      ? const Alignment(-0.65, 1.05)
                      : const Alignment(-0.45, 0.95),
                  animatedProgress,
                )!,
                child: _BackdropOrb(
                  color: colors.last.withValues(
                    alpha: emphasizeMotion ? 0.24 : 0.18,
                  ),
                  size: emphasizeMotion ? 300 : 280,
                ),
              ),
              Align(
                alignment: Alignment.lerp(
                  emphasizeMotion
                      ? const Alignment(-0.1, -1.25)
                      : const Alignment(0.25, -1.2),
                  emphasizeMotion
                      ? const Alignment(1.05, 0.55)
                      : const Alignment(1.0, 0.35),
                  animatedProgress,
                )!,
                child: _BackdropOrb(
                  color: colors[1].withValues(
                    alpha: emphasizeMotion ? 0.2 : 0.16,
                  ),
                  size: emphasizeMotion ? 220 : 200,
                ),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class _BackdropOrb extends StatelessWidget {
  const _BackdropOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color,
            blurRadius: size * 0.6,
            spreadRadius: size * 0.1,
          ),
        ],
      ),
      child: SizedBox.square(dimension: size),
    );
  }
}

class _QuizSessionHudBar extends StatelessWidget {
  const _QuizSessionHudBar({
    required this.timerText,
    required this.remainingRatio,
    required this.isTimeFrozen,
    required this.totalSeconds,
  });

  final String timerText;
  final double? remainingRatio;
  final bool isTimeFrozen;
  final int? totalSeconds;

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    final bool isTimed = totalSeconds != null;
    final Color accentColor = isTimed
        ? _timerAccentColor(
            remainingRatio: remainingRatio ?? 0,
            isTimeFrozen: isTimeFrozen,
          )
        : const Color(0xFF145E9C);

    if (!isTimed) {
      final Color primary = Theme.of(context).colorScheme.primary;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '∞',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'FREE',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final int segmentCount = totalSeconds! <= 8 ? totalSeconds! : 10;
    final double hudRatio = remainingRatio ?? 0;
    final int activeSegments = isTimeFrozen
        ? segmentCount
        : (hudRatio * segmentCount).ceil().clamp(0, segmentCount);

    return Row(
      children: <Widget>[
        _QuizHudCapsule(
          icon: isTimed
              ? (isTimeFrozen
                    ? Icons.pause_circle_filled_rounded
                    : Icons.timer_rounded)
              : Icons.all_inclusive_rounded,
          label: isTimed ? (isTimeFrozen ? 'STOP' : 'LIMIT') : 'FREE',
          highlightColor: accentColor,
          foregroundColor: primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuizMeterStrip(
            segmentCount: segmentCount,
            activeSegments: activeSegments,
            activeColor: accentColor,
            isDanger: isTimed && !isTimeFrozen && hudRatio <= 0.3,
          ),
        ),
        const SizedBox(width: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 68),
          child: Align(
            alignment: Alignment.centerRight,
            child: isTimed
                ? Text(
                    '$timerText s',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                      shadows: <Shadow>[
                        Shadow(
                          color: Colors.white.withValues(alpha: 0.25),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  )
                : RichText(
                    text: TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: '∞',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        TextSpan(
                          text: '  FREE',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _QuizHudCapsule extends StatelessWidget {
  const _QuizHudCapsule({
    required this.icon,
    required this.label,
    required this.highlightColor,
    this.foregroundColor = Colors.white,
  });

  final IconData icon;
  final String label;
  final Color highlightColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: highlightColor.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 18, color: foregroundColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizMeterStrip extends StatelessWidget {
  const _QuizMeterStrip({
    required this.segmentCount,
    required this.activeSegments,
    required this.activeColor,
    required this.isDanger,
  });

  final int segmentCount;
  final int activeSegments;
  final Color activeColor;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(segmentCount, (int index) {
        final bool isActive = index < activeSegments;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == segmentCount - 1 ? 0 : 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: isActive ? 14 : 8,
              decoration: BoxDecoration(
                color: isActive
                    ? (isDanger
                          ? const Color(0xFFE9A4B4)
                          : activeColor.withValues(alpha: 0.9))
                    : activeColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
                boxShadow: isActive
                    ? <BoxShadow>[
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.18),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _QuizHintPanel extends StatelessWidget {
  const _QuizHintPanel({
    required this.showTimeFreeze,
    required this.inputsEnabled,
    required this.fiftyFiftyHintUsed,
    required this.canUseFiftyFiftyHint,
    required this.timeFreezeHintUsed,
    required this.canUseTimeFreezeHint,
    required this.hintConsumptionTick,
    required this.consumedHintLabel,
    required this.consumedHintId,
    required this.onUseFiftyFiftyHint,
    required this.onUseTimeFreezeHint,
  });

  final bool showTimeFreeze;
  final bool inputsEnabled;
  final bool fiftyFiftyHintUsed;
  final bool canUseFiftyFiftyHint;
  final bool timeFreezeHintUsed;
  final bool canUseTimeFreezeHint;
  final int hintConsumptionTick;
  final String? consumedHintLabel;
  final String? consumedHintId;
  final VoidCallback onUseFiftyFiftyHint;
  final VoidCallback onUseTimeFreezeHint;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: <Widget>[
            _QuizHintButton(
              buttonKey: const ValueKey<String>('quiz-hint-fifty-fifty'),
              hintId: 'fifty-fifty',
              icon: Icons.filter_2_rounded,
              tooltip: fiftyFiftyHintUsed ? '2択ヒントは使用済み' : '2択に絞る',
              isUsed: fiftyFiftyHintUsed,
              enabled: inputsEnabled && canUseFiftyFiftyHint,
              justConsumed: consumedHintId == 'fifty-fifty',
              consumptionTick: hintConsumptionTick,
              onPressed: onUseFiftyFiftyHint,
            ),
            if (showTimeFreeze) ...<Widget>[
              const SizedBox(width: 8),
              _QuizHintButton(
                buttonKey: const ValueKey<String>('quiz-hint-time-freeze'),
                hintId: 'time-freeze',
                icon: Icons.pause_rounded,
                tooltip: timeFreezeHintUsed ? '時間停止ヒントは使用済み' : '時間を停止する',
                isUsed: timeFreezeHintUsed,
                enabled: inputsEnabled && canUseTimeFreezeHint,
                justConsumed: consumedHintId == 'time-freeze',
                consumptionTick: hintConsumptionTick,
                onPressed: onUseTimeFreezeHint,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuizHintButton extends StatelessWidget {
  const _QuizHintButton({
    required this.buttonKey,
    required this.hintId,
    required this.icon,
    required this.tooltip,
    required this.isUsed,
    required this.enabled,
    required this.justConsumed,
    required this.consumptionTick,
    required this.onPressed,
  });

  final Key buttonKey;
  final String hintId;
  final IconData icon;
  final String tooltip;
  final bool isUsed;
  final bool enabled;
  final bool justConsumed;
  final int consumptionTick;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final List<Color> buttonColors = isUsed
        ? <Color>[
            colorScheme.surfaceContainerHighest,
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
          ]
        : <Color>[const Color(0xFF145E9C), const Color(0xFF22B7E8)];

    return Tooltip(
      message: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: buttonColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isUsed
                    ? colorScheme.outlineVariant.withValues(alpha: 0.42)
                    : Colors.white.withValues(alpha: 0.18),
              ),
              boxShadow: isUsed
                  ? null
                  : <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xFF145E9C).withValues(alpha: 0.26),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: buttonKey,
                borderRadius: BorderRadius.circular(16),
                onTap: enabled ? onPressed : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isUsed
                        ? colorScheme.onSurface.withValues(alpha: 0.36)
                        : Colors.white,
                  ),
                ),
              ),
            ),
          ),
          if (justConsumed)
            Positioned.fill(
              child: IgnorePointer(
                child:
                    DecoratedBox(
                          key: ValueKey<String>(
                            'hint-burst-$hintId-$consumptionTick',
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFFFE082),
                              width: 2,
                            ),
                          ),
                        )
                        .animate()
                        .fadeOut(duration: 420.ms)
                        .scaleXY(begin: 0.96, end: 1.12),
              ),
            ),
          if (justConsumed)
            Positioned(
              top: -10,
              right: -6,
              child: DecoratedBox(
                key: ValueKey<String>('hint-stamp-$hintId-$consumptionTick'),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE082),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFFFFE082).withValues(alpha: 0.32),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    'USED!',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF4F2F00),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 90.ms).scaleXY(begin: 1.4, end: 1),
            ),
        ],
      ),
    );
  }
}

double? _buildRemainingRatio({
  required Duration? remaining,
  required int? totalSeconds,
}) {
  if (remaining == null || totalSeconds == null || totalSeconds <= 0) {
    return null;
  }
  return (remaining.inMilliseconds /
          Duration(seconds: totalSeconds).inMilliseconds)
      .clamp(0.0, 1.0);
}

List<Color> _quizBackgroundGradient({
  required String modeId,
  required double? remainingRatio,
  required bool isTimeFrozen,
}) {
  if (modeId == 'careful') {
    return const <Color>[
      Color(0xFFBBDDFC),
      Color(0xFFDCEEFF),
      Color(0xFFFCFEFF),
    ];
  }
  if (isTimeFrozen) {
    return const <Color>[
      Color(0xFFCBE6F9),
      Color(0xFFE1F2FF),
      Color(0xFFF5FBFF),
    ];
  }
  if (remainingRatio == null) {
    return const <Color>[
      Color(0xFFD2E7FA),
      Color(0xFFE8F4FF),
      Color(0xFFF8FCFF),
    ];
  }

  final Color safeStart = const Color(0xFFCFE5FA);
  final Color safeMid = const Color(0xFFE6F3FF);
  final Color safeEnd = const Color(0xFFF8FCFF);
  final Color dangerStart = const Color(0xFFF1D5DE);
  final Color dangerMid = const Color(0xFFFBE9EE);
  final Color dangerEnd = const Color(0xFFFFFBFC);

  return <Color>[
    Color.lerp(dangerStart, safeStart, remainingRatio)!,
    Color.lerp(dangerMid, safeMid, remainingRatio)!,
    Color.lerp(dangerEnd, safeEnd, remainingRatio)!,
  ];
}

Color _timerAccentColor({
  required double remainingRatio,
  required bool isTimeFrozen,
}) {
  if (isTimeFrozen) {
    return const Color(0xFF7CC8EA);
  }
  return Color.lerp(
    const Color(0xFFE9A4B4),
    const Color(0xFFB7D9F8),
    remainingRatio.clamp(0.0, 1.0),
  )!;
}

class _QuizAnswerFeedbackOverlay extends StatelessWidget {
  const _QuizAnswerFeedbackOverlay({
    required this.feedback,
    required this.onCompleted,
    super.key,
  });

  final QuizAnswerFeedback feedback;
  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context) {
    final bool isCorrect = feedback.isCorrect;
    final Color accentColor = isCorrect
        ? const Color(0xFF18A56B)
        : Theme.of(context).colorScheme.error;
    final Duration duration = isCorrect
        ? _kCorrectFeedbackDuration
        : _kIncorrectFeedbackDuration;

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ColoredBox(
                color: accentColor.withValues(alpha: isCorrect ? 0.08 : 0.12),
              )
              .animate()
              .fadeIn(duration: 100.ms)
              .then(delay: 110.ms)
              .fadeOut(duration: 320.ms),
          Center(
            child:
                _QuizFeedbackBadge(
                      label: isCorrect ? '正解！' : '不正解',
                      caption: isCorrect ? 'NEXT WAVE' : 'GAME OVER',
                      color: accentColor,
                      icon: isCorrect
                          ? Icons.waving_hand_rounded
                          : Icons.warning_rounded,
                    )
                    .animate(onComplete: (_) => onCompleted())
                    .fadeIn(duration: 150.ms)
                    .scaleXY(begin: 0.72, end: 1.0, duration: 260.ms)
                    .then(delay: duration - const Duration(milliseconds: 500))
                    .fadeOut(duration: 220.ms)
                    .scaleXY(end: 0.92, duration: 220.ms),
          ),
        ],
      ),
    );
  }
}

class _QuizFeedbackBadge extends StatelessWidget {
  const _QuizFeedbackBadge({
    required this.label,
    required this.caption,
    required this.color,
    required this.icon,
  });

  final String label;
  final String caption;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: <Color>[color, color.withValues(alpha: 0.78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.24),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 30, color: Colors.white),
            const SizedBox(height: 10),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              caption,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.88),
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizImagePanel extends StatefulWidget {
  const _QuizImagePanel({
    required this.imageUrl,
    required this.semanticLabel,
    this.localImagePath,
    this.reveal,
    this.fit = BoxFit.contain,
  });

  final String imageUrl;
  final String semanticLabel;
  final String? localImagePath;
  final QuizImageReveal? reveal;
  final BoxFit fit;

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
        oldWidget.reveal != widget.reveal ||
        oldWidget.fit != widget.fit) {
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
        fit: widget.fit,
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
