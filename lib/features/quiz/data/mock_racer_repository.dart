import '../domain/quiz_models.dart';
import 'racer_repository.dart';

class MockRacerRepository implements RacerRepository {
  List<RacerProfile>? _cache;

  @override
  Future<void> initialize() async {
    fetchAll();
  }

  @override
  List<RacerProfile> requireCachedAll() => fetchAll();

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
        isActive: true,
      );
    });

    _cache = racers;
    return racers;
  }
}
