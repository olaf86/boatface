import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../quiz/application/racer_master_sync_controller.dart';
import '../../quiz/data/quiz_data_providers.dart';
import '../../quiz/domain/quiz_models.dart';
import '../data/review_repository.dart';
import '../domain/review_models.dart';

final myQuizMistakesProvider =
    FutureProvider.autoDispose<List<ReviewMistakeEntry>>((Ref ref) {
      return ref.watch(reviewRepositoryProvider).fetchMyMistakes();
    });

final reviewRacerLookupProvider =
    Provider.autoDispose<Map<String, RacerProfile>>((Ref ref) {
      ref.watch(racerMasterSyncControllerProvider);
      try {
        final List<RacerProfile> racers = ref
            .read(racerRepositoryProvider)
            .requireCachedAll();
        return <String, RacerProfile>{
          for (final RacerProfile racer in racers) racer.id: racer,
        };
      } catch (_) {
        return const <String, RacerProfile>{};
      }
    });
