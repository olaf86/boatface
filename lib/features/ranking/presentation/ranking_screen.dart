import 'package:flutter/material.dart';

import '../../quiz/domain/quiz_models.dart';
import '../../quiz/domain/quiz_modes.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  String _modeId = 'quick';
  String _period = 'today';

  @override
  Widget build(BuildContext context) {
    final QuizModeConfig mode = kQuizModes.firstWhere(
      (QuizModeConfig item) => item.id == _modeId,
    );
    final List<_RankRow> rows = _buildRows(mode: mode, period: _period);
    final ThemeData theme = Theme.of(context);
    final _RankRow currentUser = rows.firstWhere(
      (_RankRow row) => row.isCurrentUser,
      orElse: () => rows.first,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('ランキング（モック）')),
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
                      SegmentedButton<String>(
                        segments: const <ButtonSegment<String>>[
                          ButtonSegment<String>(
                            value: 'today',
                            label: Text('本日'),
                          ),
                          ButtonSegment<String>(
                            value: 'term',
                            label: Text('期別'),
                          ),
                        ],
                        selected: <String>{_period},
                        onSelectionChanged: (Set<String> value) {
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('あなたの現在位置', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        '${currentUser.rank}位 / Score ${currentUser.score}',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text('総回答時間 ${_formatSeconds(currentUser.totalTimeMs)}'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          Chip(
                            label: Text(
                              _period == 'today' ? '本日ランキング' : '期別ランキング',
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            label: Text('${mode.questionCount}問モード'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
                      Text('現在は API 接続前のモック表示です。'),
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
                    child: Text(
                      '${mode.label} / ${_periodLabel(_period)}',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (BuildContext context, int index) =>
                          const Divider(height: 1),
                      itemBuilder: (BuildContext context, int i) {
                        final _RankRow row = rows[i];
                        final Color? tileColor = row.isCurrentUser
                            ? theme.colorScheme.primaryContainer
                            : null;
                        return ListTile(
                          tileColor: tileColor,
                          leading: CircleAvatar(child: Text('${row.rank}')),
                          title: Text(row.name),
                          subtitle: Text(
                            '総回答時間: ${_formatSeconds(row.totalTimeMs)}',
                          ),
                          trailing: Text('Score ${row.score}'),
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

  List<_RankRow> _buildRows({
    required QuizModeConfig mode,
    required String period,
  }) {
    final int baseScore = switch (mode.id) {
      'quick' => 10,
      'careful' => 30,
      'challenge' => 50,
      _ => 20,
    };
    final int periodOffset = period == 'today' ? 0 : 2;
    final int userRank = switch (mode.id) {
      'quick' => period == 'today' ? 2 : 4,
      'careful' => period == 'today' ? 5 : 3,
      'challenge' => period == 'today' ? 8 : 6,
      _ => 10,
    };

    return List<_RankRow>.generate(20, (int i) {
      final bool isCurrentUser = i + 1 == userRank;
      final int score = (baseScore - (i ~/ 2) - periodOffset).clamp(1, 999);
      return _RankRow(
        rank: i + 1,
        name: isCurrentUser ? 'あなた' : 'user_${mode.id}_${i + 11}',
        score: score,
        totalTimeMs: 8200 + (i * 287) + (period == 'term' ? 450 : 0),
        isCurrentUser: isCurrentUser,
      );
    });
  }

  String _formatSeconds(int totalTimeMs) {
    return '${(totalTimeMs / 1000).toStringAsFixed(1)}秒';
  }

  String _periodLabel(String period) {
    return period == 'today' ? '本日ランキング' : '期別ランキング';
  }
}

class _RankRow {
  const _RankRow({
    required this.rank,
    required this.name,
    required this.score,
    required this.totalTimeMs,
    required this.isCurrentUser,
  });

  final int rank;
  final String name;
  final int score;
  final int totalTimeMs;
  final bool isCurrentUser;
}
