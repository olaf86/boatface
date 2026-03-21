# BoatFace

BoatFace is a quiz app for learning and recognizing professional boat racers by face, name, and registration number.

## MVP Specification
- [internal-docs/mvp_spec.md](internal-docs/mvp_spec.md)

## Firebase Environments
BoatFace uses separate Flutter flavors / Xcode schemes for staging and production.

| Environment | Android flavor | iOS scheme | Package / bundle ID | Firebase project default |
| --- | --- | --- | --- | --- |
| `stg` | `stg` | `stg` | `dev.asobo.boatface.stg` | `boatface-stg` |
| `prod` | `prod` | `prod` | `dev.asobo.boatface` | `boatface-prod` |

If your Firebase project IDs differ, set `BOATFACE_FIREBASE_STG_PROJECT_ID` or `BOATFACE_FIREBASE_PROD_PROJECT_ID` before running the configure script.

## Local Setup
Install the required tooling first.

```bash
brew install firebase-cli ruby
gem install xcodeproj
dart pub global activate flutterfire_cli
flutter pub get
```

Generate Firebase files for the environment you want to run.

```bash
./scripts/configure_firebase.sh stg
./scripts/configure_firebase.sh prod
```

Required generated files stay out of Git:
- `android/app/src/<env>/google-services.json`
- `ios/Firebase/<env>/GoogleService-Info.plist`

Notes:
- The app entrypoints now initialize Firebase from the native Android/iOS config files, so `flutter analyze` does not depend on local Dart `firebase_options*.dart` files.
- `flutterfire` may still emit temporary Dart config files during setup, but they are not required by the app runtime.

## Run Commands
Use the matching entrypoint and flavor / scheme.

```bash
flutter run --flavor stg
flutter run --flavor prod
```

For iOS builds, `flutter run --flavor stg` maps to the shared `stg` Xcode scheme, and `prod` maps to `prod`.

## Android Release Signing
`android/app/build.gradle.kts` reads release signing settings from `android/key.properties`.

Create `android/key.properties` locally with:

```properties
storeFile=/absolute/path/to/release-keystore.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=YOUR_KEY_ALIAS
keyPassword=YOUR_KEY_PASSWORD
```

Notes:
- `android/key.properties` is Git-ignored
- release variants use the configured release keystore only when this file exists
- without `android/key.properties`, `signingReport` will continue to show only debug signing

## CI
GitHub Actions regenerates Firebase config during CI instead of committing generated files. Configure these repository settings:

- Secret: `FIREBASE_TOKEN`
- Variable: `BOATFACE_FIREBASE_STG_PROJECT_ID` if not `boatface-stg`
- Variable: `BOATFACE_FIREBASE_PROD_PROJECT_ID` if not `boatface-prod`
