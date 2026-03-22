import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class FirebaseFunctionsClient {
  FirebaseFunctionsClient({
    required FirebaseAuth auth,
    http.Client? httpClient,
    this.region = 'asia-northeast2',
  }) : _auth = auth,
       _httpClient = httpClient ?? http.Client();

  final FirebaseAuth _auth;
  final http.Client _httpClient;
  final String region;

  Future<Map<String, Object?>> getJsonObject(
    String path, {
    Map<String, String>? queryParameters,
    required String defaultErrorMessage,
  }) async {
    final http.Response response = await get(
      path,
      queryParameters: queryParameters,
      acceptHeader: 'application/json',
    );
    return _decodeJsonObject(
      response,
      defaultErrorMessage: defaultErrorMessage,
      invalidFormatMessage: '$defaultErrorMessage レスポンス形式が不正です。',
    );
  }

  Future<Map<String, Object?>> postJsonObject(
    String path, {
    Map<String, Object?>? body,
    required String defaultErrorMessage,
  }) async {
    final http.Response response = await post(
      path,
      body: body,
      acceptHeader: 'application/json',
    );
    return _decodeJsonObject(
      response,
      defaultErrorMessage: defaultErrorMessage,
      invalidFormatMessage: '$defaultErrorMessage レスポンス形式が不正です。',
    );
  }

  Future<List<int>> getBytes(
    String path, {
    Map<String, String>? queryParameters,
    required String defaultErrorMessage,
  }) async {
    final http.Response response = await get(
      path,
      queryParameters: queryParameters,
      acceptHeader: 'application/zip',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FirebaseFunctionsClientException(
        _buildErrorMessage(response, defaultErrorMessage: defaultErrorMessage),
      );
    }

    return response.bodyBytes;
  }

  Future<http.Response> get(
    String path, {
    Map<String, String>? queryParameters,
    required String acceptHeader,
  }) async {
    return _send(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
      acceptHeader: acceptHeader,
    );
  }

  Future<http.Response> post(
    String path, {
    Map<String, Object?>? body,
    required String acceptHeader,
  }) async {
    return _send(
      method: 'POST',
      path: path,
      acceptHeader: acceptHeader,
      body: body == null ? null : jsonEncode(body),
    );
  }

  Future<http.Response> _send({
    required String method,
    required String path,
    required String acceptHeader,
    Map<String, String>? queryParameters,
    String? body,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw const FirebaseFunctionsClientException('ログイン状態を確認できません。');
    }

    final String projectId = Firebase.app().options.projectId;
    if (projectId.isEmpty) {
      throw const FirebaseFunctionsClientException(
        'Firebase projectId を取得できません。',
      );
    }

    final String? token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const FirebaseFunctionsClientException('認証トークンを取得できません。');
    }

    final Uri uri = Uri.https(
      '$region-$projectId.cloudfunctions.net',
      path,
      queryParameters,
    );

    return _httpClient
        .send(
          http.Request(method, uri)
            ..headers.addAll(<String, String>{
              'Authorization': 'Bearer $token',
              'Accept': acceptHeader,
              if (body != null) 'Content-Type': 'application/json',
            })
            ..body = body ?? '',
        )
        .then(http.Response.fromStream);
  }

  Map<String, Object?> _decodeJsonObject(
    http.Response response, {
    required String defaultErrorMessage,
    required String invalidFormatMessage,
  }) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FirebaseFunctionsClientException(
        _buildErrorMessage(response, defaultErrorMessage: defaultErrorMessage),
      );
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<Object?, Object?>) {
      throw FirebaseFunctionsClientException(invalidFormatMessage);
    }

    return Map<String, Object?>.from(decoded);
  }

  String _buildErrorMessage(
    http.Response response, {
    required String defaultErrorMessage,
  }) {
    try {
      final Object? decoded = jsonDecode(response.body);
      if (decoded is Map<String, Object?>) {
        final Object? message = decoded['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'FirebaseFunctionsClient: failed to parse error response: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    return '$defaultErrorMessage (HTTP ${response.statusCode})';
  }
}

class FirebaseFunctionsClientException implements Exception {
  const FirebaseFunctionsClientException(this.message);

  final String message;

  @override
  String toString() => message;
}
