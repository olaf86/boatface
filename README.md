# BoatFace

BoatFace is a quiz app for learning and recognizing professional boat racers by face, name, and registration number.

## MVP Specification
- [internal-docs/mvp_spec.md](internal-docs/mvp_spec.md)

## Environments
BoatFace uses separate Flutter flavors and Xcode schemes for staging and production.

| Environment | Android flavor | iOS scheme | Package / bundle ID | Firebase project default |
| --- | --- | --- | --- | --- |
| `stg` | `stg` | `stg` | `dev.asobo.boatface.stg` | `boatface-stg` |
| `prod` | `prod` | `prod` | `dev.asobo.boatface` | `boatface-prod` |

## Local Setup
Install the required tooling first.

```bash
brew install firebase-cli ruby
gem install xcodeproj
dart pub global activate flutterfire_cli
flutter pub get
```

If your Firebase project IDs differ from the defaults above, set these environment variables before generating config:

```bash
export BOATFACE_FIREBASE_STG_PROJECT_ID=your-stg-project-id
export BOATFACE_FIREBASE_PROD_PROJECT_ID=your-prod-project-id
```

Generate Firebase files for the environment you want to run:

```bash
./scripts/configure_firebase.sh stg
./scripts/configure_firebase.sh prod
```

Generated native config files stay out of Git:
- `android/app/src/<env>/google-services.json`
- `ios/Firebase/<env>/GoogleService-Info.plist`

The app initializes Firebase from those native files, so runtime does not depend on checked-in Dart `firebase_options*.dart` files.

## Run Commands
Use the matching flavor with the shared `lib/main.dart` entrypoint.

```bash
flutter run --flavor stg -t lib/main.dart
flutter run --flavor prod -t lib/main.dart
```

For iOS builds, `flutter run --flavor stg` maps to the shared `stg` scheme, and `prod` maps to `prod`.

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
- `android/key.properties` is Git-ignored.
- Release variants use the configured release keystore only when this file exists.
- Without `android/key.properties`, release builds fall back to unsigned behavior for local development.

## CI/CD
### GitHub Actions
GitHub Actions has two responsibilities:
- [`flutter.yml`](.github/workflows/flutter.yml): analyze and test on push / pull request.
- [`android-publish-play.yml`](.github/workflows/android-publish-play.yml): build the `stg` Android App Bundle on `main` pushes and upload it to the Play Console `internal` track.

Android staging releases use an auto-incremented build number:

```text
BUILD_NUMBER = GITHUB_RUN_NUMBER * 100 + GITHUB_RUN_ATTEMPT
```

Configure these GitHub repository secrets for Android staging delivery:
- `ANDROID_STG_GOOGLE_SERVICES_JSON_BASE64`
- `ANDROID_STG_UPLOAD_KEYSTORE_BASE64`
- `ANDROID_STG_UPLOAD_KEYSTORE_PASSWORD`
- `ANDROID_STG_UPLOAD_KEY_ALIAS`
- `ANDROID_STG_UPLOAD_KEY_PASSWORD`
- `PLAY_STG_SERVICE_ACCOUNT_JSON`

Base64 encode file-based secrets before registering them:

```bash
base64 -i android/app/src/stg/google-services.json | pbcopy
base64 -i /absolute/path/to/boatface_stg_upload.jks | pbcopy
```

The Android workflow restores those secrets only inside step-scoped `env` values and removes the generated files in a final cleanup step.

### Xcode Cloud
Xcode Cloud is expected to handle iOS staging archives from `main` and deploy them to TestFlight.

This repository includes [`ios/ci_scripts/ci_post_clone.sh`](ios/ci_scripts/ci_post_clone.sh) for Xcode Cloud. The script:
- installs Flutter,
- restores the staging `GoogleService-Info.plist` from a secret,
- runs `flutter build ios --config-only --release --flavor stg`,
- installs CocoaPods dependencies.

Configure the Xcode Cloud workflow with:
- Start condition: branch changes on `main`
- Scheme: `stg`
- Archive action enabled
- TestFlight distribution enabled
- Environment variable: `IOS_FIREBASE_STG_GOOGLE_SERVICE_INFO_PLIST_BASE64` as a secret

Base64 encode the iOS Firebase plist before adding it to Xcode Cloud:

```bash
base64 -i ios/Firebase/stg/GoogleService-Info.plist | pbcopy
```

Xcode Cloud provides `CI_BUILD_NUMBER`; the post-clone script forwards that value to Flutter so iOS build numbers also auto-increment.
The restored plist is intentionally left in the workspace because the later Xcode archive step still needs to copy it into the app bundle. The runner itself is ephemeral.
