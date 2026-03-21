import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

import '../domain/quiz_models.dart';
import 'racer_master_models.dart';
import 'racer_repository.dart';

abstract class RacerMasterRemoteDataSource {
  Future<RacerDatasetManifest> fetchManifest();

  Future<RacerDatasetSnapshot> fetchSnapshot({required String datasetId});

  Future<List<int>> downloadImagePack({required String datasetId});
}

class FirebaseRacerMasterRemoteDataSource
    implements RacerMasterRemoteDataSource {
  FirebaseRacerMasterRemoteDataSource({
    required FirebaseAuth auth,
    http.Client? httpClient,
    this.region = 'asia-northeast2',
  }) : _auth = auth,
       _httpClient = httpClient ?? http.Client();

  final FirebaseAuth _auth;
  final http.Client _httpClient;
  final String region;

  @override
  Future<RacerDatasetManifest> fetchManifest() async {
    final Map<String, Object?> json = await _getJsonObject(
      '/getRacerDatasetManifest',
    );
    final RacerDatasetManifest? manifest = RacerDatasetManifest.tryParseJson(
      json,
    );
    if (manifest == null) {
      throw const RacerRepositoryException('選手データ manifest の形式が不正です。');
    }

    return manifest;
  }

  @override
  Future<RacerDatasetSnapshot> fetchSnapshot({
    required String datasetId,
  }) async {
    final Map<String, Object?> json = await _getJsonObject(
      '/getRacerDatasetSnapshot',
      queryParameters: <String, String>{'datasetId': datasetId},
    );

    final RacerDatasetManifest? manifest = RacerDatasetManifest.tryParseJson(
      Map<String, Object?>.from(json),
    );
    final Object? racersValue = json['racers'];
    if (manifest == null || racersValue is! List<Object?>) {
      throw const RacerRepositoryException('選手データ snapshot の形式が不正です。');
    }

    final List<RacerProfile> racers = racersValue
        .map(
          (Object? item) => item is Map<Object?, Object?>
              ? RacerProfile.tryParseJson(Map<String, Object?>.from(item))
              : null,
        )
        .whereType<RacerProfile>()
        .toList(growable: false);

    return RacerDatasetSnapshot(manifest: manifest, racers: racers);
  }

  @override
  Future<List<int>> downloadImagePack({required String datasetId}) async {
    final http.Response response = await _get(
      '/getRacerDatasetImagePack',
      queryParameters: <String, String>{'datasetId': datasetId},
      acceptHeader: 'application/zip',
    );
    if (response.statusCode != 200) {
      throw RacerRepositoryException(_buildErrorMessage(response));
    }

    return response.bodyBytes;
  }

  Future<Map<String, Object?>> _getJsonObject(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final http.Response response = await _get(
      path,
      queryParameters: queryParameters,
      acceptHeader: 'application/json',
    );
    if (response.statusCode != 200) {
      throw RacerRepositoryException(_buildErrorMessage(response));
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<Object?, Object?>) {
      throw const RacerRepositoryException('選手データの形式が不正です。');
    }

    return Map<String, Object?>.from(decoded);
  }

  Future<http.Response> _get(
    String path, {
    Map<String, String>? queryParameters,
    required String acceptHeader,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw const RacerRepositoryException('ログイン状態を確認できません。');
    }

    final String projectId = Firebase.app().options.projectId;
    if (projectId.isEmpty) {
      throw const RacerRepositoryException('Firebase projectId を取得できません。');
    }

    final Uri uri = Uri.https(
      '$region-$projectId.cloudfunctions.net',
      path,
      queryParameters,
    );
    final String? token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const RacerRepositoryException('認証トークンを取得できません。');
    }

    final http.Response response = await _httpClient.get(
      uri,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Accept': acceptHeader,
      },
    );
    return response;
  }

  String _buildErrorMessage(http.Response response) {
    try {
      final Object? decoded = jsonDecode(response.body);
      if (decoded is Map<String, Object?>) {
        final Object? message = decoded['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // Fall through to the generic message.
    }

    return '選手データの取得に失敗しました。(HTTP ${response.statusCode})';
  }
}
