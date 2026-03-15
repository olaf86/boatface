import '../domain/quiz_models.dart';

class MockRacerRepository {
  List<RacerProfile>? _cache;

  List<RacerProfile> fetchAll() {
    if (_cache != null) {
      return _cache!;
    }

    final DateTime now = DateTime.now().toUtc();
    final List<RacerProfile> racers = List<RacerProfile>.generate(4096, (
      int i,
    ) {
      final int registration = 1000 + i;
      return RacerProfile(
        id: 'racer-${registration.toString()}',
        name: '選手${registration.toString()}',
        registrationNumber: registration,
        imageUrl: 'https://example.com/mock/racer/$registration.jpg',
        imageSource: 'mock-dataset',
        updatedAt: now,
      );
    });

    _cache = racers;
    return racers;
  }
}
