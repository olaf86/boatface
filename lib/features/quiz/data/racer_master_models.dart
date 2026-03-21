import '../domain/quiz_models.dart';

class RacerImagePackManifest {
  const RacerImagePackManifest({
    required this.storagePath,
    required this.updatedAt,
    required this.imageCount,
    required this.byteSize,
  });

  final String storagePath;
  final DateTime updatedAt;
  final int imageCount;
  final int byteSize;

  bool shouldReplace(RacerImagePackManifest other) {
    return storagePath != other.storagePath ||
        updatedAt.isAfter(other.updatedAt) ||
        imageCount != other.imageCount ||
        byteSize != other.byteSize;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'storagePath': storagePath,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'imageCount': imageCount,
      'byteSize': byteSize,
    };
  }

  static RacerImagePackManifest? tryParseJson(Map<String, Object?> json) {
    final Object? storagePathValue = json['storagePath'];
    final Object? updatedAtValue = json['updatedAt'];
    final Object? imageCountValue = json['imageCount'];
    final Object? byteSizeValue = json['byteSize'];

    if (storagePathValue is! String ||
        storagePathValue.isEmpty ||
        updatedAtValue is! String ||
        imageCountValue is! int ||
        byteSizeValue is! int) {
      return null;
    }

    final DateTime? updatedAt = DateTime.tryParse(updatedAtValue);
    if (updatedAt == null) {
      return null;
    }

    return RacerImagePackManifest(
      storagePath: storagePathValue,
      updatedAt: updatedAt.toUtc(),
      imageCount: imageCountValue,
      byteSize: byteSizeValue,
    );
  }
}

class RacerDatasetManifest {
  const RacerDatasetManifest({
    required this.datasetId,
    required this.datasetUpdatedAt,
    required this.recordCount,
    required this.imagePack,
  });

  final String datasetId;
  final DateTime datasetUpdatedAt;
  final int recordCount;
  final RacerImagePackManifest? imagePack;

  bool shouldReplace(RacerDatasetManifest other) {
    return shouldReplaceSnapshot(other) || shouldReplaceImagePack(other);
  }

  bool shouldReplaceSnapshot(RacerDatasetManifest other) {
    return datasetId != other.datasetId ||
        datasetUpdatedAt.isAfter(other.datasetUpdatedAt) ||
        recordCount != other.recordCount;
  }

  bool shouldReplaceImagePack(RacerDatasetManifest other) {
    final RacerImagePackManifest? nextImagePack = imagePack;
    final RacerImagePackManifest? currentImagePack = other.imagePack;
    if (nextImagePack == null) {
      return false;
    }
    if (currentImagePack == null) {
      return true;
    }
    return nextImagePack.shouldReplace(currentImagePack);
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'datasetId': datasetId,
      'datasetUpdatedAt': datasetUpdatedAt.toUtc().toIso8601String(),
      'recordCount': recordCount,
      'imagePack': imagePack?.toJson(),
    };
  }

  static RacerDatasetManifest? tryParseJson(Map<String, Object?> json) {
    final Object? datasetIdValue = json['datasetId'];
    final Object? datasetUpdatedAtValue = json['datasetUpdatedAt'];
    final Object? recordCountValue = json['recordCount'];
    final Object? imagePackValue = json['imagePack'];

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
      imagePack: imagePackValue is Map<Object?, Object?>
          ? RacerImagePackManifest.tryParseJson(
              Map<String, Object?>.from(imagePackValue),
            )
          : null,
    );
  }
}

class RacerImagePackLocalState {
  const RacerImagePackLocalState({
    required this.datasetId,
    required this.updatedAt,
  });

  final String datasetId;
  final DateTime updatedAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'datasetId': datasetId,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  static RacerImagePackLocalState? tryParseJson(Map<String, Object?> json) {
    final Object? datasetIdValue = json['datasetId'];
    final Object? updatedAtValue = json['updatedAt'];

    if (datasetIdValue is! String ||
        datasetIdValue.isEmpty ||
        updatedAtValue is! String) {
      return null;
    }

    final DateTime? updatedAt = DateTime.tryParse(updatedAtValue);
    if (updatedAt == null) {
      return null;
    }

    return RacerImagePackLocalState(
      datasetId: datasetIdValue,
      updatedAt: updatedAt.toUtc(),
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
    required this.downloadedImagePack,
    required this.usedLocalSnapshot,
  });

  final RacerDatasetManifest? activeManifest;
  final RacerDatasetManifest? remoteManifest;
  final bool downloadedSnapshot;
  final bool downloadedImagePack;
  final bool usedLocalSnapshot;
}
