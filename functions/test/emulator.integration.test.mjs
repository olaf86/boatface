import test from "node:test";
import assert from "node:assert/strict";
import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";

const projectId = process.env.GCLOUD_PROJECT ?? "demo-boatface";
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST ?? "127.0.0.1:9099";
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:8080";
const functionsBaseUrl =
  process.env.FUNCTIONS_BASE_URL ??
  `http://127.0.0.1:5001/${projectId}/asia-northeast1`;
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
  await Promise.all([
    db.collection("racers").doc("racer-active").set({
      name: "Active Racer",
      registrationNumber: 1001,
      imageUrl: "https://example.com/active.png",
      imageSource: "seed",
      updatedAt: new Date("2026-03-15T00:00:00Z"),
      isActive: true,
    }),
    db.collection("racers").doc("racer-inactive").set({
      name: "Inactive Racer",
      registrationNumber: 1002,
      imageUrl: "https://example.com/inactive.png",
      imageSource: "seed",
      updatedAt: new Date("2026-03-15T00:00:00Z"),
      isActive: false,
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
