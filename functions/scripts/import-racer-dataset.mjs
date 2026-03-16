#!/usr/bin/env node

import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import {promises as fs} from "node:fs";
import {spawn} from "node:child_process";
import {pathToFileURL} from "node:url";

import {initializeApp, applicationDefault} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {path7za} from "7zip-bin";

import {
  OFFICIAL_DOWNLOAD_PAGE_URL,
  buildImageStoragePath,
  extractDatasetArchiveUrl,
  mergeProfileDetails,
  parseRosterFileBuffer,
} from "./lib/racer-dataset-helpers.mjs";

const racerDatasetStateDocPath = "app_config/racer_dataset_state";
const defaultProfileConcurrency = 8;
const defaultImageConcurrency = 4;
const defaultBatchSize = 250;

function parseArgs(argv) {
  const options = {
    datasetId: "",
    projectId: process.env.GCLOUD_PROJECT ?? "",
    bucket: process.env.FIREBASE_STORAGE_BUCKET ?? "",
    archiveUrl: "",
    archivePath: "",
    batchSize: defaultBatchSize,
    profileConcurrency: defaultProfileConcurrency,
    imageConcurrency: defaultImageConcurrency,
    clear: false,
    setCurrent: false,
    setFallback: false,
    skipImages: false,
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
    if (arg === "--archive-url") {
      options.archiveUrl = (argv[index + 1] ?? "").trim();
      index += 1;
      continue;
    }
    if (arg === "--archive-path") {
      options.archivePath = (argv[index + 1] ?? "").trim();
      index += 1;
      continue;
    }
    if (arg === "--batch-size") {
      options.batchSize = Number.parseInt(argv[index + 1] ?? "", 10);
      index += 1;
      continue;
    }
    if (arg === "--profile-concurrency") {
      options.profileConcurrency = Number.parseInt(argv[index + 1] ?? "", 10);
      index += 1;
      continue;
    }
    if (arg === "--image-concurrency") {
      options.imageConcurrency = Number.parseInt(argv[index + 1] ?? "", 10);
      index += 1;
      continue;
    }
    if (arg === "--limit") {
      options.limit = Number.parseInt(argv[index + 1] ?? "", 10);
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
    if (arg === "--skip-images") {
      options.skipImages = true;
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
  if (!options.skipImages && !options.bucket) {
    throw new Error("--bucket is required unless --skip-images is used");
  }
  if (!Number.isInteger(options.batchSize) || options.batchSize <= 0 || options.batchSize > 500) {
    throw new Error("--batch-size must be between 1 and 500");
  }
  if (!Number.isInteger(options.profileConcurrency) || options.profileConcurrency <= 0) {
    throw new Error("--profile-concurrency must be a positive integer");
  }
  if (!Number.isInteger(options.imageConcurrency) || options.imageConcurrency <= 0) {
    throw new Error("--image-concurrency must be a positive integer");
  }
  if (!Number.isInteger(options.limit) || options.limit < 0) {
    throw new Error("--limit must be a non-negative integer");
  }
  if (options.setCurrent && options.setFallback) {
    throw new Error("--set-current and --set-fallback cannot be used together");
  }
  if (!options.force && !process.env.FIRESTORE_EMULATOR_HOST && !options.bucket && !options.skipImages) {
    throw new Error("Refusing to run without a bucket outside the emulator. Pass --force to override.");
  }

  return options;
}

async function fetchText(url) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to fetch ${url}: ${response.status}`);
  }
  return response.text();
}

async function fetchBuffer(url) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to fetch ${url}: ${response.status}`);
  }
  return Buffer.from(await response.arrayBuffer());
}

async function writeTempFile(buffer, name) {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "boatface-racer-import-"));
  const filePath = path.join(tempDir, name);
  await fs.writeFile(filePath, buffer);
  return {tempDir, filePath};
}

async function extractArchive(archivePath) {
  const outputDir = await fs.mkdtemp(path.join(os.tmpdir(), "boatface-racer-extract-"));

  await new Promise((resolve, reject) => {
    const child = spawn(path7za, ["x", archivePath, `-o${outputDir}`, "-y"], {
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stderr = "";

    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });
    child.on("error", reject);
    child.on("close", (code) => {
      if (code !== 0) {
        reject(new Error(stderr || `7za exited with code ${code}`));
        return;
      }
      resolve(undefined);
    });
  });

  return outputDir;
}

async function listFilesRecursive(dirPath) {
  const entries = await fs.readdir(dirPath, {withFileTypes: true});
  const files = [];
  for (const entry of entries) {
    const entryPath = path.join(dirPath, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await listFilesRecursive(entryPath)));
      continue;
    }
    if (entry.isFile()) {
      files.push(entryPath);
    }
  }
  return files;
}

async function findRosterFile(extractedDir) {
  const files = await listFilesRecursive(extractedDir);
  if (files.length === 0) {
    throw new Error("Archive extraction produced no files");
  }

  const candidates = await Promise.all(files.map(async (filePath) => {
    const stat = await fs.stat(filePath);
    return {filePath, size: stat.size};
  }));

  candidates.sort((a, b) => b.size - a.size);
  return candidates[0].filePath;
}

