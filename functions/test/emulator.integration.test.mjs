import test from "node:test";
import assert from "node:assert/strict";
import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";

const projectId = process.env.GCLOUD_PROJECT ?? "demo-boatface";
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST ?? "127.0.0.1:9099";
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:8080";
const functionsBaseUrl =
  process.env.FUNCTIONS_BASE_URL ??
  `http://127.0.0.1:5001/${projectId}/asia-northeast2`;
const apiKey = "demo-api-key";

initializeApp({projectId});

const db = getFirestore();

async function clearFirestore() {
  const response = await fetch(
    `http://${firestoreHost}/emulator/v1/projects/${projectId}/databases/(default)/documents`,
    {method: "DELETE"},
  );
  assert.equal(response.status, 200, "failed to clear Firestore emulator");
}

async function clearAuth() {
  const response = await fetch(
    `http://${authHost}/emulator/v1/projects/${projectId}/accounts`,
    {method: "DELETE"},
  );
  assert.equal(response.status, 200, "failed to clear Auth emulator");
}

async function signInUser() {
  const email = "integration@example.com";
  const password = "testpass123";

  const signUpResponse = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`,
    {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({email, password, returnSecureToken: true}),
    },
  );
  assert.equal(signUpResponse.status, 200, "email signup failed");

  const signInResponse = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`,
    {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({email, password, returnSecureToken: true}),
    },
  );
  assert.equal(signInResponse.status, 200, "email sign-in failed");
  const signInBody = await signInResponse.json();

  const updateResponse = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:update?key=${apiKey}`,
    {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({
        idToken: signInBody.idToken,
        displayName: "Integration Tester",
        returnSecureToken: true,
      }),
    },
  );
  assert.equal(updateResponse.status, 200, "displayName update failed");
  await updateResponse.json();

  const refreshedSignInResponse = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`,
    {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({email, password, returnSecureToken: true}),
    },
  );
  assert.equal(refreshedSignInResponse.status, 200, "refresh sign-in failed");
  const refreshedSignInBody = await refreshedSignInResponse.json();

  return {idToken: refreshedSignInBody.idToken, localId: refreshedSignInBody.localId};
}

async function seedRacers() {
  await db.doc("app_config/racer_dataset_state").set({
    currentDatasetId: "dataset-current",
    fallbackDatasetId: "dataset-fallback",
  });

  await Promise.all([
    db.collection("racer_datasets").doc("dataset-current").set({
      datasetId: "dataset-current",
      racerCount: 2,
      sourceType: "seed",
      datasetUpdatedAt: new Date("2026-03-16T00:00:00Z"),
      imagePackStoragePath: "racer-image-packs/dataset-current.zip",
      imagePackImageCount: 2,
      imagePackByteSize: 2048,
      imagePackUpdatedAt: new Date("2026-03-16T01:00:00Z"),
    }),
    db.collection("racer_datasets").doc("dataset-fallback").set({
      datasetId: "dataset-fallback",
      racerCount: 1,
      sourceType: "seed",
      datasetUpdatedAt: new Date("2025-09-16T00:00:00Z"),
      imagePackStoragePath: "racer-image-packs/dataset-fallback.zip",
      imagePackImageCount: 1,
      imagePackByteSize: 1024,
      imagePackUpdatedAt: new Date("2025-09-16T01:00:00Z"),
    }),
    db.collection("racer_datasets").doc("dataset-current").collection("racers").doc("racer-active").set({
      name: "Active Racer",
      registrationNumber: 1001,
      class: "A1",
      gender: "male",
      imageUrl: "https://example.com/active.png",
      imageStoragePath: "racer-images/dataset-current/1001.png",
      imageSource: "seed",
      updatedAt: new Date("2026-03-15T00:00:00Z"),
      isActive: true,
    }),
    db.collection("racer_datasets").doc("dataset-current").collection("racers").doc("racer-inactive").set({
      name: "Inactive Racer",
      registrationNumber: 1002,
      class: "B1",
      gender: "female",
      imageUrl: "https://example.com/inactive.png",
      imageStoragePath: "racer-images/dataset-current/1002.png",
      imageSource: "seed",
      updatedAt: new Date("2026-03-15T00:00:00Z"),
      isActive: false,
    }),
    db.collection("racer_datasets").doc("dataset-fallback").collection("racers").doc("racer-fallback").set({
      name: "Fallback Racer",
      registrationNumber: 901,
      class: "A2",
      gender: "male",
      imageUrl: "https://example.com/fallback.png",
      imageStoragePath: "racer-images/dataset-fallback/0901.png",
      imageSource: "seed",
      updatedAt: new Date("2025-09-15T00:00:00Z"),
      isActive: true,
    }),
  ]);
}

