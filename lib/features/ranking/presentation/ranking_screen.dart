import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../quiz/domain/quiz_models.dart';
import '../../quiz/domain/quiz_modes.dart';
import '../application/ranking_providers.dart';
import '../domain/ranking_models.dart';

class RankingScreen extends ConsumerStatefulWidget {
  const RankingScreen({super.key});

  @override
  ConsumerState<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends ConsumerState<RankingScreen> {
  String _modeId = 'quick';
  RankingPeriod _period = RankingPeriod.today;

  @override
  Widget build(BuildContext context) {
    final RankingRequest request = RankingRequest(
      modeId: _modeId,
      period: _period,
    );
    final AsyncValue<RankingSnapshot> rankingAsync = ref.watch(
      rankingSnapshotProvider(request),
    );
    final AsyncValue<RankingCurrentUserSummary> currentUserSummaryAsync = ref
        .watch(rankingCurrentUserSummaryProvider(request));
    final String? currentUserId = ref.watch(authStateProvider).valueOrNull?.uid;
    final QuizModeConfig mode = kQuizModes.firstWhere(
      (QuizModeConfig item) => item.id == _modeId,
    );
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool twoColumn = constraints.maxWidth >= 900;
        final Widget filters = ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      flex: 4,
                      child: DropdownButtonFormField<String>(
                        initialValue: _modeId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'モード',
                          border: OutlineInputBorder(),
                        ),
                        items: kQuizModes
                            .where((QuizModeConfig mode) => mode.availableInMvp)
                            .map(
                              (QuizModeConfig mode) => DropdownMenuItem<String>(
                                value: mode.id,
                                child: Text(mode.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (String? value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _modeId = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: SegmentedButton<RankingPeriod>(
                        showSelectedIcon: false,
                        segments: <ButtonSegment<RankingPeriod>>[
                          ButtonSegment<RankingPeriod>(
                            value: RankingPeriod.today,
                            label: _PeriodSegmentLabel(
                              text: '本日',
                              selected: _period == RankingPeriod.today,
                            ),
                          ),
                          ButtonSegment<RankingPeriod>(
                            value: RankingPeriod.term,
                            label: _PeriodSegmentLabel(
                              text: '期別',
                              selected: _period == RankingPeriod.term,
                            ),
                          ),
                        ],
                        selected: <RankingPeriod>{_period},
                        onSelectionChanged: (Set<RankingPeriod> value) {
                          setState(() {
                            _period = value.first;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _CurrentUserCard(
              summaryAsync: currentUserSummaryAsync,
            ),
          ],
        );

        final Widget leaderboard = Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Card(
            clipBehavior: Clip.hardEdge,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${mode.label} / ${_period.label}',
                              style: theme.textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '再読み込み',
                        onPressed: () {
                          ref.invalidate(rankingSnapshotProvider(request));
                          ref.invalidate(rankingTermBestScoreProvider(_modeId));
                          ref.invalidate(
                            rankingCurrentUserSummaryProvider(request),
                          );
                        },
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _LeaderboardTableHeader(theme: theme),
                const Divider(height: 1),
                Expanded(
                  child: ClipRect(
                    child: rankingAsync.when(
                      data: (RankingSnapshot snapshot) {
                        if (snapshot.entries.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('まだランキングデータがありません。'),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: snapshot.entries.length,
                          separatorBuilder: (BuildContext context, int index) =>
                              Divider(
                                height: 1,
                                color: theme.colorScheme.outlineVariant,
                              ),
                          itemBuilder: (BuildContext context, int index) {
                            final RankingEntry entry = snapshot.entries[index];
                            final bool isCurrentUser =
                                currentUserId != null &&
                                currentUserId == entry.userId;
                            return _RankingListRow(
                              entry: entry,
                              isCurrentUser: isCurrentUser,
                              formattedTime: _formatSeconds(
                                entry.totalAnswerTimeMs,
                              ),
                            );
                          },
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (Object error, StackTrace stackTrace) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  _messageForError(error),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: () => ref.invalidate(
                                    rankingSnapshotProvider(request),
                                  ),
                                  child: const Text('再試行'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        if (!twoColumn) {
          return Column(
            children: <Widget>[
              SizedBox(height: 220, child: filters),
              Expanded(child: leaderboard),
            ],
          );
        }

        return Row(
          children: <Widget>[
            SizedBox(width: 300, child: filters),
            VerticalDivider(width: 1, color: theme.colorScheme.outlineVariant),
            Expanded(child: leaderboard),
          ],
        );
      },
    );
  }

  String _formatSeconds(int totalTimeMs) {
    return '${(totalTimeMs / 1000).toStringAsFixed(1)}秒';
  }

  String _messageForError(Object error) {
    return switch (error) {
      final Exception exception => exception.toString(),
      _ => 'ランキングの取得に失敗しました。',
    };
  }
}

class _LeaderboardTableHeader extends StatelessWidget {
  const _LeaderboardTableHeader({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: DefaultTextStyle(
          style: theme.textTheme.labelMedium!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
          child: const Row(
            children: <Widget>[
              SizedBox(width: 68, child: Text('順位')),
              Expanded(child: Text('プレイヤー')),
              SizedBox(width: 72, child: Text('タイム', textAlign: TextAlign.end)),
              SizedBox(
                width: 92,
                child: Text('SCORE', textAlign: TextAlign.end),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankingListRow extends StatelessWidget {
  const _RankingListRow({
    required this.entry,
    required this.isCurrentUser,
    required this.formattedTime,
  });

  final RankingEntry entry;
  final bool isCurrentUser;
  final String formattedTime;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color? crownColor = _crownColorForRank(entry.rank);
    const Color currentUserHighlight = Color(0xFFFFD54F);
    const Color currentUserAccent = Color(0xFF6B4F00);
    final Color scoreColor = isCurrentUser ? currentUserAccent : theme.colorScheme.primary;

    return ColoredBox(
      color: isCurrentUser
          ? currentUserHighlight.withValues(alpha: 0.34)
          : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 68,
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 22,
                    child: crownColor == null
                        ? null
                        : Icon(
                            Icons.workspace_premium_rounded,
                            size: 18,
                            color: crownColor,
                          ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${entry.rank}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    entry.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.region?.label ?? '地域未設定',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 72,
              child: Text(
                formattedTime,
                textAlign: TextAlign.end,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 80,
              child: Align(
                alignment: Alignment.centerRight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      '${entry.score}',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scoreColor,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color? _crownColorForRank(int rank) {
    return switch (rank) {
      1 => const Color(0xFFD4AF37),
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => null,
    };
  }
}

class _CurrentUserCard extends StatelessWidget {
  const _CurrentUserCard({required this.summaryAsync});

  final AsyncValue<RankingCurrentUserSummary> summaryAsync;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: summaryAsync.when(
          data: (RankingCurrentUserSummary summary) {
            final RankingEntry? currentUserEntry = summary.currentUserEntry;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _CurrentUserMetricCard(
                        label: '当期ベストスコア',
                        value: summary.termBestScore.bestScore?.toString() ?? '---',
                        enableShine: summary.termBestScore.bestScore != null,
                        shineDelayFraction: 0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CurrentUserMetricCard(
                        label: '現在の順位',
                        value: currentUserEntry == null
                            ? '圏外'
                            : '${currentUserEntry.rank}位',
                        enableShine: currentUserEntry != null,
                        shineDelayFraction: 0.1,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => const SizedBox(
            height: 112,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object error, StackTrace stackTrace) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _messageForError(error),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _messageForError(Object error) {
    return switch (error) {
      final Exception exception => exception.toString(),
      _ => 'ランキングの取得に失敗しました。',
    };
  }
}

class _CurrentUserMetricCard extends StatefulWidget {
  const _CurrentUserMetricCard({
    required this.label,
    required this.value,
    required this.enableShine,
    required this.shineDelayFraction,
  });

  final String label;
  final String value;
  final bool enableShine;
  final double shineDelayFraction;

  @override
  State<_CurrentUserMetricCard> createState() => _CurrentUserMetricCardState();
}

class _CurrentUserMetricCardState extends State<_CurrentUserMetricCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shineController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6700),
  );

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _CurrentUserMetricCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enableShine != widget.enableShine) {
      _syncAnimation();
    }
  }

  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  void _syncAnimation() {
    if (widget.enableShine) {
      _shineController.repeat();
    } else {
      _shineController
        ..stop()
        ..value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final BorderRadius borderRadius = BorderRadius.circular(20);
    final Color backgroundColor = widget.enableShine
        ? const Color(0xFFFFD54F)
        : theme.colorScheme.primaryContainer;
    final Color foregroundColor = widget.enableShine
        ? const Color(0xFF6B4F00)
        : theme.colorScheme.onPrimaryContainer;

    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: borderRadius,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    flex: 7,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: foregroundColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          widget.value,
                          maxLines: 1,
                          textAlign: TextAlign.end,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: foregroundColor,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.enableShine)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _shineController,
                  builder: (BuildContext context, Widget? child) {
                    const double shineStart = 0.72;
                    const double shineEnd = 0.98;
                    final double shiftedValue =
                        (_shineController.value - widget.shineDelayFraction) % 1;
                    final double progress =
                        ((shiftedValue - shineStart) / (shineEnd - shineStart))
                            .clamp(0.0, 1.0);
                    final bool isActive =
                        shiftedValue >= shineStart && shiftedValue <= shineEnd;
                    final double left = lerpDouble(-1.25, 1.25, progress)!;
                    return Opacity(
                      opacity: isActive ? 1 : 0,
                      child: FractionalTranslation(
                        translation: Offset(left, 0),
                        child: child,
                      ),
                    );
                  },
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Transform.rotate(
                      angle: -0.22,
                      child: Container(
                        width: 36,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.46),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PeriodSegmentLabel extends StatelessWidget {
  const _PeriodSegmentLabel({required this.text, required this.selected});

  final String text;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SizedBox(
      width: 72,
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned(
            left: -2,
            child: AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: const Duration(milliseconds: 140),
              child: Icon(
                Icons.check_rounded,
                size: 16,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          Center(child: Text(text)),
        ],
      ),
    );
  }
}
