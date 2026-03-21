#!/usr/bin/env node

import {initializeApp, applicationDefault} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";

const racerDatasetStateDocPath = "app_config/racer_dataset_state";

function parseArgs(argv) {
  const options = {
    count: 4096,
    projectId: process.env.GCLOUD_PROJECT ?? "demo-boatface",
    batchSize: 400,
    clear: false,
    force: false,
    datasetId: "",
    setCurrent: false,
    setFallback: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];

    if (arg === "--count") {
      options.count = Number.parseInt(argv[index + 1] ?? "", 10);
      index += 1;
      continue;
    }

    if (arg === "--project") {
      options.projectId = argv[index + 1] ?? options.projectId;
      index += 1;
      continue;
    }

    if (arg === "--batch-size") {
      options.batchSize = Number.parseInt(argv[index + 1] ?? "", 10);
      index += 1;
      continue;
    }

    if (arg === "--dataset") {
      options.datasetId = (argv[index + 1] ?? "").trim();
      index += 1;
      continue;
    }

    if (arg === "--clear") {
      options.clear = true;
      continue;
    }

    if (arg === "--set-current") {
      options.setCurrent = true;
      continue;
    }

    if (arg === "--set-fallback") {
      options.setFallback = true;
      continue;
    }

    if (arg === "--force") {
      options.force = true;
      continue;
    }

    throw new Error(`Unknown argument: ${arg}`);
  }

  if (!options.datasetId) {
    throw new Error("--dataset is required");
  }

  if (!Number.isInteger(options.count) || options.count <= 0) {
    throw new Error("--count must be a positive integer");
  }

  if (!Number.isInteger(options.batchSize) || options.batchSize <= 0 || options.batchSize > 500) {
    throw new Error("--batch-size must be between 1 and 500");
  }

  if (options.setCurrent && options.setFallback) {
    throw new Error("--set-current and --set-fallback cannot be used together");
  }

  if (!options.force && !process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error(
      "Refusing to write outside the Firestore emulator. Set FIRESTORE_EMULATOR_HOST or pass --force.",
    );
  }

  return options;
}

function buildMockRacer(registrationNumber, datasetId) {
  return {
    id: `racer-${registrationNumber}`,
    name: `選手${registrationNumber}`,
    registrationNumber,
    class: registrationNumber % 4 === 0 ? "A1" : "B1",
    gender: registrationNumber % 2 === 0 ? "male" : "female",
    imageUrl: `https://example.com/mock/racer/${registrationNumber}.jpg`,
    imageStoragePath: `racer-images/${datasetId}/${registrationNumber}.jpg`,
    imageSource: `mock-dataset:${datasetId}`,
    updatedAt: FieldValue.serverTimestamp(),
    isActive: true,
  };
}

async function clearCollection(collectionRef, batchSize) {
  let deleted = 0;

  while (true) {
    const snapshot = await collectionRef.limit(batchSize).get();
    if (snapshot.empty) {
      return deleted;
    }

    const batch = collectionRef.firestore.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
    }

    await batch.commit();
    deleted += snapshot.size;
  }
}

async function writeRacers(collectionRef, racers, batchSize) {
  let written = 0;

  for (let start = 0; start < racers.length; start += batchSize) {
    const batch = collectionRef.firestore.batch();
    const slice = racers.slice(start, start + batchSize);

    for (const racer of slice) {
      const {id, ...data} = racer;
      batch.set(collectionRef.doc(id), data);
    }

    await batch.commit();
    written += slice.length;
  }

  return written;
}

async function updateDatasetState(db, datasetId, options) {
  if (!options.setCurrent && !options.setFallback) {
    return;
  }

  const stateRef = db.doc(racerDatasetStateDocPath);
  const stateSnapshot = await stateRef.get();
  const currentDatasetId =
    stateSnapshot.exists && typeof stateSnapshot.get("currentDatasetId") === "string" ?
      stateSnapshot.get("currentDatasetId") :
      null;
  const fallbackDatasetId =
    stateSnapshot.exists && typeof stateSnapshot.get("fallbackDatasetId") === "string" ?
      stateSnapshot.get("fallbackDatasetId") :
      null;

  if (options.setCurrent) {
    const nextFallbackDatasetId =
      currentDatasetId && currentDatasetId !== datasetId ?
        currentDatasetId :
        fallbackDatasetId;
    await stateRef.set({
      currentDatasetId: datasetId,
      fallbackDatasetId: nextFallbackDatasetId ?? null,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return;
  }

  await stateRef.set({
    fallbackDatasetId: datasetId,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const appOptions = process.env.FIRESTORE_EMULATOR_HOST ?
    {projectId: options.projectId} :
    {
      credential: applicationDefault(),
      projectId: options.projectId,
    };
  const app = initializeApp(appOptions);
  const db = getFirestore(app);
  const datasetRef = db.collection("racer_datasets").doc(options.datasetId);
  const racersCollectionRef = datasetRef.collection("racers");
  const racers = Array.from({length: options.count}, (_, index) =>
    buildMockRacer(1000 + index, options.datasetId),
  );

  let deleted = 0;
  if (options.clear) {
    deleted = await clearCollection(racersCollectionRef, options.batchSize);
  }

  const written = await writeRacers(racersCollectionRef, racers, options.batchSize);
  await datasetRef.set({
    datasetId: options.datasetId,
    racerCount: options.count,
    sourceType: "mock-dataset",
    datasetUpdatedAt: FieldValue.serverTimestamp(),
    imagePackStoragePath: `racer-image-packs/${options.datasetId}.zip`,
    imagePackImageCount: options.count,
    imagePackByteSize: options.count * 1024,
    imagePackUpdatedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  await updateDatasetState(db, options.datasetId, options);

  console.log(JSON.stringify({
    projectId: options.projectId,
    emulator: Boolean(process.env.FIRESTORE_EMULATOR_HOST),
    datasetId: options.datasetId,
    setCurrent: options.setCurrent,
    setFallback: options.setFallback,
    cleared: options.clear,
    deleted,
    written,
  }));
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
