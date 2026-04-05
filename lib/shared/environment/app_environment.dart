import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppEnvironment {
  const AppEnvironment({required this.isProduction});

  final bool isProduction;
  bool get isStaging => !isProduction;
}

final Provider<AppEnvironment> appEnvironmentProvider =
    Provider<AppEnvironment>((Ref ref) {
      return AppEnvironment(isProduction: _isProductionFirebaseProject());
    });

bool _isProductionFirebaseProject() {
  try {
    return Firebase.app().options.projectId == 'boatface-prod';
  } on FirebaseException {
    return false;
  }
}
