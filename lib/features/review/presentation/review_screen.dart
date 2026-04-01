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
                        viewportFraction: mistakes.length == 1 ? 1 : 0.95,
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
                            return AnimatedScale(
                              duration: const Duration(milliseconds: 180),
                              scale: index == currentIndex ? 1 : 0.97,
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
    final String displayName = racer?.name ?? option?.label ?? '情報なし';
    final String? nameKana = racer?.nameKana ?? option?.labelReading;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        gradient: LinearGradient(
          colors: <Color>[Colors.white, accentColor.withValues(alpha: 0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              flex: 3,
              child: _RacerImage(racer: racer, fallback: option),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.14),
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
                  RacerNameText(
                    name: displayName,
                    nameKana: nameKana,
                    textAlign: TextAlign.left,
                    style: theme.textTheme.headlineSmall,
                    kanaStyle: theme.textTheme.titleSmall?.copyWith(
                      color: theme.textTheme.headlineSmall?.color?.withValues(
                        alpha: 0.78,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _InlineDetailRow(
                    leftLabel: '登録番号',
                    leftValue: racer?.registrationNumber.toString() ?? '---',
                    rightLabel: '登録期',
                    rightValue: _registrationTermLabel(racer?.registrationTerm),
                  ),
                  const SizedBox(height: 4),
                  _InlineDetailRow(
                    leftLabel: '生年月日',
                    leftValue: _birthDateLabel(racer?.birthDate),
                  ),
                  const SizedBox(height: 4),
                  _InlineDetailRow(
                    leftLabel: '級別',
                    leftValue: racer?.racerClass ?? '---',
                  ),
                  const SizedBox(height: 4),
                  _InlineDetailRow(
                    leftLabel: '支部',
                    leftValue: racer?.homeBranch ?? '---',
                    rightLabel: '出身',
                    rightValue: racer?.birthPlace ?? '---',
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
  const _RacerImage({required this.racer, required this.fallback});

  final RacerProfile? racer;
  final ReviewMistakeOption? fallback;

  @override
  Widget build(BuildContext context) {
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
                return _fallback();
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
                return _fallback();
              },
        ),
      );
    }

    return _fallback();
  }

  Widget _fallback() {
    return const _ReviewImageFallback(
      icon: Icons.person_search_rounded,
      label: '画像なし',
    );
  }
}

class _ReviewImageFallback extends StatelessWidget {
  const _ReviewImageFallback({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxHeight < 80;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: compact
                ? Icon(icon, size: 28, color: theme.colorScheme.primary)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(icon, size: 40, color: theme.colorScheme.primary),
                      const SizedBox(height: 8),
                      Text(label, style: theme.textTheme.bodyMedium),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _InlineDetailRow extends StatelessWidget {
  const _InlineDetailRow({
    required this.leftLabel,
    required this.leftValue,
    this.rightLabel,
    this.rightValue,
  });

  final String leftLabel;
  final String leftValue;
  final String? rightLabel;
  final String? rightValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _InlineDetailText(label: leftLabel, value: leftValue),
        ),
        if (rightLabel != null && rightValue != null) ...<Widget>[
          const SizedBox(width: 10),
          Expanded(
            child: _InlineDetailText(label: rightLabel!, value: rightValue!),
          ),
        ],
      ],
    );
  }
}

class _InlineDetailText extends StatelessWidget {
  const _InlineDetailText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: '$label ',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          TextSpan(text: value, style: theme.textTheme.labelMedium),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
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
