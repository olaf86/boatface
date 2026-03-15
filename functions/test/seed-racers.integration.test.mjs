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

      resolve({
        stdout: stdout.trim(),
        stderr: stderr.trim(),
      });
    });
  });
}

test("seed-racers script populates the racers collection", async () => {
  await clearFirestore();
  await db.collection("racers").doc("stale-racer").set({
    name: "Stale Racer",
    registrationNumber: 999,
    imageUrl: "https://example.com/stale.jpg",
    imageSource: "seed",
    updatedAt: new Date("2026-03-15T00:00:00Z"),
    isActive: false,
  });

  const result = await runSeedScript(["--count", "5", "--clear"]);
  const summary = JSON.parse(result.stdout);
  assert.equal(summary.deleted, 1);
  assert.equal(summary.written, 5);
  assert.equal(summary.emulator, true);

  const snapshot = await db.collection("racers").orderBy("registrationNumber", "asc").get();
  assert.equal(snapshot.size, 5);
  assert.deepEqual(
    snapshot.docs.map((doc) => ({
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
        imageSource: "mock-dataset",
        isActive: true,
      },
      {
        id: "racer-1001",
        name: "選手1001",
        registrationNumber: 1001,
        imageSource: "mock-dataset",
        isActive: true,
      },
      {
        id: "racer-1002",
        name: "選手1002",
        registrationNumber: 1002,
        imageSource: "mock-dataset",
        isActive: true,
      },
      {
        id: "racer-1003",
        name: "選手1003",
        registrationNumber: 1003,
        imageSource: "mock-dataset",
        isActive: true,
      },
      {
        id: "racer-1004",
        name: "選手1004",
        registrationNumber: 1004,
        imageSource: "mock-dataset",
        isActive: true,
      },
    ],
  );
});
