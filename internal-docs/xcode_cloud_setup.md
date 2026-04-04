# Xcode Cloud Setup

Use two Xcode Cloud workflows:

- `boatface-stg`
- `boatface-prod`

## Workflow strategy

### `boatface-stg`

- Start condition: branch changes on `develop`
- Scheme: `stg`
- Archive configuration: `Release-stg`
- Distribution: TestFlight internal testers if desired
- Environment variable:

```text
BOATFACE_ENVIRONMENT=stg
```

- Secret environment variable:

```text
IOS_FIREBASE_STG_GOOGLE_SERVICE_INFO_PLIST_BASE64
```

### `boatface-prod`

- Start condition: branch changes on `main`
- Scheme: `prod`
- Archive configuration: `Release-prod`
- Distribution: TestFlight internal testers or App Store flow, depending on your workflow
- Environment variable:

```text
BOATFACE_ENVIRONMENT=prod
```

- Secret environment variables:

```text
IOS_FIREBASE_PROD_GOOGLE_SERVICE_INFO_PLIST_BASE64
IOS_ADMOB_APP_ID_PROD
ADMOB_IOS_REWARDED_AD_UNIT_ID_PROD
```

## How the post-clone script uses these values

`ios/ci_scripts/ci_post_clone.sh` does the following:

- restores the correct Firebase plist for `stg` or `prod`
- creates `ios/Flutter/AdMob-prod.local.xcconfig` for `prod`
- runs `flutter build ios --config-only` with the matching flavor
- passes the rewarded ad unit through `--dart-define` for `prod`
- runs `pod install`

## Notes

- `stg` continues to use the test AdMob IDs already stored in the repository
- `prod` is fail-fast and requires the AdMob values above
- Xcode Cloud distribution settings are configured in Xcode / App Store Connect, not in this repository
