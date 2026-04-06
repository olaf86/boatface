import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/environment/app_environment.dart';
import '../../../shared/format/date_time_formatters.dart';
import '../../../shared/privacy/ad_privacy_consent_controller.dart';
import '../../../shared/privacy/ad_privacy_consent_service.dart';
import '../../../shared/privacy/privacy_preferences_controller.dart';
import '../../../shared/privacy/tracking_transparency_controller.dart';
import '../../../shared/privacy/tracking_transparency_service.dart';
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
    final AsyncValue<AdPrivacyConsentInfo> adPrivacyAsync = ref.watch(
      adPrivacyConsentControllerProvider,
    );
    final AsyncValue<TrackingTransparencyInfo> trackingAsync = ref.watch(
      trackingTransparencyControllerProvider,
    );
    final AppEnvironment appEnvironment = ref.watch(appEnvironmentProvider);
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
          _buildTrackingTransparencyCard(
            context,
            ref,
            appEnvironment: appEnvironment,
            adPrivacyAsync: adPrivacyAsync,
            trackingAsync: trackingAsync,
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

  Widget _buildTrackingTransparencyCard(
    BuildContext context,
    WidgetRef ref, {
    required AppEnvironment appEnvironment,
    required AsyncValue<AdPrivacyConsentInfo> adPrivacyAsync,
    required AsyncValue<TrackingTransparencyInfo> trackingAsync,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool isBusy = trackingAsync.isLoading || adPrivacyAsync.isLoading;
    final AdPrivacyConsentInfo? adPrivacyInfo = adPrivacyAsync.valueOrNull;
    final TrackingTransparencyInfo? trackingInfo = trackingAsync.valueOrNull;

    if (adPrivacyAsync.hasError) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('広告とプライバシー', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                '広告の同意状態の取得に失敗しました。',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 8),
              Text(
                adPrivacyAsync.error.toString(),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => _reloadPrivacyState(ref),
                child: const Text('再試行'),
              ),
            ],
          ),
        ),
      );
    }
    if (trackingAsync.hasError) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('広告とプライバシー', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'トラッキング許可の状態取得に失敗しました。',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 8),
              Text(
                trackingAsync.error.toString(),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => _reloadPrivacyState(ref),
                child: const Text('再試行'),
              ),
            ],
          ),
        ),
      );
    }
    if (adPrivacyInfo == null || trackingInfo == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('広告とプライバシー', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('広告とプライバシー', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              appEnvironment.isProduction
                  ? '広告の利用同意やトラッキング許可の状態を確認できます。必要に応じて、広告の設定や設定アプリから見直せます。'
                  : '広告の利用同意やトラッキング許可の状態を確認できます。iPhone 実機では IDFA の確認もできます。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _InfoRow(label: '広告の同意', value: adPrivacyInfo.consentStatusLabel),
            _InfoRow(
              label: '広告設定の見直し',
              value: adPrivacyInfo.privacyOptionsStatusLabel,
            ),
            _InfoRow(
              label: '広告を表示できる状態',
              value: adPrivacyInfo.canRequestAds ? '可能' : '未許可',
            ),
            _InfoRow(label: 'トラッキング許可', value: trackingInfo.statusLabel),
            if (appEnvironment.isStaging) _IdfaRow(idfa: trackingInfo.idfa),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                FilledButton(
                  onPressed: isBusy
                      ? null
                      : trackingInfo.canRequestAuthorization
                      ? () => _requestTrackingTransparency(ref)
                      : null,
                  child: Text(
                    trackingInfo.canRequestAuthorization
                        ? 'トラッキング許可を確認'
                        : '確認済み',
                  ),
                ),
                OutlinedButton(
                  onPressed: isBusy ? null : () => _reloadPrivacyState(ref),
                  child: const Text('状態を更新'),
                ),
                if (adPrivacyInfo.privacyOptionsRequired)
                  OutlinedButton(
                    onPressed: isBusy ? null : () => _showPrivacyOptions(ref),
                    child: const Text('広告の設定を見直す'),
                  ),
                if (appEnvironment.isStaging && trackingInfo.hasIdfa)
                  OutlinedButton(
                    onPressed: isBusy
                        ? null
                        : () => _copyIdfa(trackingInfo.idfa!),
                    child: const Text('IDFA をコピー'),
                  ),
                if (trackingInfo.canOpenSettings)
                  OutlinedButton(
                    onPressed: isBusy ? null : () => _openTrackingSettings(ref),
                    child: const Text('設定を開く'),
                  ),
              ],
            ),
          ],
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

  Future<void> _reloadPrivacyState(WidgetRef ref) async {
    try {
      await ref
          .read(privacyPreferencesControllerProvider)
          .refreshPrivacyState();
    } catch (_) {
      // Error state is reflected by the provider.
    }
  }

  Future<void> _requestTrackingTransparency(WidgetRef ref) async {
    try {
      final TrackingTransparencyInfo info = await ref
          .read(privacyPreferencesControllerProvider)
          .requestTrackingAuthorization();
      if (!mounted) {
        return;
      }
      final String message = switch (info.status) {
        TrackingTransparencyStatus.authorized when info.hasIdfa =>
          'トラッキングを許可しました。IDFA を確認できます。',
        TrackingTransparencyStatus.authorized => 'トラッキングを許可しました。',
        TrackingTransparencyStatus.denied => 'トラッキングは未許可です。必要なら設定アプリから変更できます。',
        TrackingTransparencyStatus.restricted => 'この端末ではトラッキング設定が制限されています。',
        TrackingTransparencyStatus.notSupported => 'この端末では ATT を利用できません。',
        TrackingTransparencyStatus.notDetermined => 'トラッキング設定はまだ未確認です。',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      // Error state is reflected by the provider.
    }
  }

  Future<void> _openTrackingSettings(WidgetRef ref) async {
    await ref.read(privacyPreferencesControllerProvider).openTrackingSettings();
  }

  Future<void> _showPrivacyOptions(WidgetRef ref) async {
    try {
      final AdPrivacyConsentInfo info = await ref
          .read(privacyPreferencesControllerProvider)
          .showPrivacyOptions();
      if (!mounted) {
        return;
      }
      final String message = info.lastFormErrorMessage == null
          ? 'プライバシー設定を更新しました。'
          : info.lastFormErrorMessage!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      // Error state is reflected by the provider.
    }
  }

  Future<void> _copyIdfa(String idfa) async {
    await Clipboard.setData(ClipboardData(text: idfa));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('IDFA をコピーしました。')));
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

class _IdfaRow extends StatelessWidget {
  const _IdfaRow({required this.idfa});

  final String? idfa;

  @override
  Widget build(BuildContext context) {
    final String displayValue = idfa ?? '未取得';
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(width: 132, child: Text('IDFA')),
          Expanded(
            child: SelectableText(
              displayValue,
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
