# UMP Debug Geography

On `stg`, UMP geography can be overridden with `dart-define`.
It is always disabled on `prod`.

## Available Defines

- `UMP_DEBUG_GEOGRAPHY=eea`
  - Forces the EEA consent flow
- `UMP_DEBUG_GEOGRAPHY=us_state`
  - Forces the regulated US state consent flow
- `UMP_DEBUG_GEOGRAPHY=other`
  - Forces a non-regulated region
- `UMP_TEST_DEVICE_IDS=<id1,id2,...>`
  - Optionally passes one or more UMP debug test device IDs as a comma-separated list

If `UMP_DEBUG_GEOGRAPHY` is omitted, debug geography is disabled.

## Example Commands

```bash
flutter run \
  --flavor stg \
  -d <device-id> \
  --dart-define=UMP_DEBUG_GEOGRAPHY=eea
```

```bash
flutter run \
  --flavor stg \
  -d <device-id> \
  --dart-define=UMP_DEBUG_GEOGRAPHY=us_state \
  --dart-define=UMP_TEST_DEVICE_IDS=<ump-test-device-id>
```

## Verification Steps

1. Launch `stg` on a real device.
2. If needed, uninstall the app first so the initial UMP flow is easier to verify.
3. Confirm that a UMP message appears right after the Home screen is shown.
4. Open `Settings > 広告とプライバシー`.
5. Confirm that `UMP デバッグ地域` matches the injected value.
6. If `広告の設定を見直す` is shown, tap it and confirm that the Privacy Options form can be reopened.

## Expected Behavior

- `eea`
  - The EEA consent message should appear.
- `us_state`
  - The regulated US state message should appear.
- `other`
  - Region-specific regulatory messages should usually not appear.
- On iOS, if the AdMob IDFA explainer message is published
  - The UMP flow should also surface the IDFA explainer and ATT prompt when applicable.

## Notes

- Debug geography is only active on `stg`.
- `prod` ignores both `UMP_DEBUG_GEOGRAPHY` and `UMP_TEST_DEVICE_IDS`.
- UMP debug test device IDs are separate from AdMob ad test device registration.
