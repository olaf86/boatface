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
    final String? currentUserId = ref.watch(authStateProvider).valueOrNull?.uid;
    final QuizModeConfig mode = kQuizModes.firstWhere(
      (QuizModeConfig item) => item.id == _modeId,
    );
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('ランキング')),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool twoColumn = constraints.maxWidth >= 900;
          final Widget filters = ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('表示条件', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _modeId,
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
                      const SizedBox(height: 12),
                      SegmentedButton<RankingPeriod>(
                        segments: const <ButtonSegment<RankingPeriod>>[
                          ButtonSegment<RankingPeriod>(
                            value: RankingPeriod.today,
                            label: Text('本日'),
                          ),
                          ButtonSegment<RankingPeriod>(
                            value: RankingPeriod.term,
                            label: Text('期別'),
                          ),
                        ],
                        selected: <RankingPeriod>{_period},
                        onSelectionChanged: (Set<RankingPeriod> value) {
                          setState(() {
                            _period = value.first;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(mode.description),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _CurrentUserCard(
                rankingAsync: rankingAsync,
                currentUserId: currentUserId,
                period: _period,
                questionCount: mode.questionCount,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const <Widget>[
                      Text('集計メモ'),
                      SizedBox(height: 8),
                      Text('本日ランキングは JST 00:00 区切りです。'),
                      SizedBox(height: 4),
                      Text('期別ランキングは 1月1日 / 7月1日 開始です。'),
                      SizedBox(height: 4),
                      Text('表示名と地域は設定画面のプロフィール設定を使います。'),
                    ],
                  ),
                ),
              ),
            ],
          );

          final Widget leaderboard = Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                                    : '更新日時: ${formatDateTimeYmdHm(rankingAsync.valueOrNull!.generatedAt)}',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '再読み込み',
                          onPressed: () =>
                              ref.invalidate(rankingSnapshotProvider(request)),
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
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
                          itemCount: snapshot.entries.length,
                          separatorBuilder: (BuildContext context, int index) =>
                              const Divider(height: 1),
                          itemBuilder: (BuildContext context, int index) {
                            final RankingEntry entry = snapshot.entries[index];
                            final bool isCurrentUser =
                                currentUserId != null &&
                                currentUserId == entry.userId;
                            return ListTile(
                              tileColor: isCurrentUser
                                  ? theme.colorScheme.primaryContainer
                                  : null,
                              leading: CircleAvatar(
                                child: Text('${entry.rank}'),
                              ),
                              title: Text(entry.displayName),
                              subtitle: Text(
                                [
                                  if (entry.region != null) entry.region!.label,
                                  '総回答時間: ${_formatSeconds(entry.totalAnswerTimeMs)}',
                                ].join(' ・ '),
                              ),
                              trailing: Text('Score ${entry.score}'),
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
                ],
              ),
            ),
          );

          if (!twoColumn) {
            return Column(
              children: <Widget>[
                SizedBox(height: 320, child: filters),
                Expanded(child: leaderboard),
              ],
            );
          }

          return Row(
            children: <Widget>[
              SizedBox(width: 320, child: filters),
              VerticalDivider(
                width: 1,
                color: theme.colorScheme.outlineVariant,
              ),
              Expanded(child: leaderboard),
            ],
          );
        },
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

class _CurrentUserCard extends StatelessWidget {
  const _CurrentUserCard({
    required this.rankingAsync,
    required this.currentUserId,
    required this.period,
    required this.questionCount,
  });

  final AsyncValue<RankingSnapshot> rankingAsync;
  final String? currentUserId;
  final RankingPeriod period;
  final int questionCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: rankingAsync.when(
          data: (RankingSnapshot snapshot) {
            RankingEntry? currentUserEntry;
            if (currentUserId != null) {
              for (final RankingEntry entry in snapshot.entries) {
                if (entry.userId == currentUserId) {
                  currentUserEntry = entry;
                  break;
                }
              }
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('あなたの現在位置', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  currentUserEntry == null
                      ? 'ランキング圏外'
                      : '${currentUserEntry.rank}位 / Score ${currentUserEntry.score}',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  currentUserEntry == null
                      ? 'トップ50圏外の場合はここに表示されません。'
                      : '総回答時間 ${_formatSeconds(currentUserEntry.totalAnswerTimeMs)}',
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
            height: 110,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object error, StackTrace stackTrace) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('あなたの現在位置', style: theme.textTheme.titleMedium),
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
