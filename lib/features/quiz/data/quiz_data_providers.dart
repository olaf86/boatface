import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mock_racer_repository.dart';

final Provider<MockRacerRepository> mockRacerRepositoryProvider =
    Provider<MockRacerRepository>((Ref ref) {
      return MockRacerRepository();
    });
