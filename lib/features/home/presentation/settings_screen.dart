import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/format/date_time_formatters.dart';
import '../../auth/application/auth_controller.dart';
import '../../profile/application/user_profile_controller.dart';
import '../../profile/domain/user_profile.dart';
import '../../quiz/application/racer_master_sync_controller.dart';
import '../../quiz/application/racer_master_sync_state.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _nicknameController = TextEditingController();

  String? _selectedRegionCode;
  bool _didHydrateProfile = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<UserProfile?>>(userProfileControllerProvider, (
      AsyncValue<UserProfile?>? previous,
      AsyncValue<UserProfile?> next,
    ) {
      if (!mounted || previous?.isLoading != true) {
        return;
      }

      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      next.whenOrNull(
        data: (UserProfile? profile) {
          if (profile == null) {
            return;
          }
          messenger.showSnackBar(
            const SnackBar(content: Text('プロフィールを更新しました。')),
          );
        },
        error: (Object error, StackTrace stackTrace) {
          messenger.showSnackBar(
            SnackBar(content: Text(_messageForError(error))),
          );
        },
      );
    });

    final authState = ref.watch(authStateProvider).valueOrNull;
    final AsyncValue<UserProfile> profileAsync = ref.watch(userProfileProvider);
    final AsyncValue<UserProfile?> saveState = ref.watch(
      userProfileControllerProvider,
    );
    final RacerMasterSyncState syncState = ref.watch(
      racerMasterSyncControllerProvider,
    );

    profileAsync.whenData(_hydrateProfileFormIfNeeded);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildProfileCard(
            context,
            ref,
            profileAsync: profileAsync,
            isSaving: saveState.isLoading,
          ),
          const SizedBox(height: 12),
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
                  _InfoRow(
                    label: '認証表示名',
                    value: profileAsync.valueOrNull?.displayName ?? '-',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
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
                              style: FilledButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.onError,
                              ),
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
                  const SizedBox(height: 8),
                  _SyncDetailsAccordion(syncState: syncState),
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

  Widget _buildProfileCard(
    BuildContext context,
    WidgetRef ref, {
    required AsyncValue<UserProfile> profileAsync,
    required bool isSaving,
  }) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: profileAsync.when(
          data: (UserProfile profile) {
            final String rankingDisplayName = _rankingPreviewName(
              fallbackDisplayName: profile.displayName,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('ランキングプロフィール', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'ランキングに表示するニックネームと地域を設定します。',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nicknameController,
                  maxLength: 12,
                  decoration: const InputDecoration(
                    labelText: 'ニックネーム',
                    hintText: '未入力なら認証表示名を使います',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  key: ValueKey<String?>(_selectedRegionCode),
                  initialValue: _selectedRegionCode,
                  decoration: const InputDecoration(
                    labelText: '地域',
                    hintText: '未設定',
                  ),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('未設定'),
                    ),
                    ...kUserRegionOptions.map(
                      (UserRegion region) => DropdownMenuItem<String?>(
                        value: region.code,
                        child: Text(region.label),
                      ),
                    ),
                  ],
                  onChanged: (String? value) {
                    setState(() {
                      _selectedRegionCode = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('ランキング表示プレビュー', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 10),
                      _InfoRow(label: '表示名', value: rankingDisplayName),
                      _InfoRow(
                        label: '地域',
                        value: _selectedRegion?.label ?? '未設定',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    FilledButton(
                      onPressed: isSaving ? null : () => _saveProfile(ref),
                      child: Text(isSaving ? '保存中…' : '保存'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: isSaving ? null : () => _reloadProfile(ref),
                      child: const Text('再読み込み'),
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
                Text('ランキングプロフィール', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  _messageForError(error),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => _reloadProfile(ref),
                  child: const Text('再試行'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _hydrateProfileFormIfNeeded(UserProfile profile) {
    if (_didHydrateProfile) {
      return;
    }

    _didHydrateProfile = true;
    _nicknameController.text = profile.nickname ?? '';
    _selectedRegionCode = profile.region?.code;
  }

  Future<void> _saveProfile(WidgetRef ref) async {
    try {
      await ref
          .read(userProfileControllerProvider.notifier)
          .saveProfile(
            nickname: _nicknameController.text,
            region: _selectedRegion,
          );
    } catch (_) {
      // Error feedback is shown via ref.listen.
    }
  }

  void _reloadProfile(WidgetRef ref) {
    setState(() {
      _didHydrateProfile = false;
    });
    ref.invalidate(userProfileProvider);
  }

  UserRegion? get _selectedRegion {
    for (final UserRegion region in kUserRegionOptions) {
      if (region.code == _selectedRegionCode) {
        return region;
      }
    }
    return null;
  }

  String _rankingPreviewName({required String fallbackDisplayName}) {
    final String nickname = _nicknameController.text.trim();
    if (nickname.isNotEmpty) {
      return nickname;
    }
    return fallbackDisplayName;
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

  String _messageForError(Object error) {
    return switch (error) {
      final Exception exception => exception.toString(),
      _ => 'プロフィールの読み込みに失敗しました。',
    };
  }
}

class _SyncDetailsAccordion extends StatelessWidget {
  const _SyncDetailsAccordion({required this.syncState});

  final RacerMasterSyncState syncState;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: const Text('同期詳細を見る'),
      shape: const Border(),
      collapsedShape: const Border(),
      children: <Widget>[
        _InfoRow(
          label: '使用中データセット',
          value: syncState.activeManifest?.datasetId ?? '未取得',
        ),
        _InfoRow(
          label: '使用中データセット更新日時',
          value: syncState.activeManifest == null
              ? '-'
              : formatDateTimeYmdHm(syncState.activeManifest!.datasetUpdatedAt),
        ),
        _InfoRow(
          label: '最新確認データセット',
          value: syncState.remoteManifest?.datasetId ?? '-',
        ),
        _InfoRow(
          label: '最新確認更新日時',
          value: syncState.remoteManifest == null
              ? '-'
              : formatDateTimeYmdHm(syncState.remoteManifest!.datasetUpdatedAt),
        ),
        _InfoRow(
          label: '最終同期完了',
          value: syncState.lastCompletedAt == null
              ? '-'
              : formatDateTimeYmdHm(syncState.lastCompletedAt!),
        ),
        if (syncState.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              syncState.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
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
