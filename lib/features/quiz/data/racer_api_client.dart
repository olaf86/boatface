import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

import '../domain/quiz_models.dart';
import 'racer_repository.dart';

abstract class RacerApiClient {
  Future<List<RacerProfile>> fetchAll({bool activeOnly = true});
}

class FirebaseRacerApiClient implements RacerApiClient {
  FirebaseRacerApiClient({
    required FirebaseAuth auth,
    http.Client? httpClient,
    this.region = 'asia-northeast2',
  }) : _auth = auth,
       _httpClient = httpClient ?? http.Client();

  final FirebaseAuth _auth;
  final http.Client _httpClient;
  final String region;

  @override
  Future<List<RacerProfile>> fetchAll({bool activeOnly = true}) async {
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
      '/getRacers',
      <String, String>{'active': activeOnly.toString()},
    );
    final String? token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const RacerRepositoryException('認証トークンを取得できません。');
    }
    final http.Response response = await _httpClient.get(
      uri,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw RacerRepositoryException(_buildErrorMessage(response));
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! List<Object?>) {
      throw const RacerRepositoryException('選手データの形式が不正です。');
    }

    final List<RacerProfile> racers = decoded
        .map(
          (Object? item) => item is Map<Object?, Object?>
              ? RacerProfile.tryParseJson(Map<String, Object?>.from(item))
              : null,
        )
        .whereType<RacerProfile>()
        .toList(growable: false);

    return racers;
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
