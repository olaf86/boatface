import 'dart:io';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation/app_shell.dart';
import '../../../shared/format/date_time_formatters.dart';
import '../../quiz/domain/quiz_models.dart';
import '../../quiz/presentation/racer_name_text.dart';
import '../application/review_providers.dart';
import '../domain/review_models.dart';

class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('振り返り')),
      body: const ReviewScreen(),
    );
  }
}

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ReviewMistakeEntry>> mistakesAsync = ref.watch(
      myQuizMistakesProvider,
    );
    final Map<String, RacerProfile> racerLookup = ref.watch(
      reviewRacerLookupProvider,
    );
    final ThemeData theme = Theme.of(context);

    return mistakesAsync.when(
      data: (List<ReviewMistakeEntry> mistakes) {
        if (mistakes.isEmpty) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'まだ振り返りデータがありません',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'クイズでミスした問題がここにたまっていきます。まずはホームから遊んでみましょう。',
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () => navigateToAppShellTab(
                            context,
                            ref,
                            AppShellTab.home,
                          ),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('ホームへ戻る'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        final int currentIndex = _currentIndex.clamp(0, mistakes.length - 1);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: <Widget>[
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return CarouselSlider.builder(
                      itemCount: mistakes.length,
                      options: CarouselOptions(
                        height: constraints.maxHeight,
                        scrollDirection: Axis.vertical,
                        viewportFraction: mistakes.length == 1 ? 1 : 0.82,
                        enlargeCenterPage: false,
                        enableInfiniteScroll: false,
                        onPageChanged:
                            (int index, CarouselPageChangedReason reason) {
                              setState(() {
                                _currentIndex = index;
                              });
                            },
                      ),
                      itemBuilder:
                          (BuildContext context, int index, int realIndex) {
                            final ReviewMistakeEntry mistake = mistakes[index];
                            final bool isActive = index == currentIndex;
                            return AnimatedScale(
                              duration: const Duration(milliseconds: 180),
                              scale: isActive ? 1 : 0.83,
                              child: _ReviewMistakeCard(
                                mistake: mistake,
                                correctRacer:
                                    racerLookup[mistake.correctRacerId],
                                selectedRacer: mistake.selectedRacerId == null
                                    ? null
                                    : racerLookup[mistake.selectedRacerId!],
                              ),
                            );
                          },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: List<Widget>.generate(
                  mistakes.length,
                  (int index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: index == currentIndex ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: index == currentIndex
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '振り返りデータを読み込めませんでした',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      Text(error.toString(), style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: () => ref.invalidate(myQuizMistakesProvider),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('再試行'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReviewMistakeCard extends StatelessWidget {
  const _ReviewMistakeCard({
    required this.mistake,
    required this.correctRacer,
    required this.selectedRacer,
  });

  final ReviewMistakeEntry mistake;
  final RacerProfile? correctRacer;
  final RacerProfile? selectedRacer;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isSelectionMistake = mistake.selectedOption != null;
    final Widget details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: _RacerDetailCard(
            accentColor: const Color(0xFF0A7A4A),
            racer: correctRacer,
            fallback: mistake.correctOption,
            emphasisLabel: 'CORRECT',
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _RacerDetailCard(
            accentColor: const Color(0xFFD43D2C),
            racer: selectedRacer,
            fallback: mistake.selectedOption,
            emphasisLabel: isSelectionMistake ? 'YOUR ANSWER' : 'NO ANSWER',
          ),
        ),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _MetaChip(
                  label: mistake.modeLabel,
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                ),
                _MetaChip(
                  label: promptTypeLabel(mistake.promptType),
                  color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: details),
          ],
        ),
      ),
    );
  }
}

class _RacerDetailCard extends StatelessWidget {
  const _RacerDetailCard({
    required this.accentColor,
    required this.racer,
    required this.fallback,
    required this.emphasisLabel,
  });

  final Color accentColor;
  final RacerProfile? racer;
  final ReviewMistakeOption? fallback;
  final String emphasisLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ReviewMistakeOption? option = fallback;
    final bool isNoAnswer = racer == null && option == null;
    final String displayName = isNoAnswer
        ? ''
        : (racer?.name ?? option?.label ?? '情報なし');
    final String? nameKana = isNoAnswer
        ? null
        : (racer?.nameKana ?? option?.labelReading);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Color.alphaBlend(
          accentColor.withValues(alpha: 0.08),
          theme.colorScheme.surfaceContainerLow,
        ),
        border: Border.all(
          color: Color.alphaBlend(
            accentColor.withValues(alpha: 0.12),
            theme.colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              flex: 3,
              child: _RacerImage(
                racer: racer,
                fallback: option,
                accentColor: accentColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        accentColor.withValues(alpha: 0.12),
                        theme.colorScheme.surface,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      emphasisLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accentColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (displayName.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: RacerNameText(
                          name: displayName,
                          nameKana: nameKana,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge,
                          kanaStyle: theme.textTheme.labelMedium?.copyWith(
                            fontSize:
                                (theme.textTheme.titleLarge?.fontSize ?? 22) *
                                0.28,
                            height: 0.74,
                            color: theme.textTheme.titleLarge?.color
                                ?.withValues(alpha: 0.72),
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 18),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      children: <Widget>[
                        _InlineDetailText(
                          label: '登録番号',
                          value: racer?.registrationNumber.toString() ?? '---',
                        ),
                        const SizedBox(height: 5),
                        _InlineDetailText(
                          label: '登録期',
                          value: _registrationTermLabel(
                            racer?.registrationTerm,
                          ),
                        ),
                        const SizedBox(height: 5),
                        _InlineDetailText(
                          label: '級別',
                          value: racer?.racerClass ?? '---',
                        ),
                        const SizedBox(height: 5),
                        _InlineDetailText(
                          label: '支部',
                          value: racer?.homeBranch ?? '---',
                        ),
                        const SizedBox(height: 5),
                        _InlineDetailText(
                          label: '出身',
                          value: racer?.birthPlace ?? '---',
                        ),
                        const SizedBox(height: 5),
                        _StackedDetailText(
                          label: '生年月日',
                          value: _birthDateLabel(racer?.birthDate),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _registrationTermLabel(int? registrationTerm) {
    if (registrationTerm == null) {
      return '---';
    }
    return '$registrationTerm期';
  }

  String _birthDateLabel(DateTime? birthDate) {
    if (birthDate == null) {
      return '---';
    }
    return formatDateYmd(birthDate);
  }
}

class _RacerImage extends StatelessWidget {
  const _RacerImage({
    required this.racer,
    required this.fallback,
    required this.accentColor,
  });

  final RacerProfile? racer;
  final ReviewMistakeOption? fallback;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final bool isNoAnswer = racer == null && fallback == null;
    final String? localImagePath = racer?.localImagePath;
    final String? remoteImageUrl = racer?.imageUrl ?? fallback?.imageUrl;
    if (localImagePath != null && localImagePath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.file(
          File(localImagePath),
          fit: BoxFit.cover,
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stackTrace) {
                return _fallback(isNoAnswer: isNoAnswer);
              },
        ),
      );
    }

    if (remoteImageUrl != null && remoteImageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.network(
          remoteImageUrl,
          fit: BoxFit.cover,
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stackTrace) {
                return _fallback(isNoAnswer: isNoAnswer);
              },
        ),
      );
    }

    return _fallback(isNoAnswer: isNoAnswer);
  }

  Widget _fallback({required bool isNoAnswer}) {
    return _ReviewImageFallback(
      icon: isNoAnswer
          ? Icons.do_not_disturb_alt_rounded
          : Icons.person_search_rounded,
      isNoAnswer: isNoAnswer,
      accentColor: accentColor,
    );
  }
}

class _ReviewImageFallback extends StatelessWidget {
  const _ReviewImageFallback({
    required this.icon,
    required this.accentColor,
    this.isNoAnswer = false,
  });

  final IconData icon;
  final Color accentColor;
  final bool isNoAnswer;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxHeight < 80;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: isNoAnswer
                ? Color.alphaBlend(
                    accentColor.withValues(alpha: 0.14),
                    theme.colorScheme.surfaceContainerHighest,
                  )
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (isNoAnswer) ...<Widget>[
                Positioned(
                  top: -18,
                  right: -12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    child: const SizedBox(width: 72, height: 72),
                  ),
                ),
                Positioned(
                  left: -16,
                  bottom: -24,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor.withValues(alpha: 0.08),
                    ),
                    child: const SizedBox(width: 92, height: 92),
                  ),
                ),
              ],
              Center(
                child: isNoAnswer
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                        child: const SizedBox(width: 44, height: 44),
                      )
                    : Icon(
                        icon,
                        size: compact ? 28 : 40,
                        color: theme.colorScheme.primary,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InlineDetailText extends StatelessWidget {
  const _InlineDetailText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    const double valueScaleX = 1;
    const double labelWidth = 48;
    const double labelGap = 6;
    final ThemeData theme = Theme.of(context);
    final TextStyle? labelStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: (theme.textTheme.labelSmall?.fontSize ?? 11) - 0.5,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
    );
    final TextStyle? valueStyle = theme.textTheme.labelMedium?.copyWith(
      fontSize: (theme.textTheme.labelMedium?.fontSize ?? 12) - 0.5,
    );
    final double rowHeight = (valueStyle?.fontSize ?? 11.5) * 1.35;

    return Row(
      children: <Widget>[
        SizedBox(
          width: labelWidth,
          height: rowHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: labelStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        SizedBox(width: labelGap),
        Expanded(
          child: SizedBox(
            height: rowHeight,
            child: Center(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Transform.scale(
                    scaleX: valueScaleX,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: valueStyle),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StackedDetailText extends StatelessWidget {
  const _StackedDetailText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? labelStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: (theme.textTheme.labelSmall?.fontSize ?? 11) - 0.5,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
    );
    final TextStyle? valueStyle = theme.textTheme.labelMedium?.copyWith(
      fontSize: (theme.textTheme.labelMedium?.fontSize ?? 12) - 0.5,
    );

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: valueStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }
}
