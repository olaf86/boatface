import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation/app_route.dart';
import '../../../shared/format/date_time_formatters.dart';
import '../application/racer_master_sync_controller.dart';
import '../application/racer_master_sync_state.dart';
import '../domain/quiz_models.dart';
import 'quiz_screen.dart';

class QuizRuleScreen extends ConsumerStatefulWidget {
  const QuizRuleScreen({required this.baseMode, super.key});

  final QuizModeConfig baseMode;

  @override
  ConsumerState<QuizRuleScreen> createState() => _QuizRuleScreenState();
}

class _QuizRuleScreenState extends ConsumerState<QuizRuleScreen> {
  late final bool _isCustomMode;
  late final Map<QuizPromptType, int> _editableCounts;
  late bool _unlimitedTime;
  late int _timeLimitSeconds;
  bool _isStarting = false;
  String? _startErrorMessage;

  @override
  void initState() {
    super.initState();
    _isCustomMode = widget.baseMode.id == 'custom';
    _editableCounts = <QuizPromptType, int>{
      for (final QuizPromptType type in QuizPromptType.values) type: 0,
    };
    for (final QuizSegment segment in widget.baseMode.segments) {
      _editableCounts[segment.promptType] = segment.count;
    }
    _unlimitedTime = widget.baseMode.timeLimitSeconds == null;
    _timeLimitSeconds = widget.baseMode.timeLimitSeconds ?? 10;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(racerMasterSyncControllerProvider.notifier)
          .startBackgroundSyncIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final int totalQuestions = _totalQuestionCount();
    final RacerMasterSyncState syncState = ref.watch(
      racerMasterSyncControllerProvider,
    );
    final bool canStartQuiz =
        totalQuestions > 0 && syncState.canStartQuiz && !_isStarting;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.baseMode.label} ルール')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(widget.baseMode.description),
          const SizedBox(height: 12),
          _SectionCard(
            title: '基本設定',
            children: <Widget>[
              _ReadOnlyItem(label: 'モード', value: widget.baseMode.label),
              _ReadOnlyItem(label: '問題数', value: '$totalQuestions 問'),
              _RuleItem(
                label: '時間制限',
                readOnly: !_isCustomMode,
                valueText: _unlimitedTime ? '無制限' : '$_timeLimitSeconds 秒',
                editor: _isCustomMode
                    ? Row(
                        children: <Widget>[
                          Expanded(
                            child: SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('無制限'),
                              value: _unlimitedTime,
                              onChanged: (bool value) {
                                setState(() {
                                  _unlimitedTime = value;
                                });
                              },
                            ),
                          ),
                          if (!_unlimitedTime)
                            SizedBox(
                              width: 140,
                              child: DropdownButtonFormField<int>(
                                initialValue: _timeLimitSeconds,
                                decoration: const InputDecoration(
                                  labelText: '秒数',
                                  isDense: true,
                                ),
                                items: <int>[5, 10, 15, 20, 30]
                                    .map(
                                      (int second) => DropdownMenuItem<int>(
                                        value: second,
                                        child: Text('$second 秒'),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: (int? value) {
                                  if (value == null) return;
                                  setState(() {
                                    _timeLimitSeconds = value;
                                  });
                                },
                              ),
                            ),
                        ],
                      )
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '出題形式',
            children: <Widget>[
              for (final QuizPromptType type in QuizPromptType.values)
                _RuleItem(
                  label: promptTypeLabel(type),
                  readOnly: !_isCustomMode,
                  valueText: '${_editableCounts[type] ?? 0} 問',
                  editor: _isCustomMode
                      ? _CountEditor(
                          value: _editableCounts[type] ?? 0,
                          onChanged: (int next) {
                            setState(() {
                              _editableCounts[type] = next;
                            });
                          },
                        )
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: canStartQuiz ? () => _startQuizFlow(context) : null,
            child: _isStarting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('スタート'),
          ),
          if (_isStarting)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('選手データを読み込んでいます…'),
            ),
          if (!_isStarting) _SyncStatusPanel(syncState: syncState),
          if (_startErrorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _startErrorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_isCustomMode && totalQuestions == 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '問題数を1問以上に設定してください。',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }

  int _totalQuestionCount() {
    return _editableCounts.values.fold<int>(
      0,
      (int sum, int count) => sum + count,
    );
  }

  Future<void> _startQuizFlow(BuildContext context) async {
    final QuizModeConfig resolvedMode = _resolveMode();
    setState(() {
      _isStarting = true;
      _startErrorMessage = null;
    });

    try {
      await ref.read(racerMasterSyncControllerProvider.notifier).retry();
    } catch (error) {
      if (!mounted) {
        return;
      }
      final String message = switch (error) {
        final Exception exception => exception.toString(),
        _ => '選手データの読み込みに失敗しました。しばらくしてから再試行してください。',
      };
      setState(() {
        _isStarting = false;
        _startErrorMessage = message;
      });
      return;
    }

    final RacerMasterSyncState syncState = ref.read(
      racerMasterSyncControllerProvider,
    );
    if (!syncState.canStartQuiz) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isStarting = false;
        _startErrorMessage = syncState.errorMessage ?? '選手データの準備完了後にスタートできます。';
      });
      return;
    }

    if (!context.mounted) {
      return;
    }
    setState(() {
      _isStarting = false;
    });
    await Navigator.of(context).push<void>(
      buildAppRoute(
        page: QuizScreen(mode: resolvedMode, showIntroCountdown: true),
        transition: AppRouteTransition.sharedAxisHorizontal,
      ),
    );
  }

  QuizModeConfig _resolveMode() {
    if (!_isCustomMode) {
      return widget.baseMode;
    }

    final List<QuizSegment> segments = QuizPromptType.values
        .map(
          (QuizPromptType type) =>
              QuizSegment(promptType: type, count: _editableCounts[type] ?? 0),
        )
        .where((QuizSegment segment) => segment.count > 0)
        .toList(growable: false);

    return widget.baseMode.copyWith(
      description: 'カスタム設定',
      clearTimeLimit: _unlimitedTime,
      timeLimitSeconds: _unlimitedTime ? null : _timeLimitSeconds,
      segments: segments,
    );
  }
}

class _SyncStatusPanel extends ConsumerWidget {
  const _SyncStatusPanel({required this.syncState});

