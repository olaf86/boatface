#!/bin/sh

set -e

cd "$CI_PRIMARY_REPOSITORY_PATH"

git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin:$HOME/.pub-cache/bin"

flutter precache --ios
flutter pub get
dart pub global activate flutterfire_cli

mkdir -p ios/Firebase/stg

if [ -n "${IOS_FIREBASE_STG_GOOGLE_SERVICE_INFO_PLIST_BASE64:-}" ]; then
  echo "$IOS_FIREBASE_STG_GOOGLE_SERVICE_INFO_PLIST_BASE64" | base64 -D > ios/Firebase/stg/GoogleService-Info.plist
  echo "Restored staging GoogleService-Info.plist"
else
  echo "IOS_FIREBASE_STG_GOOGLE_SERVICE_INFO_PLIST_BASE64 is not set"
  exit 1
fi

BUILD_NUMBER="${CI_BUILD_NUMBER:-1}"
flutter build ios --config-only --release --flavor stg --target lib/main_stg.dart --build-number="$BUILD_NUMBER"

HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods

cd ios
# GoogleService-Info.plist must remain in the workspace after this script ends
# because the subsequent Xcode archive step copies it into the app bundle.
pod install

exit 0
