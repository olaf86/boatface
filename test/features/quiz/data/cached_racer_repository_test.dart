import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boatface/features/quiz/data/cached_racer_repository.dart';
import 'package:boatface/features/quiz/data/racer_api_client.dart';
import 'package:boatface/features/quiz/domain/quiz_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CachedRacerRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('preload fetches remote data and stores it in cache', () async {
      final _FakeRacerApiClient apiClient = _FakeRacerApiClient(
        racers: _buildRacers(prefix: 'remote'),
      );
      final CachedRacerRepository repository = CachedRacerRepository(
        apiClient: apiClient,
      );

      await repository.preload();

      expect(apiClient.fetchCount, 1);
      expect(repository.requireCachedAll().length, 4);

      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final String? rawCache = preferences.getString('quiz_racer_cache_v1');
      expect(rawCache, isNotNull);
      expect(rawCache, contains('remote-racer-0'));
    });

    test('preload restores cached data without hitting remote', () async {
      final List<RacerProfile> cachedRacers = _buildRacers(prefix: 'disk');
      SharedPreferences.setMockInitialValues(<String, Object>{
        'quiz_racer_cache_v1': jsonEncode(<String, Object?>{
          'fetchedAt': DateTime.now().toUtc().toIso8601String(),
          'racers': cachedRacers
              .map((RacerProfile racer) => racer.toJson())
              .toList(growable: false),
        }),
      });

      final _FakeRacerApiClient apiClient = _FakeRacerApiClient(
        racers: _buildRacers(prefix: 'remote'),
      );
      final CachedRacerRepository repository = CachedRacerRepository(
        apiClient: apiClient,
      );

      await repository.preload();

      expect(apiClient.fetchCount, 0);
      expect(
        repository.requireCachedAll().map((RacerProfile racer) => racer.id),
        cachedRacers.map((RacerProfile racer) => racer.id),
      );
    });

    test(
      'stale cache is used immediately and refreshed in background',
      () async {
        final List<RacerProfile> staleRacers = _buildRacers(prefix: 'stale');
        SharedPreferences.setMockInitialValues(<String, Object>{
          'quiz_racer_cache_v1': jsonEncode(<String, Object?>{
            'fetchedAt': DateTime.now()
                .toUtc()
                .subtract(const Duration(days: 2))
                .toIso8601String(),
            'racers': staleRacers
                .map((RacerProfile racer) => racer.toJson())
                .toList(growable: false),
          }),
        });

        final _FakeRacerApiClient apiClient = _FakeRacerApiClient(
          racers: _buildRacers(prefix: 'fresh'),
        );
        final CachedRacerRepository repository = CachedRacerRepository(
          apiClient: apiClient,
          cacheTtl: const Duration(hours: 1),
        );

        await repository.preload();
        expect(repository.requireCachedAll().first.id, staleRacers.first.id);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(apiClient.fetchCount, 1);
        expect(repository.requireCachedAll().first.id, 'fresh-racer-0');
      },
    );
  });
}

class _FakeRacerApiClient implements RacerApiClient {
  _FakeRacerApiClient({required this.racers});

  final List<RacerProfile> racers;
  int fetchCount = 0;

  @override
  Future<List<RacerProfile>> fetchAll({bool activeOnly = true}) async {
    fetchCount += 1;
    return racers;
  }
}

List<RacerProfile> _buildRacers({required String prefix}) {
  final DateTime updatedAt = DateTime.utc(2026, 3, 20);
  return List<RacerProfile>.generate(4, (int index) {
    return RacerProfile(
      id: '$prefix-racer-$index',
      name: '選手$index',
      registrationNumber: 1000 + index,
      imageUrl: 'https://example.com/$prefix/$index.jpg',
      imageSource: prefix,
      updatedAt: updatedAt,
    );
  });
}
