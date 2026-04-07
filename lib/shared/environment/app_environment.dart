import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum UmpDebugGeography { disabled, eea, regulatedUsState, other }

class AppEnvironment {
  const AppEnvironment({
    required this.isProduction,
    this.umpDebugGeography = UmpDebugGeography.disabled,
    this.umpTestDeviceIds = const <String>[],
  });

  final bool isProduction;
  final UmpDebugGeography umpDebugGeography;
  final List<String> umpTestDeviceIds;
  bool get isStaging => !isProduction;
  bool get usesUmpDebugSettings =>
      isStaging &&
      (umpDebugGeography != UmpDebugGeography.disabled ||
          umpTestDeviceIds.isNotEmpty);
}

final Provider<AppEnvironment> appEnvironmentProvider =
    Provider<AppEnvironment>((Ref ref) {
      final bool isProduction = _isProductionFirebaseProject();
      return AppEnvironment(
        isProduction: isProduction,
        umpDebugGeography: isProduction
            ? UmpDebugGeography.disabled
            : _umpDebugGeographyFromEnvironment(),
        umpTestDeviceIds: isProduction
            ? const <String>[]
            : _umpTestDeviceIdsFromEnvironment(),
      );
    });

bool _isProductionFirebaseProject() {
  try {
    return Firebase.app().options.projectId == 'boatface-prod';
  } on FirebaseException {
    return false;
  }
}

UmpDebugGeography _umpDebugGeographyFromEnvironment() {
  const String rawValue = String.fromEnvironment(
    'UMP_DEBUG_GEOGRAPHY',
    defaultValue: '',
  );
  return switch (rawValue.trim().toLowerCase()) {
    'eea' => UmpDebugGeography.eea,
    'regulated_us_state' => UmpDebugGeography.regulatedUsState,
    'us_state' => UmpDebugGeography.regulatedUsState,
    'other' => UmpDebugGeography.other,
    _ => UmpDebugGeography.disabled,
  };
}

List<String> _umpTestDeviceIdsFromEnvironment() {
  const String rawValue = String.fromEnvironment(
    'UMP_TEST_DEVICE_IDS',
    defaultValue: '',
  );
  if (rawValue.trim().isEmpty) {
    return const <String>[];
  }
  return rawValue
      .split(',')
      .map((String value) => value.trim())
      .where((String value) => value.isNotEmpty)
      .toList(growable: false);
}
