import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import 'cached_racer_repository.dart';
import 'racer_api_client.dart';
import 'racer_repository.dart';

final Provider<RacerApiClient> racerApiClientProvider =
    Provider<RacerApiClient>((Ref ref) {
      return FirebaseRacerApiClient(auth: ref.watch(firebaseAuthProvider));
    });

final Provider<RacerRepository> racerRepositoryProvider =
    Provider<RacerRepository>((Ref ref) {
      return CachedRacerRepository(
        apiClient: ref.watch(racerApiClientProvider),
      );
    });
