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

Firestore settings in this repo also configure a TTL policy for `quiz_sessions.expiresAt`, so expired quiz sessions are automatically cleaned up after deployment. Deploy Firestore config when you change indexes or field overrides:

```bash
firebase deploy --only firestore --project boatface-stg
firebase deploy --only firestore --project boatface-prod
```

Generated native config files stay out of Git:
- `android/app/src/<env>/google-services.json`
- `ios/Firebase/<env>/GoogleService-Info.plist`

The app initializes Firebase from those native files, so runtime does not depend on checked-in Dart `firebase_options*.dart` files.

## Run Commands
Use the matching flavor.

```bash
flutter run --flavor stg
flutter run --flavor prod
```

For iOS builds, `flutter run --flavor stg` maps to the shared `stg` scheme, and `prod` maps to `prod`.

## App Icon Generation
The app icon source is drawn in Flutter/Dart, then exported to the checked-in iOS and Android icon files.

Regenerate every icon size with:

```bash
./scripts/generate_app_icons.sh
```

This updates:
- `design/generated/app_icon_casual_1024.png`
- `design/generated/app_icon_casual_512.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png`
- `android/app/src/main/res/mipmap-*/ic_launcher.png`

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
- For the GitHub Actions staging secret, set `storeFile=../boat-face-stg-upload-keystore.jks` so it matches the CI restore path from `android/app`.

## CI/CD
### GitHub Actions
GitHub Actions has two responsibilities:
- [`flutter.yml`](.github/workflows/flutter.yml): analyze and test on push / pull request.
- [`android-publish-play.yml`](.github/workflows/android-publish-play.yml): build the `stg` Android App Bundle on `main` pushes and upload it to the Play Console `internal` track.

Android staging releases use an auto-incremented build number:

```text
BUILD_NUMBER = GITHUB_RUN_NUMBER * 100 + GITHUB_RUN_ATTEMPT
```

The Android publish workflow is triggered automatically by pushes to `main`. Manual runs are also available through `workflow_dispatch`.

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
base64 -i /absolute/path/to/boat-face-stg-upload-keystore.jks | pbcopy
```

The Android workflow restores those secrets only inside step-scoped `env` values and removes the generated files in a final cleanup step.

Before the workflow can publish successfully, prepare Google Play Console:
- Create the `dev.asobo.boatface.stg` app.
- Enable Play App Signing.
- Create or confirm the `internal` testing track.
- Create a service account with Play Console release permissions for this app.
- Register internal testers or a tester group.

Store the Play service account JSON as the `PLAY_STG_SERVICE_ACCOUNT_JSON` GitHub secret.

After these secrets are configured, pushing a commit to `main` should trigger [`android-publish-play.yml`](.github/workflows/android-publish-play.yml) automatically. Check the GitHub Actions run named `Android Publish to Play Console` to confirm that:
- `Build staging AAB` succeeds.
- `Upload to Play Console internal testing` succeeds.

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
