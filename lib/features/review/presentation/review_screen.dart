import 'dart:io';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation/app_shell.dart';
import '../../../shared/format/date_time_formatters.dart';
import '../../quiz/domain/quiz_models.dart';
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
        final ReviewMistakeEntry currentMistake = mistakes[currentIndex];

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '最近のミス 10 件',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${currentIndex + 1} / ${mistakes.length} 件目  •  ${currentMistake.modeLabel}  •  ${formatDateTimeMdHm(currentMistake.createdAt)}',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '再読み込み',
                        onPressed: () => ref.invalidate(myQuizMistakesProvider),
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return CarouselSlider.builder(
                      itemCount: mistakes.length,
                      options: CarouselOptions(
                        height: constraints.maxHeight,
                        scrollDirection: Axis.vertical,
                        viewportFraction: 1,
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
                            return _ReviewMistakeCard(
                              mistake: mistake,
                              correctRacer: racerLookup[mistake.correctRacerId],
                              selectedRacer: mistake.selectedRacerId == null
                                  ? null
                                  : racerLookup[mistake.selectedRacerId!],
                            );
                          },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
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
    final Widget details = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: _RacerDetailCard(
            title: '正解レーサー',
            accentColor: const Color(0xFF0A7A4A),
            racer: correctRacer,
            fallback: mistake.correctOption,
            emphasisLabel: 'CORRECT',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RacerDetailCard(
            title: isSelectionMistake ? '不正解レーサー' : '未回答',
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _MetaChip(
                  label: promptTypeLabel(mistake.promptType),
                  color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                ),
                _MetaChip(
                  label: '${mistake.questionIndex + 1} 問目',
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.16),
                ),
                _MetaChip(
                  label: _outcomeLabel(mistake.outcome),
                  color: theme.colorScheme.error.withValues(alpha: 0.14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.72,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.timer_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '回答時間 ${(mistake.elapsedMs / 1000).toStringAsFixed(1)} 秒',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: details),
          ],
        ),
      ),
    );
  }

  String _outcomeLabel(QuizMistakeOutcome outcome) {
    return switch (outcome) {
      QuizMistakeOutcome.wrongAnswer => '誤答',
      QuizMistakeOutcome.timeout => '時間切れ',
      QuizMistakeOutcome.abandoned => '離脱',
    };
  }
}

class _RacerDetailCard extends StatelessWidget {
  const _RacerDetailCard({
    required this.title,
    required this.accentColor,
    required this.racer,
    required this.fallback,
    required this.emphasisLabel,
  });

  final String title;
  final Color accentColor;
  final RacerProfile? racer;
  final ReviewMistakeOption? fallback;
  final String emphasisLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ReviewMistakeOption? option = fallback;
    final String displayName = racer?.name ?? option?.label ?? '情報なし';

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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
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
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 56,
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: _RacerImage(racer: racer, fallback: option),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        _DetailLine(
                          label: '基本',
                          value:
                              '${racer?.registrationNumber.toString() ?? '---'} / ${racer?.racerClass ?? '---'} / ${_genderLabel(racer?.gender)}',
                        ),
                        _DetailLine(
                          label: '生年月日',
                          value: _birthDateLabel(racer?.birthDate),
                        ),
                        _DetailLine(
                          label: '出身',
                          value: racer?.birthPlace ?? '---',
                        ),
                        _DetailLine(
                          label: '支部',
                          value: racer?.homeBranch ?? '---',
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

  String _genderLabel(String? gender) {
    return switch (gender) {
      'male' => '男子',
      'female' => '女子',
      null => '---',
      _ => gender,
    };
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

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
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
