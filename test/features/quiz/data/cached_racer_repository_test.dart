import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boatface/features/quiz/application/racer_master_sync_controller.dart';
import 'package:boatface/features/quiz/application/racer_master_sync_state.dart';
import 'package:boatface/features/quiz/data/cached_racer_repository.dart';
import 'package:boatface/features/quiz/data/racer_api_client.dart';
import 'package:boatface/features/quiz/data/racer_master_local_store.dart';
import 'package:boatface/features/quiz/data/racer_master_models.dart';
import 'package:boatface/features/quiz/data/quiz_data_providers.dart';
import 'package:boatface/features/quiz/domain/quiz_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FileRacerMasterLocalStore', () {
    test('writes and reads compressed snapshot files', () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'boatface-racer-store-',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      final FileRacerMasterLocalStore store = FileRacerMasterLocalStore(
        rootDirectoryProvider: () async => tempDir,
      );
      final RacerDatasetSnapshot snapshot = _buildSnapshot(
        datasetId: '2026-H1',
        updatedAt: DateTime.utc(2026, 3, 21),
        prefix: 'local',
      );

      await store.writeSnapshot(snapshot);

      final RacerDatasetSnapshot? restored = await store.readSnapshot();
      expect(restored, isNotNull);
      expect(restored!.manifest.datasetId, '2026-H1');
      expect(restored.racers.length, 5);
      expect(restored.racers.first.id, 'local-racer-0');
    });

    test('extracts image packs and records local state', () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'boatface-racer-images-',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      final FileRacerMasterLocalStore store = FileRacerMasterLocalStore(
        rootDirectoryProvider: () async => tempDir,
      );
      final RacerDatasetManifest manifest = _buildManifest(
        datasetId: '2026-H1',
        updatedAt: DateTime.utc(2026, 3, 21),
      );

      await store.writeImagePack(
        manifest: manifest,
        zipBytes: _buildImagePackZipBytes(<String>[
          '1000.jpg',
          '1001.jpg',
          '1002.jpg',
          '1003.jpg',
          '1004.jpg',
        ]),
      );

      final RacerImagePackLocalState? state = await store.readImagePackState();
      expect(state, isNotNull);
      expect(state!.datasetId, '2026-H1');
      expect(state.updatedAt, manifest.imagePack!.updatedAt);

      final String? imagePath = await store.resolveLocalImagePath(
        datasetId: '2026-H1',
        racer: _buildSnapshot(
          datasetId: '2026-H1',
          updatedAt: DateTime.utc(2026, 3, 21),
          prefix: 'local',
        ).racers.first,
      );
      expect(imagePath, isNotNull);
      expect(File(imagePath!).existsSync(), true);
    });
  });

  group('CachedRacerRepository', () {
    test('initializes from remote when no local data exists', () async {
      final _FakeRemoteDataSource remoteDataSource = _FakeRemoteDataSource(
        manifest: _buildManifest(
          datasetId: '2026-H1',
          updatedAt: DateTime.utc(2026, 3, 21),
        ),
        snapshot: _buildSnapshot(
          datasetId: '2026-H1',
          updatedAt: DateTime.utc(2026, 3, 21),
          prefix: 'remote',
        ),
      );
      final _InMemoryLocalStore localStore = _InMemoryLocalStore();
      final CachedRacerRepository repository = CachedRacerRepository(
        remoteDataSource: remoteDataSource,
        localStore: localStore,
      );

      final RacerSyncResult result = await repository.initialize();

      expect(remoteDataSource.manifestFetchCount, 1);
      expect(remoteDataSource.snapshotFetchCount, 1);
      expect(remoteDataSource.imagePackFetchCount, 1);
      expect(result.downloadedSnapshot, true);
      expect(result.downloadedImagePack, true);
      expect(repository.requireCachedAll().first.id, 'remote-racer-0');
      expect(repository.requireCachedAll().first.hasLocalImagePath, true);
      expect(localStore.snapshot?.manifest.datasetId, '2026-H1');
      expect(localStore.imagePackState?.datasetId, '2026-H1');
    });

    test('uses local snapshot and image pack without remote access', () async {
      final RacerDatasetSnapshot localSnapshot = _buildSnapshot(
        datasetId: '2026-H1',
        updatedAt: DateTime.utc(2026, 3, 21),
        prefix: 'local',
      );
      final _InMemoryLocalStore localStore = _InMemoryLocalStore(
        snapshot: localSnapshot,
        imagePackState: RacerImagePackLocalState(
          datasetId: '2026-H1',
          updatedAt: localSnapshot.manifest.imagePack!.updatedAt,
        ),
      );
      await localStore.seedLocalImages(localSnapshot);

      final _FakeRemoteDataSource remoteDataSource = _FakeRemoteDataSource(
        manifest: _buildManifest(
          datasetId: '2026-H1',
          updatedAt: DateTime.utc(2026, 3, 22),
        ),
        snapshot: _buildSnapshot(
          datasetId: '2026-H1',
          updatedAt: DateTime.utc(2026, 3, 22),
          prefix: 'remote',
        ),
      );
      final CachedRacerRepository repository = CachedRacerRepository(
        remoteDataSource: remoteDataSource,
        localStore: localStore,
      );

      final RacerSyncResult initResult = await repository.initialize();

      expect(initResult.usedLocalSnapshot, true);
      expect(initResult.downloadedImagePack, false);
      expect(repository.requireCachedAll().first.id, 'local-racer-0');
      expect(remoteDataSource.manifestFetchCount, 0);
      expect(remoteDataSource.snapshotFetchCount, 0);
      expect(remoteDataSource.imagePackFetchCount, 0);
    });

    test(
      'refreshes image pack when only image pack metadata is newer',
      () async {
        final RacerDatasetSnapshot localSnapshot = _buildSnapshot(
          datasetId: '2026-H1',
          updatedAt: DateTime.utc(2026, 3, 21),
          prefix: 'local',
        );
        final _InMemoryLocalStore localStore = _InMemoryLocalStore(
          snapshot: localSnapshot,
          imagePackState: RacerImagePackLocalState(
            datasetId: '2026-H1',
            updatedAt: DateTime.utc(2026, 3, 21, 0, 0, 0),
          ),
        );
        await localStore.seedLocalImages(localSnapshot);
        final _FakeRemoteDataSource remoteDataSource = _FakeRemoteDataSource(
          manifest: _buildManifest(
            datasetId: '2026-H1',
            updatedAt: DateTime.utc(2026, 3, 21),
            imagePackUpdatedAt: DateTime.utc(2026, 3, 22),
          ),
          snapshot: _buildSnapshot(
            datasetId: '2026-H1',
            updatedAt: DateTime.utc(2026, 3, 22),
            prefix: 'remote',
          ),
        );
        final CachedRacerRepository repository = CachedRacerRepository(
          remoteDataSource: remoteDataSource,
          localStore: localStore,
        );

        await repository.initialize();
        final RacerSyncResult syncResult = await repository.syncIfNeeded();

        expect(remoteDataSource.manifestFetchCount, 1);
        expect(remoteDataSource.snapshotFetchCount, 0);
        expect(remoteDataSource.imagePackFetchCount, 1);
        expect(syncResult.downloadedSnapshot, false);
        expect(syncResult.downloadedImagePack, true);
        expect(
          localStore.snapshot?.manifest.imagePack?.updatedAt,
          DateTime.utc(2026, 3, 22),
        );
      },
    );

    test(
      're-downloads snapshot when local snapshot is unusable even if manifest matches',
      () async {
        final RacerDatasetSnapshot localSnapshot = RacerDatasetSnapshot(
          manifest: _buildManifest(
            datasetId: '2026-H1',
            updatedAt: DateTime.utc(2026, 3, 22),
          ),
          racers: const <RacerProfile>[],
        );
        final _InMemoryLocalStore localStore = _InMemoryLocalStore(
          snapshot: localSnapshot,
        );
        final _FakeRemoteDataSource remoteDataSource = _FakeRemoteDataSource(
          manifest: _buildManifest(
            datasetId: '2026-H1',
            updatedAt: DateTime.utc(2026, 3, 22),
          ),
          snapshot: _buildSnapshot(
            datasetId: '2026-H1',
            updatedAt: DateTime.utc(2026, 3, 22),
            prefix: 'remote',
          ),
        );
        final CachedRacerRepository repository = CachedRacerRepository(
          remoteDataSource: remoteDataSource,
          localStore: localStore,
        );

        final RacerSyncResult result = await repository.initialize();

        expect(result.downloadedSnapshot, true);
        expect(result.downloadedImagePack, true);
        expect(remoteDataSource.manifestFetchCount, 1);
        expect(remoteDataSource.snapshotFetchCount, 1);
        expect(remoteDataSource.imagePackFetchCount, 1);
        expect(localStore.snapshot?.racers, isNotEmpty);
        expect(repository.requireCachedAll().first.id, 'remote-racer-0');
      },
    );
  });

  group('RacerMasterSyncController', () {
    test(
      'starts background sync and promotes local data to ready state',
      () async {
        final _FakeRemoteDataSource remoteDataSource = _FakeRemoteDataSource(
          manifest: _buildManifest(
            datasetId: '2026-H1',
            updatedAt: DateTime.utc(2026, 3, 22),
          ),
          snapshot: _buildSnapshot(
            datasetId: '2026-H1',
            updatedAt: DateTime.utc(2026, 3, 22),
            prefix: 'remote',
          ),
        );
        final _InMemoryLocalStore localStore = _InMemoryLocalStore();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            racerMasterRemoteDataSourceProvider.overrideWithValue(
              remoteDataSource,
            ),
            racerMasterLocalStoreProvider.overrideWithValue(localStore),
          ],
        );
        addTearDown(container.dispose);

        expect(
          container.read(racerMasterSyncControllerProvider).canStartQuiz,
          false,
        );

        await container
            .read(racerMasterSyncControllerProvider.notifier)
            .startBackgroundSyncIfNeeded();

        final RacerMasterSyncState state = container.read(
          racerMasterSyncControllerProvider,
        );
        expect(state.phase, RacerMasterSyncPhase.ready);
        expect(state.canStartQuiz, true);
        expect(
          state.activeManifest?.datasetUpdatedAt,
          DateTime.utc(2026, 3, 22),
        );
        expect(
          state.remoteManifest?.datasetUpdatedAt,
          DateTime.utc(2026, 3, 22),
        );
      },
    );
  });
}