async function callFunction(path, options = {}) {
  const response = await fetch(`${functionsBaseUrl}/${path}`, options);
  const contentType = response.headers.get("content-type") ?? "";
  const body = contentType.includes("application/json") ?
    await response.json() :
    await response.text();

  return {response, body};
}

test("functions endpoints work together in the emulator suite", async () => {
  await clearFirestore();
  await clearAuth();
  await seedRacers();

  const {idToken, localId} = await signInUser();
  const authHeaders = {
    Authorization: `Bearer ${idToken}`,
    "Content-Type": "application/json",
  };

  const racersResult = await callFunction("getRacers?active=true", {
    method: "GET",
    headers: {Authorization: `Bearer ${idToken}`},
  });
  assert.equal(racersResult.response.status, 200);
  assert.equal(Array.isArray(racersResult.body), true);
  assert.equal(racersResult.body.length, 1);
  assert.equal(racersResult.body[0].id, "racer-active");
  assert.equal(racersResult.body[0].class, "A1");
  assert.equal(racersResult.body[0].gender, "male");

  const manifestResult = await callFunction("getRacerDatasetManifest", {
    method: "GET",
    headers: {Authorization: `Bearer ${idToken}`},
  });
  assert.equal(manifestResult.response.status, 200);
  assert.equal(manifestResult.body.datasetId, "dataset-current");
  assert.equal(manifestResult.body.datasetUpdatedAt, "2026-03-16T00:00:00.000Z");
  assert.equal(manifestResult.body.recordCount, 2);
  assert.deepEqual(manifestResult.body.imagePack, {
    storagePath: "racer-image-packs/dataset-current.zip",
    updatedAt: "2026-03-16T01:00:00.000Z",
    imageCount: 2,
    byteSize: 2048,
  });

  const snapshotResult = await callFunction("getRacerDatasetSnapshot", {
    method: "GET",
    headers: {Authorization: `Bearer ${idToken}`},
  });
  assert.equal(snapshotResult.response.status, 200);
  assert.equal(snapshotResult.body.datasetId, "dataset-current");
  assert.equal(snapshotResult.body.recordCount, 2);
  assert.equal(snapshotResult.body.imagePack.storagePath, "racer-image-packs/dataset-current.zip");
  assert.equal(snapshotResult.body.racers.length, 2);
  assert.equal(snapshotResult.body.racers[0].id, "racer-active");
  assert.equal(snapshotResult.body.racers[1].id, "racer-inactive");
  assert.equal(snapshotResult.body.racers[0].imageStoragePath, "racer-images/dataset-current/1001.png");
  assert.equal(snapshotResult.body.racers[0].class, "A1");
  assert.equal(snapshotResult.body.racers[0].gender, "male");

  await db.doc("app_config/racer_dataset_state").set({
    currentDatasetId: null,
  }, {merge: true});

  const fallbackRacersResult = await callFunction("getRacers", {
    method: "GET",
    headers: {Authorization: `Bearer ${idToken}`},
  });
  assert.equal(fallbackRacersResult.response.status, 200);
  assert.equal(fallbackRacersResult.body.length, 1);
  assert.equal(fallbackRacersResult.body[0].id, "racer-fallback");

  const sessionResult = await callFunction("createQuizSession", {
    method: "POST",
    headers: authHeaders,
    body: JSON.stringify({modeId: "quick"}),
  });
  assert.equal(sessionResult.response.status, 201);
  assert.match(sessionResult.body.sessionId, /^qs_/);
  assert.ok(sessionResult.body.expiresAt);

  const submitResult = await callFunction("submitQuizResult", {
    method: "POST",
    headers: authHeaders,
    body: JSON.stringify({
      sessionId: sessionResult.body.sessionId,
      modeId: "quick",
      modeLabel: "さくっと",
      score: 7,
      correctAnswers: 7,
      totalQuestions: 10,
      totalAnswerTimeMs: 5432,
      endReason: "wrongAnswer",
      rankingEligible: true,
      continuedByAd: false,
      clientFinishedAt: "2026-03-15T10:00:00Z",
    }),
  });
  assert.equal(submitResult.response.status, 201);
  assert.equal(typeof submitResult.body.resultId, "string");
  assert.equal(submitResult.body.rankingEligible, true);

  const rankingsResult = await callFunction("getRankings?modeId=quick&period=today&limit=10", {
    method: "GET",
    headers: {Authorization: `Bearer ${idToken}`},
  });
  assert.equal(rankingsResult.response.status, 200);
  assert.equal(rankingsResult.body.modeId, "quick");
  assert.equal(rankingsResult.body.period, "today");
  assert.equal(rankingsResult.body.entries.length, 1);
  assert.deepEqual(rankingsResult.body.entries[0], {
    rank: 1,
    userId: localId,
    displayName: "Integration Tester",
    score: 7,
    totalAnswerTimeMs: 5432,
  });
});
