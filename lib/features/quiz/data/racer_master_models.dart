import '../domain/quiz_models.dart';

class RacerDatasetManifest {
  const RacerDatasetManifest({
    required this.datasetId,
    required this.datasetUpdatedAt,
    required this.recordCount,
  });

  final String datasetId;
  final DateTime datasetUpdatedAt;
  final int recordCount;

  bool shouldReplace(RacerDatasetManifest other) {
    return datasetId != other.datasetId ||
        datasetUpdatedAt.isAfter(other.datasetUpdatedAt);
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'datasetId': datasetId,
      'datasetUpdatedAt': datasetUpdatedAt.toUtc().toIso8601String(),
      'recordCount': recordCount,
    };
  }

  static RacerDatasetManifest? tryParseJson(Map<String, Object?> json) {
    final Object? datasetIdValue = json['datasetId'];
    final Object? datasetUpdatedAtValue = json['datasetUpdatedAt'];
    final Object? recordCountValue = json['recordCount'];

    if (datasetIdValue is! String ||
        datasetIdValue.isEmpty ||
        datasetUpdatedAtValue is! String ||
        recordCountValue is! int) {
      return null;
    }

    final DateTime? datasetUpdatedAt = DateTime.tryParse(datasetUpdatedAtValue);
    if (datasetUpdatedAt == null) {
      return null;
    }

    return RacerDatasetManifest(
      datasetId: datasetIdValue,
      datasetUpdatedAt: datasetUpdatedAt.toUtc(),
      recordCount: recordCountValue,
    );
  }
}

class RacerDatasetSnapshot {
  const RacerDatasetSnapshot({required this.manifest, required this.racers});

  final RacerDatasetManifest manifest;
  final List<RacerProfile> racers;
}

class RacerSyncResult {
  const RacerSyncResult({
    required this.activeManifest,
    required this.remoteManifest,
    required this.downloadedSnapshot,
    required this.usedLocalSnapshot,
  });

  final RacerDatasetManifest? activeManifest;
  final RacerDatasetManifest? remoteManifest;
  final bool downloadedSnapshot;
  final bool usedLocalSnapshot;
}
