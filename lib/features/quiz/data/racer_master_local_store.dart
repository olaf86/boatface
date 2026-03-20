import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/quiz_models.dart';
import 'racer_master_models.dart';

abstract class RacerMasterLocalStore {
  Future<RacerDatasetSnapshot?> readSnapshot();

  Future<void> writeSnapshot(RacerDatasetSnapshot snapshot);
}

class FileRacerMasterLocalStore implements RacerMasterLocalStore {
  FileRacerMasterLocalStore({
    Future<Directory> Function()? rootDirectoryProvider,
  }) : _rootDirectoryProvider =
           rootDirectoryProvider ?? getApplicationSupportDirectory;

  static const String _directoryName = 'racer_master';
  static const String _manifestFileName = 'manifest.json';
  static const String _snapshotFileName = 'racers.json.gz';

  final Future<Directory> Function() _rootDirectoryProvider;

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

  Future<Directory> _ensureDirectory() async {
    final Directory root = await _rootDirectoryProvider();
    final Directory directory = Directory('${root.path}/$_directoryName');
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}
