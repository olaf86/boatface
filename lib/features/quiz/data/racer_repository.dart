import '../domain/quiz_models.dart';
import 'racer_master_models.dart';

abstract class RacerRepository {
  Future<RacerSyncResult> initialize();

  Future<RacerSyncResult> syncIfNeeded();

  RacerDatasetManifest? get currentManifest;

  bool get hasUsableData;

  bool get hasUsableSnapshot;

  List<RacerProfile> requireCachedAll();
}

class RacerRepositoryException implements Exception {
  const RacerRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
