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
  Future<void>? _initializeFuture;
  Future<void>? _refreshFuture;

  @override
  Future<void> initialize() {
    if (_hasReadySnapshot()) {
      _scheduleBackgroundRefresh();
      return Future<void>.value();
    }

    final Future<void>? initializeFuture = _initializeFuture;
    if (initializeFuture != null) {
      return initializeFuture;
    }

    final Future<void> nextFuture = _initializeImpl();
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

  Future<void> _initializeImpl() async {
    final RacerDatasetSnapshot? localSnapshot = await _localStore
        .readSnapshot();
    if (_isUsable(localSnapshot)) {
      _memorySnapshot = localSnapshot;
      _scheduleBackgroundRefresh();
      return;
    }

    await _downloadLatestSnapshot();
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

  void _scheduleBackgroundRefresh() {
    _refreshFuture ??= _refreshIfNeeded()
        .catchError((_) {
          return;
        })
        .whenComplete(() {
          _refreshFuture = null;
        });
  }

  Future<void> _refreshIfNeeded() async {
    final RacerDatasetManifest remoteManifest = await _remoteDataSource
        .fetchManifest();
    final RacerDatasetManifest? localManifest = _memorySnapshot?.manifest;
    if (localManifest != null && !remoteManifest.shouldReplace(localManifest)) {
      return;
    }

    final RacerDatasetSnapshot remoteSnapshot = await _remoteDataSource
        .fetchSnapshot(datasetId: remoteManifest.datasetId);
    _applySnapshot(remoteSnapshot);
    await _localStore.writeSnapshot(remoteSnapshot);
  }

  Future<void> _downloadLatestSnapshot() async {
    final RacerDatasetManifest remoteManifest = await _remoteDataSource
        .fetchManifest();
    final RacerDatasetSnapshot remoteSnapshot = await _remoteDataSource
        .fetchSnapshot(datasetId: remoteManifest.datasetId);
    _applySnapshot(remoteSnapshot);
    await _localStore.writeSnapshot(remoteSnapshot);
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
