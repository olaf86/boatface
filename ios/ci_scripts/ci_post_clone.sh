#!/bin/sh

set -eu

cd "$CI_PRIMARY_REPOSITORY_PATH"

git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin:$HOME/.pub-cache/bin"

flutter precache --ios
flutter pub get
dart pub global activate flutterfire_cli

ENVIRONMENT="${BOATFACE_ENVIRONMENT:-stg}"
BUILD_NUMBER="${CI_BUILD_NUMBER:-1}"

case "$ENVIRONMENT" in
  stg)
    FIREBASE_DIR="ios/Firebase/stg"
    FIREBASE_SECRET_NAME="IOS_FIREBASE_STG_GOOGLE_SERVICE_INFO_PLIST_BASE64"
    FIREBASE_SECRET_VALUE="${IOS_FIREBASE_STG_GOOGLE_SERVICE_INFO_PLIST_BASE64:-}"
    FLUTTER_FLAVOR="stg"
    ;;
  prod)
    FIREBASE_DIR="ios/Firebase/prod"
    FIREBASE_SECRET_NAME="IOS_FIREBASE_PROD_GOOGLE_SERVICE_INFO_PLIST_BASE64"
    FIREBASE_SECRET_VALUE="${IOS_FIREBASE_PROD_GOOGLE_SERVICE_INFO_PLIST_BASE64:-}"
    FLUTTER_FLAVOR="prod"
    ;;
  *)
    echo "Unsupported BOATFACE_ENVIRONMENT: $ENVIRONMENT" >&2
    exit 1
    ;;
esac

mkdir -p "$FIREBASE_DIR"

if [ -z "$FIREBASE_SECRET_VALUE" ]; then
  echo "$FIREBASE_SECRET_NAME is not set" >&2
  exit 1
fi

echo "$FIREBASE_SECRET_VALUE" | base64 -D > "$FIREBASE_DIR/GoogleService-Info.plist"
echo "Restored $ENVIRONMENT GoogleService-Info.plist"

if [ "$ENVIRONMENT" = "prod" ]; then
  if [ -z "${IOS_ADMOB_APP_ID_PROD:-}" ]; then
    echo "IOS_ADMOB_APP_ID_PROD is not set" >&2
    exit 1
  fi
  if [ -z "${ADMOB_IOS_REWARDED_AD_UNIT_ID_PROD:-}" ]; then
    echo "ADMOB_IOS_REWARDED_AD_UNIT_ID_PROD is not set" >&2
    exit 1
  fi

  cat > ios/Flutter/AdMob-prod.local.xcconfig <<EOF
ADMOB_APPLICATION_ID=${IOS_ADMOB_APP_ID_PROD}
EOF

  flutter build ios \
    --config-only \
    --release \
    --flavor "$FLUTTER_FLAVOR" \
    --build-number="$BUILD_NUMBER" \
    --dart-define=ADMOB_IOS_REWARDED_AD_UNIT_ID_PROD="${ADMOB_IOS_REWARDED_AD_UNIT_ID_PROD}"
else
  flutter build ios \
    --config-only \
    --release \
    --flavor "$FLUTTER_FLAVOR" \
    --build-number="$BUILD_NUMBER"
fi

HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods

cd ios
# GoogleService-Info.plist and prod AdMob xcconfig must remain in the workspace
# after this script ends because subsequent Xcode Cloud steps use them.
pod install

exit 0
