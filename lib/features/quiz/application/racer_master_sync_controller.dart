import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/quiz_data_providers.dart';
import '../data/racer_master_models.dart';
import '../data/racer_repository.dart';
import 'racer_master_sync_state.dart';

final NotifierProvider<RacerMasterSyncController, RacerMasterSyncState>
racerMasterSyncControllerProvider =
    NotifierProvider<RacerMasterSyncController, RacerMasterSyncState>(
      RacerMasterSyncController.new,
    );

class RacerMasterSyncController extends Notifier<RacerMasterSyncState> {
  RacerRepository get _repository => ref.read(racerRepositoryProvider);

  @override
  RacerMasterSyncState build() {
    return RacerMasterSyncState(
      phase: _repository.hasUsableData
          ? RacerMasterSyncPhase.ready
          : RacerMasterSyncPhase.idle,
      hasUsableData: _repository.hasUsableData,
      activeManifest: _repository.currentManifest,
      remoteManifest: null,
      lastCompletedAt: null,
      errorMessage: null,
    );
  }

  Future<void> startBackgroundSyncIfNeeded() async {
    if (state.isSyncing) {
      return;
    }
    await _runSync(forceRemoteCheck: true);
  }

  Future<void> retry() async {
    await _runSync(forceRemoteCheck: true);
  }

  Future<void> _runSync({required bool forceRemoteCheck}) async {
    final bool hadUsableData = _repository.hasUsableData;
    state = state.copyWith(
      phase: hadUsableData
          ? RacerMasterSyncPhase.checking
          : RacerMasterSyncPhase.downloading,
      hasUsableData: hadUsableData,
      activeManifest: _repository.currentManifest,
      clearErrorMessage: true,
    );

    try {
      final RacerSyncResult initialization = await _repository.initialize();
      _applyResult(initialization);

      if (!forceRemoteCheck || !initialization.usedLocalSnapshot) {
        return;
      }

      state = state.copyWith(
        phase: RacerMasterSyncPhase.checking,
        clearErrorMessage: true,
      );
      final RacerSyncResult syncResult = await _repository.syncIfNeeded();
      _applyResult(syncResult);
    } catch (error) {
      state = state.copyWith(
        phase: hadUsableData
            ? RacerMasterSyncPhase.ready
            : RacerMasterSyncPhase.error,
        hasUsableData: _repository.hasUsableData,
        activeManifest: _repository.currentManifest,
        errorMessage: _messageFor(error),
      );
    }
  }

  void _applyResult(RacerSyncResult result) {
    final RacerDatasetManifest? activeManifest =
        result.activeManifest ?? _repository.currentManifest;
    state = state.copyWith(
      phase: _repository.hasUsableData
          ? RacerMasterSyncPhase.ready
          : RacerMasterSyncPhase.error,
      hasUsableData: _repository.hasUsableData,
      activeManifest: activeManifest,
      remoteManifest: result.remoteManifest,
      lastCompletedAt: DateTime.now().toUtc(),
      clearErrorMessage: true,
    );
  }

  String _messageFor(Object error) {
    return switch (error) {
      final Exception exception => exception.toString(),
      _ => '選手データの同期に失敗しました。',
    };
  }
}
