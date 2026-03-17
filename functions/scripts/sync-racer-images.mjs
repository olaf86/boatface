#!/usr/bin/env node

import path from "node:path";
import crypto from "node:crypto";
import {pathToFileURL} from "node:url";

import {initializeApp, applicationDefault} from "firebase-admin/app";
import {FieldPath, FieldValue, getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";

import {buildImageStoragePath} from "./lib/racer-dataset-helpers.mjs";

const defaultBatchSize = 250;
const defaultConcurrency = 8;
const defaultRequestHeaders = {
  "user-agent": "Mozilla/5.0 (compatible; DataSync/1.0)",
  "accept-language": "ja,en;q=0.8",
};

function parseArgs(argv) {
  const options = {
    datasetId: "",
    projectId: process.env.GCLOUD_PROJECT ?? "",
    bucket: process.env.FIREBASE_STORAGE_BUCKET ?? "",
    batchSize: defaultBatchSize,
    concurrency: defaultConcurrency,
    limit: 0,
    force: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];

    if (arg === "--dataset") {
      options.datasetId = (argv[index + 1] ?? "").trim();
      index += 1;
      continue;
    }
    if (arg === "--project") {
      options.projectId = (argv[index + 1] ?? "").trim();
      index += 1;
      continue;
    }
    if (arg === "--bucket") {
      options.bucket = (argv[index + 1] ?? "").trim();
      index += 1;
      continue;
    }
    if (arg === "--batch-size") {
      options.batchSize = Number.parseInt(argv[index + 1] ?? "", 10);
      index += 1;
      continue;
    }
    if (arg === "--concurrency") {
      options.concurrency = Number.parseInt(argv[index + 1] ?? "", 10);
      index += 1;
      continue;
    }
    if (arg === "--limit") {
      options.limit = Number.parseInt(argv[index + 1] ?? "", 10);
      index += 1;
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
  if (!options.projectId) {
    throw new Error("--project is required or GCLOUD_PROJECT must be set");
  }
  if (!options.bucket) {
    throw new Error("--bucket is required");
  }
  if (!Number.isInteger(options.batchSize) || options.batchSize <= 0 || options.batchSize > 500) {
    throw new Error("--batch-size must be between 1 and 500");
  }
  if (!Number.isInteger(options.concurrency) || options.concurrency <= 0) {
    throw new Error("--concurrency must be a positive integer");
  }
  if (!Number.isInteger(options.limit) || options.limit < 0) {
    throw new Error("--limit must be a non-negative integer");
  }
  if (!options.force && !process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error("Refusing to sync images outside the emulator without --force.");
  }

  return options;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function fetchWithRetry(url, options = {}, attempts = 4) {
  let lastError;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      return await fetch(url, {
        ...options,
        headers: {
          ...defaultRequestHeaders,
          ...(options.headers ?? {}),
        },
      });
    } catch (error) {
      lastError = error;
      if (attempt < attempts) {
        await sleep(500 * attempt);
      }
    }
  }

  throw lastError;
}

async function runWithConcurrency(items, concurrency, worker, options = {}) {
  let index = 0;
  let completed = 0;
  const label = typeof options.label === "string" ? options.label : null;
  const logEvery =
    Number.isInteger(options.logEvery) && options.logEvery > 0 ? options.logEvery : 0;

  async function runner() {
    while (index < items.length) {
      const current = index;
      index += 1;
      await worker(items[current], current);
      completed += 1;
      if (label && (completed === items.length || (logEvery > 0 && completed % logEvery === 0))) {
        console.error(`[${label}] ${completed}/${items.length}`);
      }
    }
  }

  await Promise.all(
    Array.from({length: Math.min(concurrency, items.length || 1)}, () => runner()),
  );
}

async function listDatasetRacers(datasetRef, batchSize) {
  const racers = [];
  let lastDoc = null;

  while (true) {
    let query = datasetRef
      .collection("racers")
      .orderBy(FieldPath.documentId())
      .limit(batchSize);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) {
      return racers;
    }

    racers.push(...snapshot.docs);
    lastDoc = snapshot.docs.at(-1);
  }
}

function normalizeStorageMetadata(datasetId, racer) {
  const imageStoragePath =
    typeof racer.imageStoragePath === "string" && racer.imageStoragePath ?
      racer.imageStoragePath :
      buildImageStoragePath(datasetId, racer.registrationNumber, racer.imageUrl);

  return {
    imageStoragePath,
    imageContentType:
      typeof racer.imageContentType === "string" && racer.imageContentType ?
        racer.imageContentType :
        null,
    imageHash:
      typeof racer.imageHash === "string" && racer.imageHash ? racer.imageHash : null,
  };
}

