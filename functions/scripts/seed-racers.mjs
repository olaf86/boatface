#!/usr/bin/env node

import {initializeApp, applicationDefault} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";

function parseArgs(argv) {
  const options = {
    count: 1600,
    projectId: process.env.GCLOUD_PROJECT ?? "demo-boatface",
    batchSize: 400,
    clear: false,
    force: false,
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

    if (arg === "--clear") {
      options.clear = true;
      continue;
    }

    if (arg === "--force") {
      options.force = true;
      continue;
    }

    throw new Error(`Unknown argument: ${arg}`);
  }

  if (!Number.isInteger(options.count) || options.count <= 0) {
    throw new Error("--count must be a positive integer");
  }

  if (!Number.isInteger(options.batchSize) || options.batchSize <= 0 || options.batchSize > 500) {
    throw new Error("--batch-size must be between 1 and 500");
  }

  if (!options.force && !process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error(
      "Refusing to write outside the Firestore emulator. Set FIRESTORE_EMULATOR_HOST or pass --force.",
    );
  }

  return options;
}

function buildMockRacer(registrationNumber) {
  return {
    id: `racer-${registrationNumber}`,
    name: `選手${registrationNumber}`,
    registrationNumber,
    imageUrl: `https://example.com/mock/racer/${registrationNumber}.jpg`,
    imageSource: "mock-dataset",
    updatedAt: FieldValue.serverTimestamp(),
    isActive: true,
  };
}

async function clearCollection(db, collectionName, batchSize) {
  let deleted = 0;

  while (true) {
    const snapshot = await db.collection(collectionName).limit(batchSize).get();
    if (snapshot.empty) {
      return deleted;
    }

    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
    }

    await batch.commit();
    deleted += snapshot.size;
  }
}

async function writeRacers(db, racers, batchSize) {
  let written = 0;

  for (let start = 0; start < racers.length; start += batchSize) {
    const batch = db.batch();
    const slice = racers.slice(start, start + batchSize);

    for (const racer of slice) {
      const {id, ...data} = racer;
      batch.set(db.collection("racers").doc(id), data);
    }

    await batch.commit();
    written += slice.length;
  }

  return written;
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
  const racers = Array.from({length: options.count}, (_, index) =>
    buildMockRacer(1000 + index),
  );

  let deleted = 0;
  if (options.clear) {
    deleted = await clearCollection(db, "racers", options.batchSize);
  }

  const written = await writeRacers(db, racers, options.batchSize);
  console.log(JSON.stringify({
    projectId: options.projectId,
    emulator: Boolean(process.env.FIRESTORE_EMULATOR_HOST),
    cleared: options.clear,
    deleted,
    written,
  }));
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
