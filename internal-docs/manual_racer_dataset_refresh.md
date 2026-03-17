# Manual Racer Dataset Refresh

## Purpose

Use this procedure when the scheduled racer dataset refresh fails or when the current period dataset must be refreshed manually.

## Automatic Refresh

- Schedule: `JST 00:00` on `January 1` and `July 1`
- Trigger: Firebase scheduled function `refreshRacerDatasetOnSchedule`
- Behavior:
  - imports the current period roster dataset
  - updates `app_config/racer_dataset_state.currentDatasetId`
  - backfills image metadata from Storage

## Prerequisites

- Firebase project is selected
- ADC is available when running locally
- `DATASET_REFRESH_TOKEN` secret is set when using the manual HTTP function

## Easiest Manual Refresh

Run one command from [`functions/`](/Users/olaf/Repos/boatface/functions):

```bash
npm run refresh:racers -- --dataset 2026-H1 --project boatface-stg --bucket boatface-stg.firebasestorage.app
```

Notes:
- omit `--dataset` to infer the current JST period automatically
- use `--no-clear` only when a full rebuild is intentionally avoided
- use `--skip-images` only when image backfill must be delayed

## Manual HTTP Trigger

Send a POST request to the deployed function with the admin token.

```bash
curl -X POST \
  "https://asia-northeast2-boatface-stg.cloudfunctions.net/runRacerDatasetRefresh" \
  -H "Content-Type: application/json" \
  -H "X-Boatface-Admin-Token: $DATASET_REFRESH_TOKEN" \
  -d '{"datasetId":"2026-H1","syncImages":true}'
```

Request body:
- `datasetId`: optional, defaults to current JST period
- `syncImages`: optional, defaults to `true`
- `clear`: optional, defaults to `true`
- `setCurrent`: optional, defaults to `true`

## Validation Checklist

After refresh, confirm:

1. `racer_datasets/<datasetId>` exists
2. `app_config/racer_dataset_state.currentDatasetId` is updated
3. `racer_datasets/<datasetId>/racers` count matches roster count
4. `imageStoragePath` is filled for racer documents

## Recovery Notes

- If the import succeeds and image sync fails, rerun with the same `datasetId`
- Existing Storage objects are reused; the image sync step is resume-safe
- `fallbackDatasetId` is preserved by the import flow, so the previous period remains available during recovery
