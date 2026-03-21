import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import 'cached_racer_repository.dart';
import 'racer_api_client.dart';
import 'racer_master_local_store.dart';
import 'racer_repository.dart';

final Provider<RacerMasterRemoteDataSource>
racerMasterRemoteDataSourceProvider = Provider<RacerMasterRemoteDataSource>((
  Ref ref,
) {
  return FirebaseRacerMasterRemoteDataSource(
    auth: ref.watch(firebaseAuthProvider),
  );
});

final Provider<RacerMasterLocalStore> racerMasterLocalStoreProvider =
    Provider<RacerMasterLocalStore>((Ref ref) {
      return FileRacerMasterLocalStore();
    });

final Provider<RacerRepository> racerRepositoryProvider =
    Provider<RacerRepository>((Ref ref) {
      return CachedRacerRepository(
        remoteDataSource: ref.watch(racerMasterRemoteDataSourceProvider),
        localStore: ref.watch(racerMasterLocalStoreProvider),
      );
    });
