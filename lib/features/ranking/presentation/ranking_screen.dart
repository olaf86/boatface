import 'package:flutter/material.dart';

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
    final List<_RankRow> rows = List<_RankRow>.generate(
      20,
      (int i) => _RankRow(
        rank: i + 1,
        name: i == 0 ? 'あなた' : 'user_${(i + 11).toString()}',
        score: 50 - i,
        totalTimeMs: (9000 + i * 321),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('ランキング（モック）')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                DropdownButton<String>(
                  value: _modeId,
                  items: kQuizModes
                      .where((mode) => mode.availableInMvp)
                      .map(
                        (mode) => DropdownMenuItem<String>(
                          value: mode.id,
                          child: Text(mode.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (String? value) {
                    if (value == null) return;
                    setState(() {
                      _modeId = value;
                    });
                  },
                ),
                SegmentedButton<String>(
                  segments: const <ButtonSegment<String>>[
                    ButtonSegment<String>(value: 'today', label: Text('本日')),
                    ButtonSegment<String>(value: 'term', label: Text('期別')),
                  ],
                  selected: <String>{_period},
                  onSelectionChanged: (Set<String> value) {
                    setState(() {
                      _period = value.first;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('集計境界: 本日 00:00 JST / 期別 1月1日・7月1日'),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const Divider(height: 1),
                itemBuilder: (BuildContext context, int i) {
                  final _RankRow row = rows[i];
                  return ListTile(
                    leading: Text('${row.rank}位'),
                    title: Text(row.name),
                    subtitle: Text(
                      '総回答時間: ${(row.totalTimeMs / 1000).toStringAsFixed(1)}秒',
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
  }
}

class _RankRow {
  const _RankRow({
    required this.rank,
    required this.name,
    required this.score,
    required this.totalTimeMs,
  });

  final int rank;
  final String name;
  final int score;
  final int totalTimeMs;
}
