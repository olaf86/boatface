# AdMob Prod Setup

This repository keeps only Google test ad IDs in version control.

For production builds:

- Android `App ID` comes from `android/admob.properties`
- iOS `App ID` comes from `ios/Flutter/AdMob-prod.local.xcconfig`
- Rewarded `Ad Unit ID` comes from `--dart-define`

`prod` is fail-fast:

- Android build fails if `ADMOB_ANDROID_APP_ID_PROD` is missing
- Android build fails if `ADMOB_ANDROID_APP_ID_PROD` is missing or still set to Google's test App ID
- iOS build fails if `ADMOB_APPLICATION_ID` is missing or still set to Google's test App ID
- `prod` runtime fails before loading a rewarded ad if the rewarded ad unit ID define is missing or still set to Google's test rewarded ad unit ID

## Local files

Create these files locally and do not commit them:

### `android/admob.properties`

```properties
ADMOB_ANDROID_APP_ID_PROD=ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy
```

### `ios/Flutter/AdMob-prod.local.xcconfig`

```xcconfig
ADMOB_APPLICATION_ID=ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy
```

## Flutter build defines

Pass these for production builds:

```text
--dart-define=ADMOB_ANDROID_REWARDED_AD_UNIT_ID_PROD=ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy
--dart-define=ADMOB_IOS_REWARDED_AD_UNIT_ID_PROD=ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy
```

## Example commands

### Android

```bash
flutter build appbundle \
  --flavor prod \
  --release \
  --dart-define=ADMOB_ANDROID_REWARDED_AD_UNIT_ID_PROD=ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy
```

### iOS

```bash
flutter build ipa \
  --flavor prod \
  --release \
  --dart-define=ADMOB_IOS_REWARDED_AD_UNIT_ID_PROD=ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy
```

`stg` continues to use Google's test IDs from version control.