  final RacerMasterSyncState syncState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final bool showRetry = !syncState.canStartQuiz && !syncState.isSyncing;
    final String message = switch (syncState.phase) {
      RacerMasterSyncPhase.idle =>
        syncState.canStartQuiz ? '選手データは準備済みです。' : '選手データの同期待ちです。',
      RacerMasterSyncPhase.checking =>
        syncState.canStartQuiz
            ? 'バックグラウンドで最新データを確認しています。'
            : '選手データの更新状況を確認しています。',
      RacerMasterSyncPhase.downloading =>
        syncState.canStartQuiz
            ? '新しい選手データへ更新しています。'
            : '選手データをダウンロードしています。完了するとスタートできます。',
      RacerMasterSyncPhase.ready => '選手データは準備済みです。',
      RacerMasterSyncPhase.error =>
        syncState.canStartQuiz
            ? '最新確認に失敗したため、保存済みデータを利用します。'
            : (syncState.errorMessage ?? '選手データの同期に失敗しました。'),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('データ状態', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(message),
              if (syncState.activeManifest != null) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  '使用中: ${syncState.activeManifest!.datasetId} '
                  '(${formatDateTimeYmdHm(syncState.activeManifest!.datasetUpdatedAt)})',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              if (showRetry) ...<Widget>[
                const SizedBox(height: 10),
                FilledButton.tonal(
                  onPressed: () => ref
                      .read(racerMasterSyncControllerProvider.notifier)
                      .retry(),
                  child: const Text('同期を再試行'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyItem extends StatelessWidget {
  const _ReadOnlyItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  const _RuleItem({
    required this.label,
    required this.readOnly,
    required this.valueText,
    this.editor,
  });

  final String label;
  final bool readOnly;
  final String valueText;
  final Widget? editor;

  @override
  Widget build(BuildContext context) {
    if (readOnly || editor == null) {
      return _ReadOnlyItem(label: label, value: valueText);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[Text(label), const SizedBox(height: 8), editor!],
      ),
    );
  }
}

class _CountEditor extends StatelessWidget {
  const _CountEditor({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 56,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          onPressed: value < 200 ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