async function readExistingObjectMetadata(file) {
  const [exists] = await file.exists();
  if (!exists) {
    return null;
  }

  const [metadata] = await file.getMetadata();
  return {
    imageContentType: metadata.contentType ?? null,
    imageHash: metadata.metadata?.imageHash ?? null,
  };
}

async function uploadImage(file, racer) {
  const imageResponse = await fetchWithRetry(racer.imageUrl);
  if (!imageResponse.ok) {
    throw new Error(`Failed to fetch image for ${racer.registrationNumber}: ${imageResponse.status}`);
  }

  const imageBuffer = Buffer.from(await imageResponse.arrayBuffer());
  const contentType = imageResponse.headers.get("content-type") ?? "image/jpeg";
  const imageHash = crypto.createHash("sha256").update(imageBuffer).digest("hex");

  await file.save(imageBuffer, {
    resumable: false,
    metadata: {
      contentType,
      metadata: {
        registrationNumber: String(racer.registrationNumber),
        imageHash,
      },
    },
  });

  return {
    imageContentType: contentType,
    imageHash,
  };
}

async function syncRacerImage(bucket, datasetId, racerDoc, force) {
  const racer = racerDoc.data();
  if (!racer.imageUrl || !racer.registrationNumber) {
    return {status: "skipped-no-image"};
  }

  if (!force && typeof racer.imageStoragePath === "string" && racer.imageStoragePath) {
    return {status: "skipped-synced"};
  }

  const {imageStoragePath, imageContentType, imageHash} = normalizeStorageMetadata(datasetId, racer);
  const file = bucket.file(imageStoragePath);
  const existingMetadata = await readExistingObjectMetadata(file);
  const nextMetadata =
    existingMetadata ?? await uploadImage(file, racer);

  await racerDoc.ref.set({
    imageStoragePath,
    imageContentType: nextMetadata.imageContentType ?? imageContentType,
    imageHash: nextMetadata.imageHash ?? imageHash,
    imageFetchedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  return {status: existingMetadata ? "backfilled" : "uploaded"};
}

export async function main(argv = process.argv.slice(2)) {
  const options = parseArgs(argv);
  const app = initializeApp({
    credential: process.env.FIRESTORE_EMULATOR_HOST ? undefined : applicationDefault(),
    projectId: options.projectId,
    storageBucket: options.bucket,
  }, `racer-image-sync-${Date.now()}`);
  const db = getFirestore(app);
  const bucket = getStorage(app).bucket(options.bucket);
  const datasetRef = db.collection("racer_datasets").doc(options.datasetId);

  const datasetSnapshot = await datasetRef.get();
  if (!datasetSnapshot.exists) {
    throw new Error(`Dataset ${options.datasetId} does not exist`);
  }

  const allRacerDocs = await listDatasetRacers(datasetRef, options.batchSize);
  const candidateRacerDocs = allRacerDocs.filter((racerDoc) => {
    if (options.force) {
      return true;
    }

    const racer = racerDoc.data();
    return !(typeof racer.imageStoragePath === "string" && racer.imageStoragePath);
  });
  const racerDocs =
    options.limit > 0 ? candidateRacerDocs.slice(0, options.limit) : candidateRacerDocs;

  const counters = {
    uploaded: 0,
    backfilled: 0,
    skippedSynced: 0,
    skippedNoImage: 0,
  };

  await runWithConcurrency(
    racerDocs,
    options.concurrency,
    async (racerDoc) => {
      const result = await syncRacerImage(bucket, options.datasetId, racerDoc, options.force);
      if (result.status === "uploaded") {
        counters.uploaded += 1;
        return;
      }
      if (result.status === "backfilled") {
        counters.backfilled += 1;
        return;
      }
      if (result.status === "skipped-synced") {
        counters.skippedSynced += 1;
        return;
      }
      counters.skippedNoImage += 1;
    },
    {label: "image-sync", logEvery: 50},
  );

  await datasetRef.set({
    imageStorageBucket: options.bucket,
    imageSyncUpdatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  console.log(JSON.stringify({
    projectId: options.projectId,
    datasetId: options.datasetId,
    bucket: options.bucket,
    totalRacers: allRacerDocs.length,
    processed: racerDocs.length,
    ...counters,
  }));
}

const entryFileUrl = process.argv[1] ? pathToFileURL(process.argv[1]).href : null;

if (entryFileUrl && import.meta.url === entryFileUrl) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.stack ?? error.message : error);
    process.exitCode = 1;
  });
}
