import '../data/racer_master_models.dart';

enum RacerMasterSyncPhase { idle, checking, downloading, ready, error }

class RacerMasterSyncState {
  const RacerMasterSyncState({
    required this.phase,
    required this.hasUsableData,
    required this.activeManifest,
    required this.remoteManifest,
    required this.lastCompletedAt,
    required this.errorMessage,
  });

  const RacerMasterSyncState.initial()
    : phase = RacerMasterSyncPhase.idle,
      hasUsableData = false,
      activeManifest = null,
      remoteManifest = null,
      lastCompletedAt = null,
      errorMessage = null;

  final RacerMasterSyncPhase phase;
  final bool hasUsableData;
  final RacerDatasetManifest? activeManifest;
  final RacerDatasetManifest? remoteManifest;
  final DateTime? lastCompletedAt;
  final String? errorMessage;

  bool get isSyncing =>
      phase == RacerMasterSyncPhase.checking ||
      phase == RacerMasterSyncPhase.downloading;

  bool get canStartQuiz => hasUsableData;

  RacerMasterSyncState copyWith({
    RacerMasterSyncPhase? phase,
    bool? hasUsableData,
    RacerDatasetManifest? activeManifest,
    bool clearActiveManifest = false,
    RacerDatasetManifest? remoteManifest,
    bool clearRemoteManifest = false,
    DateTime? lastCompletedAt,
    bool clearLastCompletedAt = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return RacerMasterSyncState(
      phase: phase ?? this.phase,
      hasUsableData: hasUsableData ?? this.hasUsableData,
      activeManifest: clearActiveManifest
          ? null
          : (activeManifest ?? this.activeManifest),
      remoteManifest: clearRemoteManifest
          ? null
          : (remoteManifest ?? this.remoteManifest),
      lastCompletedAt: clearLastCompletedAt
          ? null
          : (lastCompletedAt ?? this.lastCompletedAt),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}
