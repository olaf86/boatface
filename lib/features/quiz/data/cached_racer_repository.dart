import '../domain/quiz_models.dart';
import 'racer_api_client.dart';
import 'racer_master_local_store.dart';
import 'racer_master_models.dart';
import 'racer_repository.dart';

class CachedRacerRepository implements RacerRepository {
  CachedRacerRepository({
    required RacerMasterRemoteDataSource remoteDataSource,
    required RacerMasterLocalStore localStore,
  }) : _remoteDataSource = remoteDataSource,
       _localStore = localStore;

  static const int _minimumQuizRacerCount = 4;

  final RacerMasterRemoteDataSource _remoteDataSource;
  final RacerMasterLocalStore _localStore;

  RacerDatasetSnapshot? _memorySnapshot;
  Future<RacerSyncResult>? _initializeFuture;
  Future<RacerSyncResult>? _refreshFuture;

  @override
  Future<RacerSyncResult> initialize() {
    if (_hasReadySnapshot()) {
      return Future<RacerSyncResult>.value(
        RacerSyncResult(
          activeManifest: currentManifest,
          remoteManifest: currentManifest,
          downloadedSnapshot: false,
          usedLocalSnapshot: true,
        ),
      );
    }

    final Future<RacerSyncResult>? initializeFuture = _initializeFuture;
    if (initializeFuture != null) {
      return initializeFuture;
    }

    final Future<RacerSyncResult> nextFuture = _initializeImpl();
    _initializeFuture = nextFuture;
    return nextFuture.whenComplete(() {
      if (identical(_initializeFuture, nextFuture)) {
        _initializeFuture = null;
      }
    });
  }

  @override
  List<RacerProfile> requireCachedAll() {
    final RacerDatasetSnapshot? snapshot = _memorySnapshot;
    if (snapshot == null) {
      throw const RacerRepositoryException('選手データがまだ読み込まれていません。');
    }

    final List<RacerProfile> activeRacers = _activeRacers(snapshot.racers);
    if (activeRacers.length < _minimumQuizRacerCount) {
      throw const RacerRepositoryException('クイズ開始に必要な選手データが不足しています。');
    }

    return activeRacers;
  }

  @override
  Future<RacerSyncResult> syncIfNeeded() {
    final Future<RacerSyncResult>? refreshFuture = _refreshFuture;
    if (refreshFuture != null) {
      return refreshFuture;
    }

    final Future<RacerSyncResult> nextFuture = _syncIfNeededImpl();
    _refreshFuture = nextFuture;
    return nextFuture.whenComplete(() {
      if (identical(_refreshFuture, nextFuture)) {
        _refreshFuture = null;
      }
    });
  }

  @override
  RacerDatasetManifest? get currentManifest => _memorySnapshot?.manifest;

  @override
  bool get hasUsableData => _hasReadySnapshot();

  Future<RacerSyncResult> _initializeImpl() async {
    final RacerDatasetSnapshot? localSnapshot = await _localStore
        .readSnapshot();
    if (_isUsable(localSnapshot)) {
      _memorySnapshot = localSnapshot;
      return RacerSyncResult(
        activeManifest: currentManifest,
        remoteManifest: null,
        downloadedSnapshot: false,
        usedLocalSnapshot: true,
      );
    }

    final RacerDatasetSnapshot remoteSnapshot = await _downloadLatestSnapshot();
    return RacerSyncResult(
      activeManifest: remoteSnapshot.manifest,
      remoteManifest: remoteSnapshot.manifest,
      downloadedSnapshot: true,
      usedLocalSnapshot: false,
    );
  }

  bool _hasReadySnapshot() => _isUsable(_memorySnapshot);

  bool _isUsable(RacerDatasetSnapshot? snapshot) {
    if (snapshot == null) {
      return false;
    }
    return _activeRacers(snapshot.racers).length >= _minimumQuizRacerCount;
  }

  List<RacerProfile> _activeRacers(List<RacerProfile> racers) {
    return racers
        .where((RacerProfile racer) => racer.isActive)
        .toList(growable: false);
  }

  Future<RacerSyncResult> _syncIfNeededImpl() async {
    final RacerDatasetManifest remoteManifest = await _remoteDataSource
        .fetchManifest();
    final RacerDatasetManifest? localManifest = _memorySnapshot?.manifest;
    if (localManifest != null && !remoteManifest.shouldReplace(localManifest)) {
      return RacerSyncResult(
        activeManifest: localManifest,
        remoteManifest: remoteManifest,
        downloadedSnapshot: false,
        usedLocalSnapshot: true,
      );
    }

    final RacerDatasetSnapshot remoteSnapshot = await _remoteDataSource
        .fetchSnapshot(datasetId: remoteManifest.datasetId);
    _applySnapshot(remoteSnapshot);
    await _localStore.writeSnapshot(remoteSnapshot);
    return RacerSyncResult(
      activeManifest: remoteSnapshot.manifest,
      remoteManifest: remoteSnapshot.manifest,
      downloadedSnapshot: true,
      usedLocalSnapshot: false,
    );
  }

  Future<RacerDatasetSnapshot> _downloadLatestSnapshot() async {
    final RacerDatasetManifest remoteManifest = await _remoteDataSource
        .fetchManifest();
    final RacerDatasetSnapshot remoteSnapshot = await _remoteDataSource
        .fetchSnapshot(datasetId: remoteManifest.datasetId);
    _applySnapshot(remoteSnapshot);
    await _localStore.writeSnapshot(remoteSnapshot);
    return remoteSnapshot;
  }

  void _applySnapshot(RacerDatasetSnapshot snapshot) {
    final List<RacerProfile> activeRacers = _activeRacers(snapshot.racers);
    if (activeRacers.length < _minimumQuizRacerCount) {
      throw const RacerRepositoryException('クイズ開始に必要な選手データが不足しています。');
    }
    _memorySnapshot = RacerDatasetSnapshot(
      manifest: snapshot.manifest,
      racers: snapshot.racers.toList(growable: false),
    );
  }
}