class _FakeRemoteDataSource implements RacerMasterRemoteDataSource {
  _FakeRemoteDataSource({required this.manifest, required this.snapshot});

  final RacerDatasetManifest manifest;
  final RacerDatasetSnapshot snapshot;
  int manifestFetchCount = 0;
  int snapshotFetchCount = 0;
  int imagePackFetchCount = 0;

  @override
  Future<RacerDatasetManifest> fetchManifest() async {
    manifestFetchCount += 1;
    return manifest;
  }

  @override
  Future<RacerDatasetSnapshot> fetchSnapshot({
    required String datasetId,
  }) async {
    snapshotFetchCount += 1;
    return snapshot;
  }

  @override
  Future<List<int>> downloadImagePack({required String datasetId}) async {
    imagePackFetchCount += 1;
    return _buildImagePackZipBytes(
      snapshot.racers
          .map((RacerProfile racer) => '${racer.registrationNumber}.jpg')
          .toList(growable: false),
    );
  }
}

class _InMemoryLocalStore implements RacerMasterLocalStore {
  _InMemoryLocalStore({this.snapshot, this.imagePackState});

  RacerDatasetSnapshot? snapshot;
  RacerImagePackLocalState? imagePackState;
  final Map<String, String> imagePaths = <String, String>{};

