import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/format/date_time_formatters.dart';
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
              period: _period,
              questionCount: mode.questionCount,
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
                            const SizedBox(height: 4),
                            Text(
                              rankingAsync.valueOrNull == null
                                  ? 'ランキングを読み込み中です。'
                                  : '更新 ${formatDateTimeYmdHm(rankingAsync.valueOrNull!.generatedAt)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
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
    final Color scoreColor = isCurrentUser
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.primary;

    return ColoredBox(
      color: isCurrentUser
          ? theme.colorScheme.primaryContainer
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
  const _CurrentUserCard({
    required this.summaryAsync,
    required this.period,
    required this.questionCount,
  });

  final AsyncValue<RankingCurrentUserSummary> summaryAsync;
  final RankingPeriod period;
  final int questionCount;

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
                Text('あなたの成績', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '当期ベストスコア',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          summary.termBestScore.bestScore?.toString() ?? '---',
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          summary.termBestScore.bestScore == null
                              ? 'このモードの記録はまだありません。'
                              : '$questionCount問モードで出した今期の自己ベストです。',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('現在の順位', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(
                  currentUserEntry == null
                      ? 'ランキング圏外'
                      : '${currentUserEntry.rank}位 / Score ${currentUserEntry.score}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentUserEntry == null
                      ? '${period.label}のトップ50圏外の場合はここに表示されません。'
                      : '${period.label}での総回答時間 ${_formatSeconds(currentUserEntry.totalAnswerTimeMs)}',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    Chip(
                      label: Text(period.label),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      label: Text('$questionCount問モード'),
                      visualDensity: VisualDensity.compact,
                    ),
                    if (currentUserEntry?.region != null)
                      Chip(
                        label: Text(currentUserEntry!.region!.label),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            );
          },
          loading: () => const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object error, StackTrace stackTrace) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('あなたの成績', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
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
