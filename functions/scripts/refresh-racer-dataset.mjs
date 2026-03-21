#!/usr/bin/env node

import path from "node:path";
import {spawn} from "node:child_process";
import {pathToFileURL} from "node:url";

function getJstNowParts(date = new Date()) {
  const jstDate = new Date(date.getTime() + 9 * 60 * 60 * 1000);
  const year = jstDate.getUTCFullYear();
  const month = jstDate.getUTCMonth() + 1;

  return {
    datasetId: `${year}-${month <= 6 ? "H1" : "H2"}`,
  };
}

function parseArgs(argv) {
  const options = {
    datasetId: "",
    projectId: process.env.GCLOUD_PROJECT ?? "",
    bucket: process.env.FIREBASE_STORAGE_BUCKET ?? "",
    clear: true,
    setCurrent: true,
    syncImages: true,
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
    if (arg === "--no-clear") {
      options.clear = false;
      continue;
    }
    if (arg === "--no-set-current") {
      options.setCurrent = false;
      continue;
    }
    if (arg === "--skip-images") {
      options.syncImages = false;
      continue;
    }
    throw new Error(`Unknown argument: ${arg}`);
  }

  if (!options.projectId) {
    throw new Error("--project is required or GCLOUD_PROJECT must be set");
  }

  if (!options.datasetId) {
    options.datasetId = getJstNowParts().datasetId;
  }

  if (options.syncImages && !options.bucket) {
    throw new Error("--bucket is required unless --skip-images is used");
  }

  return options;
}

async function runNodeScript(scriptName, args) {
  const scriptPath = path.resolve(process.cwd(), "scripts", scriptName);

  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [scriptPath, ...args], {
      stdio: ["ignore", "pipe", "pipe"],
      env: process.env,
    });
    let stdout = "";
    let stderr = "";

    child.stdout.on("data", (chunk) => {
      const text = chunk.toString();
      stdout += text;
      process.stdout.write(text);
    });

    child.stderr.on("data", (chunk) => {
      const text = chunk.toString();
      stderr += text;
      process.stderr.write(text);
    });

    child.on("error", reject);
    child.on("close", (code) => {
      if (code !== 0) {
        reject(new Error(stderr || `${scriptName} exited with code ${code}`));
        return;
      }

      const lines = stdout
        .split("\n")
        .map((line) => line.trim())
        .filter(Boolean);
      const lastLine = lines.at(-1) ?? "";

      try {
        resolve(lastLine ? JSON.parse(lastLine) : null);
      } catch {
        resolve({rawOutput: stdout});
      }
    });
  });
}

export async function main(argv = process.argv.slice(2)) {
  const options = parseArgs(argv);

  const importArgs = [
    "--dataset",
    options.datasetId,
    "--project",
    options.projectId,
  ];
  if (options.clear) {
    importArgs.push("--clear");
  }
  if (options.setCurrent) {
    importArgs.push("--set-current");
  }

  const importResult = await runNodeScript("import-racer-dataset.mjs", importArgs);

  let imageSyncResult = null;
  let imagePackResult = null;
  if (options.syncImages) {
    const syncArgs = [
      "--dataset",
      options.datasetId,
      "--project",
      options.projectId,
      "--bucket",
      options.bucket,
      "--force",
    ];

    imageSyncResult = await runNodeScript("sync-racer-images.mjs", syncArgs);
    imagePackResult = await runNodeScript("build-racer-image-pack.mjs", syncArgs);
  }

  console.log(JSON.stringify({
    datasetId: options.datasetId,
    projectId: options.projectId,
    bucket: options.syncImages ? options.bucket : null,
    importResult,
    imageSyncResult,
    imagePackResult,
  }));
}

const entryFileUrl = process.argv[1] ? pathToFileURL(process.argv[1]).href : null;

if (entryFileUrl && import.meta.url === entryFileUrl) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.stack ?? error.message : error);
    process.exitCode = 1;
  });
}
