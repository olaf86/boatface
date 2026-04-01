import '../domain/quiz_models.dart';
import 'racer_master_models.dart';
import 'racer_repository.dart';

class MockRacerRepository implements RacerRepository {
  List<RacerProfile>? _cache;

  @override
  Future<RacerSyncResult> initialize() async {
    fetchAll();
    return RacerSyncResult(
      activeManifest: currentManifest,
      remoteManifest: currentManifest,
      downloadedSnapshot: false,
      downloadedImagePack: false,
      usedLocalSnapshot: true,
    );
  }

  @override
  Future<RacerSyncResult> syncIfNeeded() async => initialize();

  @override
  RacerDatasetManifest? get currentManifest => RacerDatasetManifest(
    datasetId: 'mock-dataset',
    datasetUpdatedAt: DateTime.utc(2026, 3, 21),
    recordCount: fetchAll().length,
    imagePack: null,
  );

  @override
  bool get hasUsableData => fetchAll().length >= 4;

  @override
  bool get hasUsableSnapshot => fetchAll().length >= 4;

  @override
  List<RacerProfile> requireCachedAll() => fetchAll();

  List<RacerProfile> fetchAll() {
    if (_cache != null) {
      return _cache!;
    }

    final DateTime now = DateTime.now().toUtc();
    final List<RacerProfile> racers = List<RacerProfile>.generate(4096, (
      int i,
    ) {
      final int registration = 1000 + i;
      return RacerProfile(
        id: 'racer-${registration.toString()}',
        name: '選手${registration.toString()}',
        nameKana: 'センシュ${registration.toString()}',
        registrationNumber: registration,
        registrationTerm: 80 + (i % 20),
        racerClass: switch (i % 4) {
          0 => 'A1',
          1 => 'A2',
          2 => 'B1',
          _ => 'B2',
        },
        gender: i.isEven ? 'male' : 'female',
        imageUrl: 'https://example.com/mock/racer/$registration.jpg',
        imageStoragePath: 'racer-images/mock-dataset/$registration.jpg',
        imageSource: 'mock-dataset',
        updatedAt: now,
        isActive: true,
      );
    });

    _cache = racers;
    return racers;
  }
}
