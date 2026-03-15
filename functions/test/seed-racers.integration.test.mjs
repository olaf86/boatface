import test from "node:test";
import assert from "node:assert/strict";
import {spawn} from "node:child_process";
import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";

const projectId = process.env.GCLOUD_PROJECT ?? "demo-boatface";
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:8080";

initializeApp({projectId});

const db = getFirestore();

async function clearFirestore() {
  const response = await fetch(
    `http://${firestoreHost}/emulator/v1/projects/${projectId}/databases/(default)/documents`,
    {method: "DELETE"},
  );
  assert.equal(response.status, 200, "failed to clear Firestore emulator");
}

async function runSeedScript(args) {
  return new Promise((resolve, reject) => {
    const child = spawn("node", ["./scripts/seed-racers.mjs", ...args], {
      cwd: process.cwd(),
      env: {
        ...process.env,
        FIRESTORE_EMULATOR_HOST: firestoreHost,
        GCLOUD_PROJECT: projectId,
      },
      stdio: ["ignore", "pipe", "pipe"],
    });

    let stdout = "";
    let stderr = "";

    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });
    child.on("error", reject);
    child.on("close", (code) => {
      if (code !== 0) {
        reject(new Error(stderr || `seed script exited with code ${code}`));
        return;
      }

      resolve(JSON.parse(stdout.trim()));
    });
  });
}

test("seed-racers keeps current and fallback datasets side-by-side", async () => {
  await clearFirestore();

  const fallbackSummary = await runSeedScript([
    "--dataset", "2025-H2",
    "--set-fallback",
    "--count", "3",
    "--clear",
  ]);
  assert.equal(fallbackSummary.datasetId, "2025-H2");
  assert.equal(fallbackSummary.setFallback, true);
  assert.equal(fallbackSummary.setCurrent, false);
  assert.equal(fallbackSummary.deleted, 0);
  assert.equal(fallbackSummary.written, 3);

  await db.collection("racer_datasets").doc("2026-H1").collection("racers").doc("stale-racer").set({
    name: "Stale Racer",
    registrationNumber: 999,
    imageUrl: "https://example.com/stale.jpg",
    imageSource: "seed",
    updatedAt: new Date("2026-03-15T00:00:00Z"),
    isActive: false,
  });

  const currentSummary = await runSeedScript([
    "--dataset", "2026-H1",
    "--set-current",
    "--count", "5",
    "--clear",
  ]);
  assert.equal(currentSummary.datasetId, "2026-H1");
  assert.equal(currentSummary.setCurrent, true);
  assert.equal(currentSummary.setFallback, false);
  assert.equal(currentSummary.deleted, 1);
  assert.equal(currentSummary.written, 5);
  assert.equal(currentSummary.emulator, true);

  const stateSnapshot = await db.doc("app_config/racer_dataset_state").get();
  assert.equal(stateSnapshot.get("currentDatasetId"), "2026-H1");
  assert.equal(stateSnapshot.get("fallbackDatasetId"), "2025-H2");

  const currentSnapshot = await db.collection("racer_datasets")
    .doc("2026-H1")
    .collection("racers")
    .orderBy("registrationNumber", "asc")
    .get();
  assert.equal(currentSnapshot.size, 5);
  assert.deepEqual(
    currentSnapshot.docs.map((doc) => ({
      id: doc.id,
      name: doc.get("name"),
      registrationNumber: doc.get("registrationNumber"),
      imageSource: doc.get("imageSource"),
      isActive: doc.get("isActive"),
    })),
    [
      {
        id: "racer-1000",
        name: "選手1000",
        registrationNumber: 1000,
        imageSource: "mock-dataset:2026-H1",
        isActive: true,
      },
      {
        id: "racer-1001",
        name: "選手1001",
        registrationNumber: 1001,
        imageSource: "mock-dataset:2026-H1",
        isActive: true,
      },
      {
        id: "racer-1002",
        name: "選手1002",
        registrationNumber: 1002,
        imageSource: "mock-dataset:2026-H1",
        isActive: true,
      },
      {
        id: "racer-1003",
        name: "選手1003",
        registrationNumber: 1003,
        imageSource: "mock-dataset:2026-H1",
        isActive: true,
      },
      {
        id: "racer-1004",
        name: "選手1004",
        registrationNumber: 1004,
        imageSource: "mock-dataset:2026-H1",
        isActive: true,
      },
    ],
  );

  const fallbackSnapshot = await db.collection("racer_datasets")
    .doc("2025-H2")
    .collection("racers")
    .orderBy("registrationNumber", "asc")
    .get();
  assert.equal(fallbackSnapshot.size, 3);
  assert.equal(fallbackSnapshot.docs[0].id, "racer-1000");
  assert.equal(fallbackSnapshot.docs[0].get("imageSource"), "mock-dataset:2025-H2");

  const promotedSummary = await runSeedScript([
    "--dataset", "2026-H2",
    "--set-current",
    "--count", "2",
    "--clear",
  ]);
  assert.equal(promotedSummary.setCurrent, true);

  const promotedStateSnapshot = await db.doc("app_config/racer_dataset_state").get();
  assert.equal(promotedStateSnapshot.get("currentDatasetId"), "2026-H2");
  assert.equal(promotedStateSnapshot.get("fallbackDatasetId"), "2026-H1");
});
