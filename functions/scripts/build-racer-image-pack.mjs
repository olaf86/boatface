#!/usr/bin/env node

import os from "node:os";
import path from "node:path";
import fs from "node:fs/promises";
import {createWriteStream} from "node:fs";
import {pipeline} from "node:stream/promises";
import {pathToFileURL} from "node:url";

import {initializeApp, applicationDefault} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import yazl from "yazl";

import {buildImagePackStoragePath} from "./helpers/racer-dataset-helpers.mjs";

function parseArgs(argv) {
  const options = {
    datasetId: "",
    projectId: process.env.GCLOUD_PROJECT ?? "",
    bucket: process.env.FIREBASE_STORAGE_BUCKET ?? "",
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
  if (!options.force && !process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error("Refusing to build image packs outside the emulator without --force.");
  }

  return options;
}

async function writeZipFile(outputPath, inputDirectory) {
  const zipFile = new yazl.ZipFile();
  const directoryEntries = await fs.readdir(inputDirectory, {withFileTypes: true});

  for (const entry of directoryEntries) {
    if (!entry.isFile()) {
      continue;
    }

    const sourcePath = path.join(inputDirectory, entry.name);
    zipFile.addFile(sourcePath, entry.name);
  }

  zipFile.end();
  await pipeline(zipFile.outputStream, createWriteStream(outputPath));
}

export async function main(argv = process.argv.slice(2)) {
  const options = parseArgs(argv);
  const app = initializeApp({
    credential: process.env.FIRESTORE_EMULATOR_HOST ? undefined : applicationDefault(),
    projectId: options.projectId,
    storageBucket: options.bucket,
  }, `racer-image-pack-${Date.now()}`);
  const db = getFirestore(app);
  const bucket = getStorage(app).bucket(options.bucket);
  const datasetRef = db.collection("racer_datasets").doc(options.datasetId);

  const datasetSnapshot = await datasetRef.get();
  if (!datasetSnapshot.exists) {
    throw new Error(`Dataset ${options.datasetId} does not exist`);
  }

  const racersSnapshot = await datasetRef.collection("racers")
    .orderBy("registrationNumber", "asc")
    .get();
  const racers = racersSnapshot.docs.map((doc) => doc.data());
  const packCandidates = racers.filter((racer) =>
    typeof racer.imageStoragePath === "string" && racer.imageStoragePath &&
    Number.isInteger(racer.registrationNumber),
  );

  if (packCandidates.length === 0) {
    throw new Error(`Dataset ${options.datasetId} has no synced racer images`);
  }

  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "boatface-image-pack-"));
  const imagesDir = path.join(tempDir, "images");
  await fs.mkdir(imagesDir, {recursive: true});

  try {
    for (const racer of packCandidates) {
      const storagePath = racer.imageStoragePath;
      const localPath = path.join(imagesDir, path.basename(storagePath));
      await bucket.file(storagePath).download({destination: localPath});
    }

    const zipPath = path.join(tempDir, `${options.datasetId}.zip`);
    await writeZipFile(zipPath, imagesDir);

    const imagePackStoragePath = buildImagePackStoragePath(options.datasetId);
    await bucket.upload(zipPath, {
      destination: imagePackStoragePath,
      metadata: {
        contentType: "application/zip",
        metadata: {
          datasetId: options.datasetId,
          imageCount: String(packCandidates.length),
        },
      },
    });

    const uploadedFile = bucket.file(imagePackStoragePath);
    const [metadata] = await uploadedFile.getMetadata();
    const byteSize = Number.parseInt(metadata.size ?? "0", 10);

    await datasetRef.set({
      imagePackStoragePath,
      imagePackUpdatedAt: FieldValue.serverTimestamp(),
      imagePackImageCount: packCandidates.length,
      imagePackByteSize: Number.isNaN(byteSize) ? 0 : byteSize,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});

    console.log(JSON.stringify({
      datasetId: options.datasetId,
      imagePackStoragePath,
      imageCount: packCandidates.length,
      byteSize: Number.isNaN(byteSize) ? 0 : byteSize,
    }));
  } finally {
    await fs.rm(tempDir, {recursive: true, force: true});
  }
}

const entryFileUrl = process.argv[1] ? pathToFileURL(process.argv[1]).href : null;

if (entryFileUrl && import.meta.url === entryFileUrl) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.stack ?? error.message : error);
    process.exitCode = 1;
  });
}
