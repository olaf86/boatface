#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/configure_firebase.sh <stg|prod>

Environment overrides:
  BOATFACE_FIREBASE_STG_PROJECT_ID
  BOATFACE_FIREBASE_PROD_PROJECT_ID
EOF
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

for command in firebase flutterfire; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "error: $command is not installed or not on PATH" >&2
    exit 1
  fi
done

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
environment="$1"

case "$environment" in
  stg)
    project_id="${BOATFACE_FIREBASE_STG_PROJECT_ID:-boatface-stg}"
    android_package="dev.asobo.boatface.stg"
    ios_bundle_id="dev.asobo.boatface.stg"
    dart_out="lib/firebase_options_stg.dart"
    android_out="android/app/src/stg/google-services.json"
    ios_out="ios/Firebase/stg/GoogleService-Info.plist"
    ios_build_configs=("Debug-stg" "Profile-stg" "Release-stg")
    ;;
  prod)
    project_id="${BOATFACE_FIREBASE_PROD_PROJECT_ID:-boatface-prod}"
    android_package="dev.asobo.boatface"
    ios_bundle_id="dev.asobo.boatface"
    dart_out="lib/firebase_options_prod.dart"
    android_out="android/app/src/prod/google-services.json"
    ios_out="ios/Firebase/prod/GoogleService-Info.plist"
    ios_build_configs=("Debug-prod" "Profile-prod" "Release-prod")
    ;;
  *)
    usage
    exit 1
    ;;
esac

mkdir -p \
  "$root_dir/$(dirname "$android_out")" \
  "$root_dir/$(dirname "$ios_out")"

cd "$root_dir"

common_args=(
  configure
  --yes
  --project="$project_id"
  --out="$dart_out"
  --overwrite-firebase-options
)

flutterfire "${common_args[@]}" \
  --platforms=android \
  --android-package-name="$android_package" \
  --android-out="$android_out"

for build_config in "${ios_build_configs[@]}"; do
  flutterfire "${common_args[@]}" \
    --platforms=ios \
    --ios-bundle-id="$ios_bundle_id" \
    --ios-build-config="$build_config" \
    --ios-out="$ios_out"
done

echo "Generated Firebase config for $environment:"
echo "  Dart:    $dart_out"
echo "  Android: $android_out"
echo "  iOS:     $ios_out"
