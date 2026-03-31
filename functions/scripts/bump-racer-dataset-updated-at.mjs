#!/usr/bin/env node

import {applicationDefault, initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {pathToFileURL} from "node:url";

const racerDatasetStateDocPath = "app_config/racer_dataset_state";

function parseArgs(argv) {
  const options = {
    projectId: process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT ?? "",
    datasetIds: [],
    includeFallback: true,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];

    if (arg === "--project") {
      options.projectId = (argv[index + 1] ?? "").trim();
      index += 1;
      continue;
    }
    if (arg === "--dataset") {
      const datasetId = (argv[index + 1] ?? "").trim();
      if (datasetId) {
        options.datasetIds.push(datasetId);
      }
      index += 1;
      continue;
    }
    if (arg === "--current-only") {
      options.includeFallback = false;
      continue;
    }

    throw new Error(`Unknown argument: ${arg}`);
  }

  if (!options.projectId) {
    throw new Error("--project is required or GCLOUD_PROJECT must be set");
  }

  return options;
}

async function resolveDatasetIds(db, options) {
  if (options.datasetIds.length > 0) {
    return Array.from(new Set(options.datasetIds));
  }

  const stateSnapshot = await db.doc(racerDatasetStateDocPath).get();
  if (!stateSnapshot.exists) {
    throw new Error("racer_dataset_state_missing");
  }

  const datasetIds = [];
  const currentDatasetId = stateSnapshot.get("currentDatasetId");
  const fallbackDatasetId = stateSnapshot.get("fallbackDatasetId");

  if (typeof currentDatasetId === "string" && currentDatasetId.trim()) {
    datasetIds.push(currentDatasetId.trim());
  }
  if (
    options.includeFallback &&
    typeof fallbackDatasetId === "string" &&
    fallbackDatasetId.trim()
  ) {
    datasetIds.push(fallbackDatasetId.trim());
  }

  return Array.from(new Set(datasetIds));
}

export async function main(argv = process.argv.slice(2)) {
  const options = parseArgs(argv);
  const app = initializeApp(
    {
      credential: applicationDefault(),
      projectId: options.projectId,
    },
    `bump-racer-dataset-${Date.now()}`,
  );
  const db = getFirestore(app);
  const datasetIds = await resolveDatasetIds(db, options);

  if (datasetIds.length == 0) {
    throw new Error("no_dataset_ids_resolved");
  }

  const batch = db.batch();
  for (const datasetId of datasetIds) {
    batch.set(
      db.collection("racer_datasets").doc(datasetId),
      {
        datasetUpdatedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  }
  await batch.commit();

  console.log(JSON.stringify({
    projectId: options.projectId,
    datasetIds,
    updatedCount: datasetIds.length,
  }));
}

const entryFileUrl = process.argv[1] ? pathToFileURL(process.argv[1]).href : null;

if (entryFileUrl && import.meta.url === entryFileUrl) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.stack ?? error.message : error);
    process.exitCode = 1;
  });
}
