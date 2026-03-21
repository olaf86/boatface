import 'dart:io';

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
  });

  group('CachedRacerRepository', () {
    test('initializes from remote when no local snapshot exists', () async {
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
      expect(result.downloadedSnapshot, true);
      expect(repository.requireCachedAll().first.id, 'remote-racer-0');
      expect(localStore.snapshot?.manifest.datasetId, '2026-H1');
    });

    test(
      'uses local snapshot immediately and refreshes after explicit sync',
      () async {
        final _InMemoryLocalStore localStore = _InMemoryLocalStore(
          snapshot: _buildSnapshot(
            datasetId: '2026-H1',
            updatedAt: DateTime.utc(2026, 3, 21),
            prefix: 'local',
          ),
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

        final RacerSyncResult initResult = await repository.initialize();

        expect(initResult.usedLocalSnapshot, true);
        expect(repository.requireCachedAll().first.id, 'local-racer-0');
        expect(remoteDataSource.manifestFetchCount, 0);
        expect(remoteDataSource.snapshotFetchCount, 0);

        final RacerSyncResult syncResult = await repository.syncIfNeeded();

        expect(remoteDataSource.manifestFetchCount, 1);
        expect(remoteDataSource.snapshotFetchCount, 1);
        expect(syncResult.downloadedSnapshot, true);
        expect(repository.requireCachedAll().first.id, 'remote-racer-0');
        expect(
          localStore.snapshot?.manifest.datasetUpdatedAt,
          DateTime.utc(2026, 3, 22),
        );
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
        final _InMemoryLocalStore localStore = _InMemoryLocalStore(
          snapshot: _buildSnapshot(
            datasetId: '2026-H1',
            updatedAt: DateTime.utc(2026, 3, 21),
            prefix: 'local',
          ),
        );
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
}

class _InMemoryLocalStore implements RacerMasterLocalStore {
  _InMemoryLocalStore({this.snapshot});

  RacerDatasetSnapshot? snapshot;

  @override
  Future<RacerDatasetSnapshot?> readSnapshot() async => snapshot;

  @override
  Future<void> writeSnapshot(RacerDatasetSnapshot nextSnapshot) async {
    snapshot = nextSnapshot;
  }
}

RacerDatasetManifest _buildManifest({
  required String datasetId,
  required DateTime updatedAt,
}) {
  return RacerDatasetManifest(
    datasetId: datasetId,
    datasetUpdatedAt: updatedAt,
    recordCount: 5,
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
        registrationNumber: 1000 + index,
        imageUrl: 'https://example.com/$prefix/$index.jpg',
        imageSource: prefix,
        updatedAt: updatedAt,
        isActive: index < 4 || prefix == 'local',
      );
    }),
  );
}
