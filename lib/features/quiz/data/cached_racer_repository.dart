import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/quiz_models.dart';
import 'racer_api_client.dart';
import 'racer_repository.dart';

class CachedRacerRepository implements RacerRepository {
  CachedRacerRepository({
    required RacerApiClient apiClient,
    this.cacheTtl = const Duration(hours: 12),
  }) : _apiClient = apiClient;

  static const String _cacheKey = 'quiz_racer_cache_v1';
  static const int _minimumRacerCount = 4;

  final RacerApiClient _apiClient;
  final Duration cacheTtl;

  List<RacerProfile>? _memoryCache;
  DateTime? _memoryFetchedAt;
  Future<void>? _ongoingLoad;
  Future<void>? _backgroundRefresh;

  @override
  Future<void> preload() {
    final Future<void>? ongoing = _ongoingLoad;
    if (ongoing != null) {
      return ongoing;
    }

    final Future<void> nextLoad = _preloadImpl();
    _ongoingLoad = nextLoad;
    return nextLoad.whenComplete(() {
      if (identical(_ongoingLoad, nextLoad)) {
        _ongoingLoad = null;
      }
    });
  }

  @override
  List<RacerProfile> requireCachedAll() {
    final List<RacerProfile>? cache = _memoryCache;
    if (cache == null || cache.length < _minimumRacerCount) {
      throw const RacerRepositoryException('選手データがまだ読み込まれていません。');
    }
    return cache;
  }

  Future<void> _preloadImpl() async {
    if (_hasUsableMemoryCache()) {
      if (_isExpired(_memoryFetchedAt)) {
        _scheduleBackgroundRefresh();
      }
      return;
    }

    final _RacerCacheSnapshot? diskSnapshot = await _readCacheSnapshot();
    if (diskSnapshot != null) {
      _applySnapshot(diskSnapshot);
      if (_isExpired(diskSnapshot.fetchedAt)) {
        _scheduleBackgroundRefresh();
      }
      return;
    }

    await _refreshFromRemote();
  }

  bool _hasUsableMemoryCache() {
    final List<RacerProfile>? cache = _memoryCache;
    return cache != null && cache.length >= _minimumRacerCount;
  }

  bool _isExpired(DateTime? fetchedAt) {
    if (fetchedAt == null) {
      return true;
    }
    return DateTime.now().toUtc().difference(fetchedAt) >= cacheTtl;
  }

  void _scheduleBackgroundRefresh() {
    _backgroundRefresh ??= _refreshFromRemote()
        .catchError((_) {
          return;
        })
        .whenComplete(() {
          _backgroundRefresh = null;
        });
  }

  Future<void> _refreshFromRemote() async {
    final List<RacerProfile> racers = await _apiClient.fetchAll(
      activeOnly: true,
    );
    if (racers.length < _minimumRacerCount) {
      throw const RacerRepositoryException('クイズ開始に必要な選手データが不足しています。');
    }

    final _RacerCacheSnapshot snapshot = _RacerCacheSnapshot(
      fetchedAt: DateTime.now().toUtc(),
      racers: racers,
    );
    _applySnapshot(snapshot);
    await _writeCacheSnapshot(snapshot);
  }

  void _applySnapshot(_RacerCacheSnapshot snapshot) {
    if (snapshot.racers.length < _minimumRacerCount) {
      throw const RacerRepositoryException('クイズ開始に必要な選手データが不足しています。');
    }
    _memoryCache = snapshot.racers;
    _memoryFetchedAt = snapshot.fetchedAt;
  }

  Future<_RacerCacheSnapshot?> _readCacheSnapshot() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? raw = preferences.getString(_cacheKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        return null;
      }

      final Object? fetchedAtValue = decoded['fetchedAt'];
      final Object? racersValue = decoded['racers'];
      if (fetchedAtValue is! String || racersValue is! List<Object?>) {
        return null;
      }

      final DateTime? fetchedAt = DateTime.tryParse(fetchedAtValue);
      if (fetchedAt == null) {
        return null;
      }

      final List<RacerProfile> racers = racersValue
          .map(
            (Object? item) => item is Map<Object?, Object?>
                ? RacerProfile.tryParseJson(Map<String, Object?>.from(item))
                : null,
          )
          .whereType<RacerProfile>()
          .toList(growable: false);
      if (racers.length < _minimumRacerCount) {
        return null;
      }

      return _RacerCacheSnapshot(fetchedAt: fetchedAt.toUtc(), racers: racers);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCacheSnapshot(_RacerCacheSnapshot snapshot) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _cacheKey,
      jsonEncode(<String, Object?>{
        'fetchedAt': snapshot.fetchedAt.toUtc().toIso8601String(),
        'racers': snapshot.racers
            .map((RacerProfile racer) => racer.toJson())
            .toList(),
      }),
    );
  }
}

class _RacerCacheSnapshot {
  const _RacerCacheSnapshot({required this.fetchedAt, required this.racers});

  final DateTime fetchedAt;
  final List<RacerProfile> racers;
}
