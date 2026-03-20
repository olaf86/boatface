import '../domain/quiz_models.dart';

abstract class RacerRepository {
  Future<void> preload();

  List<RacerProfile> requireCachedAll();
}

class RacerRepositoryException implements Exception {
  const RacerRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
