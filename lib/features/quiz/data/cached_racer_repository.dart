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
  RacerImagePackLocalState? _imagePackState;
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
          downloadedImagePack: false,
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

  @override
  bool get hasUsableSnapshot => _hasUsableSnapshot(_memorySnapshot);

  @override
  List<RacerProfile> requireCachedAll() {
    final RacerDatasetSnapshot? snapshot = _memorySnapshot;
    if (snapshot == null || !_hasReadySnapshot()) {
      throw const RacerRepositoryException('選手画像を含むクイズデータがまだ読み込まれていません。');
    }

    final List<RacerProfile> activeRacers = _activeRacers(snapshot.racers);
    if (activeRacers.length < _minimumQuizRacerCount) {
      throw const RacerRepositoryException('クイズ開始に必要な選手データが不足しています。');
    }

    return activeRacers;
  }

  Future<RacerSyncResult> _initializeImpl() async {
    final RacerDatasetSnapshot? localSnapshot = await _localStore
        .readSnapshot();
    _imagePackState = await _localStore.readImagePackState();
    if (localSnapshot != null) {
      _memorySnapshot = await _attachLocalImages(localSnapshot);
    }

    if (_hasReadySnapshot()) {
      return RacerSyncResult(
        activeManifest: currentManifest,
        remoteManifest: currentManifest,
        downloadedSnapshot: false,
        downloadedImagePack: false,
        usedLocalSnapshot: true,
      );
    }

    final RacerDatasetManifest remoteManifest = await _remoteDataSource
        .fetchManifest();
    final _SyncPreparation preparation = await _prepareSnapshot(
      localSnapshot: localSnapshot,
      remoteManifest: remoteManifest,
    );

    bool downloadedImagePack = false;
    if (_shouldDownloadImagePack(preparation.snapshot.manifest)) {
      await _downloadAndStoreImagePack(preparation.snapshot.manifest);
      downloadedImagePack = true;
    }

    _memorySnapshot = await _attachLocalImages(preparation.snapshot);
    if (!_hasReadySnapshot()) {
      throw const RacerRepositoryException('選手画像の同期が完了していません。');
    }

    return RacerSyncResult(
      activeManifest: currentManifest,
      remoteManifest: remoteManifest,
      downloadedSnapshot: preparation.downloadedSnapshot,
      downloadedImagePack: downloadedImagePack,
      usedLocalSnapshot:
          localSnapshot != null && !preparation.downloadedSnapshot,
    );
  }

  Future<RacerSyncResult> _syncIfNeededImpl() async {
    final RacerDatasetManifest remoteManifest = await _remoteDataSource
        .fetchManifest();
    final RacerDatasetSnapshot? localSnapshot =
        _memorySnapshot ?? await _localStore.readSnapshot();
    _imagePackState ??= await _localStore.readImagePackState();

    final _SyncPreparation preparation = await _prepareSnapshot(
      localSnapshot: localSnapshot,
      remoteManifest: remoteManifest,
    );

    bool downloadedImagePack = false;
    if (_shouldDownloadImagePack(preparation.snapshot.manifest)) {
      await _downloadAndStoreImagePack(preparation.snapshot.manifest);
      downloadedImagePack = true;
    }

    _memorySnapshot = await _attachLocalImages(preparation.snapshot);
    if (!_hasUsableSnapshot(_memorySnapshot)) {
      throw const RacerRepositoryException('クイズ開始に必要な選手データが不足しています。');
    }
    if (!_hasReadySnapshot()) {
      throw const RacerRepositoryException('選手画像の同期が完了していません。');
    }

    return RacerSyncResult(
      activeManifest: currentManifest,
      remoteManifest: remoteManifest,
      downloadedSnapshot: preparation.downloadedSnapshot,
      downloadedImagePack: downloadedImagePack,
      usedLocalSnapshot:
          localSnapshot != null && !preparation.downloadedSnapshot,
    );
  }

  Future<_SyncPreparation> _prepareSnapshot({
    required RacerDatasetSnapshot? localSnapshot,
    required RacerDatasetManifest remoteManifest,
  }) async {
    if (localSnapshot == null ||
        !_hasUsableSnapshot(localSnapshot) ||
        remoteManifest.shouldReplaceSnapshot(localSnapshot.manifest)) {
      final RacerDatasetSnapshot remoteSnapshot = await _remoteDataSource
          .fetchSnapshot(datasetId: remoteManifest.datasetId);
      _validateSnapshot(remoteSnapshot);
      await _localStore.writeSnapshot(remoteSnapshot);
      return _SyncPreparation(
        snapshot: remoteSnapshot,
        downloadedSnapshot: true,
      );
    }

    if (remoteManifest.shouldReplaceImagePack(localSnapshot.manifest)) {
      final RacerDatasetSnapshot updatedSnapshot = RacerDatasetSnapshot(
        manifest: remoteManifest,
        racers: localSnapshot.racers
            .map(
              (RacerProfile racer) => racer.copyWith(clearLocalImagePath: true),
            )
            .toList(growable: false),
      );
      await _localStore.writeSnapshot(updatedSnapshot);
      return _SyncPreparation(
        snapshot: updatedSnapshot,
        downloadedSnapshot: false,
      );
    }

    return _SyncPreparation(snapshot: localSnapshot, downloadedSnapshot: false);
  }

  Future<void> _downloadAndStoreImagePack(RacerDatasetManifest manifest) async {
    final RacerImagePackManifest? imagePack = manifest.imagePack;
    if (imagePack == null) {
      throw const RacerRepositoryException('選手画像 pack の情報が不足しています。');
    }

    final List<int> zipBytes = await _remoteDataSource.downloadImagePack(
      datasetId: manifest.datasetId,
    );
    await _localStore.writeImagePack(manifest: manifest, zipBytes: zipBytes);
    _imagePackState = RacerImagePackLocalState(
      datasetId: manifest.datasetId,
      updatedAt: imagePack.updatedAt,
    );
  }

  Future<RacerDatasetSnapshot> _attachLocalImages(
    RacerDatasetSnapshot snapshot,
  ) async {
    final RacerImagePackLocalState? imagePackState = _imagePackState;
    if (!_hasReadyImagePack(snapshot.manifest, imagePackState)) {
      return RacerDatasetSnapshot(
        manifest: snapshot.manifest,
        racers: snapshot.racers
            .map(
              (RacerProfile racer) => racer.copyWith(clearLocalImagePath: true),
            )
            .toList(growable: false),
      );
    }

    final List<RacerProfile> racersWithPaths = <RacerProfile>[];
    for (final RacerProfile racer in snapshot.racers) {
      final String? localImagePath = await _localStore.resolveLocalImagePath(
        datasetId: snapshot.manifest.datasetId,
        racer: racer,
      );
      if (localImagePath == null || localImagePath.isEmpty) {
        racersWithPaths.add(racer.copyWith(clearLocalImagePath: true));
        continue;
      }

      racersWithPaths.add(racer.copyWith(localImagePath: localImagePath));
    }

    return RacerDatasetSnapshot(
      manifest: snapshot.manifest,
      racers: racersWithPaths,
    );
  }

  bool _hasReadySnapshot() => _isReady(_memorySnapshot);

  bool _isReady(RacerDatasetSnapshot? snapshot) {
    if (!_hasUsableSnapshot(snapshot)) {
      return false;
    }

    final List<RacerProfile> activeRacers = _activeRacers(snapshot!.racers);
    return activeRacers.every((RacerProfile racer) => racer.hasLocalImagePath);
  }

  bool _hasUsableSnapshot(RacerDatasetSnapshot? snapshot) {
    if (snapshot == null) {
      return false;
    }
    return _activeRacers(snapshot.racers).length >= _minimumQuizRacerCount;
  }

  bool _hasReadyImagePack(
    RacerDatasetManifest manifest,
    RacerImagePackLocalState? imagePackState,
  ) {
    final RacerImagePackManifest? imagePack = manifest.imagePack;
    if (imagePack == null || imagePackState == null) {
      return false;
    }

    return imagePackState.datasetId == manifest.datasetId &&
        !imagePack.updatedAt.isAfter(imagePackState.updatedAt);
  }

  bool _shouldDownloadImagePack(RacerDatasetManifest manifest) {
    return !_hasReadyImagePack(manifest, _imagePackState);
  }

  List<RacerProfile> _activeRacers(List<RacerProfile> racers) {
    return racers
        .where((RacerProfile racer) => racer.isActive)
        .toList(growable: false);
  }

  void _validateSnapshot(RacerDatasetSnapshot snapshot) {
    if (_activeRacers(snapshot.racers).length < _minimumQuizRacerCount) {
      throw const RacerRepositoryException('クイズ開始に必要な選手データが不足しています。');
    }
  }
}

class _SyncPreparation {
  const _SyncPreparation({
    required this.snapshot,
    required this.downloadedSnapshot,
  });

  final RacerDatasetSnapshot snapshot;
  final bool downloadedSnapshot;
}
