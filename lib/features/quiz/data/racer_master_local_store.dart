import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/quiz_models.dart';
import 'racer_master_models.dart';

abstract class RacerMasterLocalStore {
  Future<RacerDatasetSnapshot?> readSnapshot();

  Future<void> writeSnapshot(RacerDatasetSnapshot snapshot);

  Future<RacerImagePackLocalState?> readImagePackState();

  Future<void> writeImagePack({
    required RacerDatasetManifest manifest,
    required List<int> zipBytes,
  });

  Future<String?> resolveLocalImagePath({
    required String datasetId,
    required RacerProfile racer,
  });
}

class FileRacerMasterLocalStore implements RacerMasterLocalStore {
  FileRacerMasterLocalStore({
    Future<Directory> Function()? rootDirectoryProvider,
  }) : _rootDirectoryProvider =
           rootDirectoryProvider ?? getApplicationSupportDirectory;

  static const String _directoryName = 'racer_master';
  static const String _manifestFileName = 'manifest.json';
  static const String _snapshotFileName = 'racers.json.gz';
  static const String _imagePackStateFileName = 'image-pack.json';
  static const String _imagesDirectoryName = 'images';

  final Future<Directory> Function() _rootDirectoryProvider;
  Future<Directory>? _directoryFuture;

  @override
  Future<RacerDatasetSnapshot?> readSnapshot() async {
    final Directory directory = await _ensureDirectory();
    final File manifestFile = File('${directory.path}/$_manifestFileName');
    final File snapshotFile = File('${directory.path}/$_snapshotFileName');

    if (!manifestFile.existsSync() || !snapshotFile.existsSync()) {
      return null;
    }

    try {
      final Object? manifestDecoded = jsonDecode(
        await manifestFile.readAsString(),
      );
      if (manifestDecoded is! Map<Object?, Object?>) {
        return null;
      }

      final RacerDatasetManifest? manifest = RacerDatasetManifest.tryParseJson(
        Map<String, Object?>.from(manifestDecoded),
      );
      if (manifest == null) {
        return null;
      }

      final List<int> compressedBytes = await snapshotFile.readAsBytes();
      final String jsonText = utf8.decode(gzip.decode(compressedBytes));
      final Object? racersDecoded = jsonDecode(jsonText);
      if (racersDecoded is! List<Object?>) {
        return null;
      }

      final List<RacerProfile> racers = racersDecoded
          .map(
            (Object? item) => item is Map<Object?, Object?>
                ? RacerProfile.tryParseJson(Map<String, Object?>.from(item))
                : null,
          )
          .whereType<RacerProfile>()
          .toList(growable: false);

      return RacerDatasetSnapshot(manifest: manifest, racers: racers);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeSnapshot(RacerDatasetSnapshot snapshot) async {
    final Directory directory = await _ensureDirectory();
    final File manifestFile = File('${directory.path}/$_manifestFileName');
    final File snapshotFile = File('${directory.path}/$_snapshotFileName');

    await manifestFile.writeAsString(
      jsonEncode(snapshot.manifest.toJson()),
      flush: true,
    );
    await snapshotFile.writeAsBytes(
      gzip.encode(
        utf8.encode(
          jsonEncode(
            snapshot.racers
                .map((RacerProfile racer) => racer.toJson())
                .toList(growable: false),
          ),
        ),
      ),
      flush: true,
    );
  }

  @override
  Future<RacerImagePackLocalState?> readImagePackState() async {
    final Directory directory = await _ensureDirectory();
    final File stateFile = File('${directory.path}/$_imagePackStateFileName');
    if (!stateFile.existsSync()) {
      return null;
    }

    try {
      final Object? decoded = jsonDecode(await stateFile.readAsString());
      if (decoded is! Map<Object?, Object?>) {
        return null;
      }

      return RacerImagePackLocalState.tryParseJson(
        Map<String, Object?>.from(decoded),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeImagePack({
    required RacerDatasetManifest manifest,
    required List<int> zipBytes,
  }) async {
    final RacerImagePackManifest? imagePack = manifest.imagePack;
    if (imagePack == null) {
      throw const FileSystemException('image pack metadata is missing');
    }

    final Directory directory = await _ensureDirectory();
    final Directory imagesRoot = Directory(
      '${directory.path}/$_imagesDirectoryName',
    );
    if (!imagesRoot.existsSync()) {
      await imagesRoot.create(recursive: true);
    }

    final Directory datasetDirectory = Directory(
      '${imagesRoot.path}/${manifest.datasetId}',
    );
    if (datasetDirectory.existsSync()) {
      await datasetDirectory.delete(recursive: true);
    }
    await datasetDirectory.create(recursive: true);

    final Archive archive = ZipDecoder().decodeBytes(zipBytes, verify: true);
    int writtenImageCount = 0;
    for (final ArchiveFile file in archive) {
      if (!file.isFile) {
        continue;
      }

      final List<int> data = file.content as List<int>;
      final String entryName = _basename(file.name);
      final File outputFile = File('${datasetDirectory.path}/$entryName');
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(data, flush: true);
      writtenImageCount += 1;
    }

    if (writtenImageCount < imagePack.imageCount) {
      throw FileSystemException(
        'expected ${imagePack.imageCount} images but extracted $writtenImageCount',
      );
    }

    final File stateFile = File('${directory.path}/$_imagePackStateFileName');
    await stateFile.writeAsString(
      jsonEncode(
        RacerImagePackLocalState(
          datasetId: manifest.datasetId,
          updatedAt: imagePack.updatedAt,
        ).toJson(),
      ),
      flush: true,
    );

    final List<FileSystemEntity> staleEntities = imagesRoot
        .listSync(followLinks: false)
        .where((FileSystemEntity entity) {
          return entity is Directory &&
              _basename(entity.path) != manifest.datasetId;
        })
        .toList(growable: false);
    for (final FileSystemEntity entity in staleEntities) {
      await entity.delete(recursive: true);
    }
  }

  @override
  Future<String?> resolveLocalImagePath({
    required String datasetId,
    required RacerProfile racer,
  }) async {
    final String? imageFileName = _imageFileNameFor(racer);
    if (imageFileName == null) {
      return null;
    }

    final Directory directory = await _ensureDirectory();
    return '${directory.path}/$_imagesDirectoryName/$datasetId/$imageFileName';
  }

  Future<Directory> _ensureDirectory() async {
    final Future<Directory>? currentFuture = _directoryFuture;
    if (currentFuture != null) {
      return currentFuture;
    }

    final Future<Directory> nextFuture = _createDirectory();
    _directoryFuture = nextFuture;
    return nextFuture;
  }

  Future<Directory> _createDirectory() async {
    final Directory root = await _rootDirectoryProvider();
    final Directory directory = Directory('${root.path}/$_directoryName');
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _basename(String pathValue) {
    final List<String> segments = pathValue.split('/');
    return segments.isEmpty ? pathValue : segments.last;
  }

  String? _imageFileNameFor(RacerProfile racer) {
    final String? storagePath = racer.imageStoragePath;
    if (storagePath != null && storagePath.isNotEmpty) {
      return _basename(storagePath);
    }

    final Uri? imageUri = Uri.tryParse(racer.imageUrl);
    if (imageUri == null || imageUri.pathSegments.isEmpty) {
      return null;
    }

    return imageUri.pathSegments.last;
  }
}
