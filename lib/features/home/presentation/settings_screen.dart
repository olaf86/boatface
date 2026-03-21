import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../quiz/application/racer_master_sync_controller.dart';
import '../../quiz/application/racer_master_sync_state.dart';
import '../../../shared/format/date_time_formatters.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider).valueOrNull;
    final RacerMasterSyncState syncState = ref.watch(
      racerMasterSyncControllerProvider,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('アカウント', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: 'ログイン方法',
                    value: authState?.providerLabel ?? '未ログイン',
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () async {
                      final bool? confirmed = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext context) => AlertDialog(
                          title: const Text('ログアウト確認'),
                          content: const Text('ログアウトしますか？'),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('キャンセル'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('ログアウト'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        await ref
                            .read(authControllerProvider.notifier)
                            .signOut();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      }
                    },
                    child: const Text('ログアウト'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('クイズデータ', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _InfoRow(label: '同期状態', value: _statusLabel(syncState)),
                  _InfoRow(
                    label: '使用中 dataset',
                    value: syncState.activeManifest?.datasetId ?? '未取得',
                  ),
                  _InfoRow(
                    label: '使用中 dataset 更新日時',
                    value: syncState.activeManifest == null
                        ? '-'
                        : formatDateTimeYmdHm(
                            syncState.activeManifest!.datasetUpdatedAt,
                          ),
                  ),
                  _InfoRow(
                    label: '最新確認 dataset',
                    value: syncState.remoteManifest?.datasetId ?? '-',
                  ),
                  _InfoRow(
                    label: '最新確認 更新日時',
                    value: syncState.remoteManifest == null
                        ? '-'
                        : formatDateTimeYmdHm(
                            syncState.remoteManifest!.datasetUpdatedAt,
                          ),
                  ),
                  _InfoRow(
                    label: '最終同期完了',
                    value: syncState.lastCompletedAt == null
                        ? '-'
                        : formatDateTimeYmdHm(syncState.lastCompletedAt!),
                  ),
                  if (syncState.errorMessage != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      syncState.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: syncState.isSyncing
                        ? null
                        : () => ref
                              .read(racerMasterSyncControllerProvider.notifier)
                              .retry(),
                    child: Text(syncState.isSyncing ? '同期中…' : 'データ更新を確認'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(RacerMasterSyncState state) {
    switch (state.phase) {
      case RacerMasterSyncPhase.idle:
        return state.hasUsableData ? '準備完了' : '未同期';
      case RacerMasterSyncPhase.checking:
        return '更新確認中';
      case RacerMasterSyncPhase.downloading:
        return state.hasUsableData ? '更新中' : '初回同期中';
      case RacerMasterSyncPhase.ready:
        return '準備完了';
      case RacerMasterSyncPhase.error:
        return state.hasUsableData ? 'ローカルデータで利用中' : '同期失敗';
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 132, child: Text(label)),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}
