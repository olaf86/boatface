Never main() {
  throw UnsupportedError(
    'Use an environment-specific entrypoint: '
    '`flutter run --flavor stg -t lib/main_stg.dart` or '
    '`flutter run --flavor prod -t lib/main_prod.dart`.',
  );
}