  @override
  Future<RacerDatasetSnapshot?> readSnapshot() async => snapshot;

  @override
  Future<void> writeSnapshot(RacerDatasetSnapshot nextSnapshot) async {
    snapshot = nextSnapshot;
  }

  @override
  Future<RacerImagePackLocalState?> readImagePackState() async =>
      imagePackState;

  @override
  Future<void> writeImagePack({
    required RacerDatasetManifest manifest,
    required List<int> zipBytes,
  }) async {
    final Archive archive = ZipDecoder().decodeBytes(zipBytes, verify: true);
    final Directory tempDir = await Directory.systemTemp.createTemp(
      'boatface-racer-pack-',
    );
    for (final ArchiveFile file in archive) {
      if (!file.isFile) {
        continue;
      }

      final String localPath = '${tempDir.path}/${file.name}';
      await File(localPath).writeAsBytes(file.content as List<int>);
      imagePaths['${manifest.datasetId}/${file.name}'] = localPath;
    }
    imagePackState = RacerImagePackLocalState(
      datasetId: manifest.datasetId,
      updatedAt: manifest.imagePack!.updatedAt,
    );
  }

  @override
  Future<String?> resolveLocalImagePath({
    required String datasetId,
    required RacerProfile racer,
  }) async {
    return imagePaths['$datasetId/${racer.registrationNumber}.jpg'];
  }