async function deleteCollection(collectionRef, batchSize) {
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

async function runWithConcurrency(items, concurrency, worker) {
  const results = new Array(items.length);
  let index = 0;

  async function runner() {
    while (index < items.length) {
      const current = index;
      index += 1;
      results[current] = await worker(items[current], current);
    }
  }

  await Promise.all(
    Array.from({length: Math.min(concurrency, items.length || 1)}, () => runner()),
  );
  return results;
}

async function fetchProfileHtml(racer) {
  const response = await fetch(racer.profileUrl);
  if (!response.ok) {
    throw new Error(`Failed to fetch profile for ${racer.registrationNumber}: ${response.status}`);
  }
  return response.text();
}

async function uploadRacerImage(bucket, datasetId, racer) {
  if (!racer.imageUrl) {
    return racer;
  }

  const imageResponse = await fetch(racer.imageUrl);
  if (!imageResponse.ok) {
    throw new Error(`Failed to fetch image for ${racer.registrationNumber}: ${imageResponse.status}`);
  }

  const imageBuffer = Buffer.from(await imageResponse.arrayBuffer());
  const contentType = imageResponse.headers.get("content-type") ?? "image/jpeg";
  const imageHash = crypto.createHash("sha256").update(imageBuffer).digest("hex");
  const imageStoragePath = buildImageStoragePath(
    datasetId,
    racer.registrationNumber,
    racer.imageUrl,
  );

  const file = bucket.file(imageStoragePath);
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
    ...racer,
    imageStoragePath,
    imageContentType: contentType,
    imageHash,
    imageFetchedAt: FieldValue.serverTimestamp(),
  };
}

async function writeRacers(collectionRef, racers, batchSize) {
  let written = 0;
  for (let start = 0; start < racers.length; start += batchSize) {
    const slice = racers.slice(start, start + batchSize);
    const batch = collectionRef.firestore.batch();

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
      currentDatasetId && currentDatasetId !== datasetId ? currentDatasetId : fallbackDatasetId;
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

async function resolveArchiveBuffer(options) {
  if (options.archivePath) {
    return fs.readFile(options.archivePath);
  }

  const archiveUrl = options.archiveUrl || extractDatasetArchiveUrl(
    await fetchText(OFFICIAL_DOWNLOAD_PAGE_URL),
    options.datasetId,
  );
  return fetchBuffer(archiveUrl);
}

export async function main(argv = process.argv.slice(2)) {
  const options = parseArgs(argv);
  const appOptions = process.env.FIRESTORE_EMULATOR_HOST ?
    {projectId: options.projectId, storageBucket: options.bucket || undefined} :
    {
      credential: applicationDefault(),
      projectId: options.projectId,
      storageBucket: options.bucket || undefined,
    };
  const app = initializeApp(appOptions, `racer-import-${Date.now()}`);
  const db = getFirestore(app);
  const bucket = options.skipImages ? null : getStorage(app).bucket(options.bucket);

  const archiveBuffer = await resolveArchiveBuffer(options);
  const archiveFileName = options.archivePath ?
    path.basename(options.archivePath) :
    `${options.datasetId}.archive`;
  const archiveTemp = await writeTempFile(archiveBuffer, archiveFileName);
  const extractedDir = await extractArchive(archiveTemp.filePath);
  const rosterFilePath = await findRosterFile(extractedDir);
  const rosterBuffer = await fs.readFile(rosterFilePath);

  let racers = parseRosterFileBuffer(rosterBuffer, options.datasetId);
  if (options.limit > 0) {
    racers = racers.slice(0, options.limit);
  }

  const racersWithProfiles = await runWithConcurrency(
    racers,
    options.profileConcurrency,
    async (racer) => {
      const profileHtml = await fetchProfileHtml(racer);
      return mergeProfileDetails(racer, profileHtml);
    },
  );

  const finalRacers = options.skipImages ?
    racersWithProfiles :
    await runWithConcurrency(
      racersWithProfiles,
      options.imageConcurrency,
      async (racer) => uploadRacerImage(bucket, options.datasetId, racer),
    );

  const datasetRef = db.collection("racer_datasets").doc(options.datasetId);
  const racersCollectionRef = datasetRef.collection("racers");
  let deleted = 0;
  if (options.clear) {
    deleted = await deleteCollection(racersCollectionRef, options.batchSize);
  }

  const written = await writeRacers(racersCollectionRef, finalRacers, options.batchSize);
  await datasetRef.set({
    datasetId: options.datasetId,
    racerCount: finalRacers.length,
    rosterFileName: path.basename(rosterFilePath),
    archiveFileName,
    sourceType: "boatrace-term-download",
    imageStorageBucket: options.skipImages ? null : options.bucket,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  await updateDatasetState(db, options.datasetId, options);

  await fs.rm(archiveTemp.tempDir, {recursive: true, force: true});
  await fs.rm(extractedDir, {recursive: true, force: true});

  console.log(JSON.stringify({
    projectId: options.projectId,
    datasetId: options.datasetId,
    bucket: options.skipImages ? null : options.bucket,
    skipImages: options.skipImages,
    cleared: options.clear,
    deleted,
    written,
    rosterFileName: path.basename(rosterFilePath),
  }));
}

const entryFileUrl = process.argv[1] ? pathToFileURL(process.argv[1]).href : null;

if (entryFileUrl && import.meta.url === entryFileUrl) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.stack ?? error.message : error);
    process.exitCode = 1;
  });
}