  Future<void> seedLocalImages(RacerDatasetSnapshot localSnapshot) async {
    for (final RacerProfile racer in localSnapshot.racers) {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'boatface-racer-local-',
      );
      final String path = '${tempDir.path}/${racer.registrationNumber}.jpg';
      await File(path).writeAsString('local-image');
      imagePaths['${localSnapshot.manifest.datasetId}/${racer.registrationNumber}.jpg'] =
          path;
    }
  }
}

RacerDatasetManifest _buildManifest({
  required String datasetId,
  required DateTime updatedAt,
  DateTime? imagePackUpdatedAt,
}) {
  return RacerDatasetManifest(
    datasetId: datasetId,
    datasetUpdatedAt: updatedAt,
    recordCount: 5,
    imagePack: RacerImagePackManifest(
      storagePath: 'racer-image-packs/$datasetId.zip',
      updatedAt: imagePackUpdatedAt ?? updatedAt,
      imageCount: 5,
      byteSize: 5120,
    ),
  );
}

RacerDatasetSnapshot _buildSnapshot({
  required String datasetId,
  required DateTime updatedAt,
  required String prefix,
}) {
  return RacerDatasetSnapshot(
    manifest: _buildManifest(datasetId: datasetId, updatedAt: updatedAt),
    racers: List<RacerProfile>.generate(5, (int index) {
      return RacerProfile(
        id: '$prefix-racer-$index',
        name: '選手$index',
        nameKana: 'センシュ$index',
        registrationNumber: 1000 + index,
        registrationTerm: 80 + index,
        racerClass: index < 4 ? 'A1' : 'B1',
        gender: index.isEven ? 'male' : 'female',
        imageUrl: 'https://example.com/$prefix/$index.jpg',
        imageStoragePath: 'racer-images/$datasetId/${1000 + index}.jpg',
        imageSource: prefix,
        updatedAt: updatedAt,
        isActive: index < 4 || prefix == 'local',
        birthDate: DateTime.utc(1990, 4, index + 1),
        birthPlace: '福岡県',
        homeBranch: '東京',
      );
    }),
  );
}

List<int> _buildImagePackZipBytes(List<String> fileNames) {
  final Archive archive = Archive();
  for (final String fileName in fileNames) {
    archive.addFile(
      ArchiveFile(
        fileName,
        utf8.encode(fileName).length,
        utf8.encode(fileName),
      ),
    );
  }
  return ZipEncoder().encode(archive);
}
