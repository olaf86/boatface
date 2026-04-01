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

async function submitResultWithMistake(authHeaders, sessionId, mistakeIndex) {
  const submitResult = await callFunction("submitQuizResult", {
    method: "POST",
    headers: authHeaders,
    body: JSON.stringify({
      sessionId,
      modeId: "quick",
      modeLabel: "さくっと",
      score: 7,
      correctAnswers: 7,
      totalQuestions: 10,
      totalAnswerTimeMs: 5432 + mistakeIndex,
      endReason: "wrongAnswer",
      rankingEligible: true,
      continuedByAd: false,
      clientFinishedAt: "2026-03-15T10:00:00Z",
      mistakes: [
        {
          questionIndex: mistakeIndex % 10,
          mistakeSequence: 0,
          promptType: "faceToName",
          prompt: `この選手は誰？ #${mistakeIndex}`,
          promptImageUrl: "https://example.com/prompt.png",
          options: [
            {
              racerId: "racer-active",
              label: "Active Racer",
              labelReading: "アクティブレーサー",
              imageUrl: "https://example.com/active.png",
            },
            {
              racerId: "racer-inactive",
              label: "Inactive Racer",
              labelReading: "インアクティブレーサー",
              imageUrl: "https://example.com/inactive.png",
            },
          ],
          correctIndex: 0,
          selectedIndex: 1,
          correctRacerId: "racer-active",
          selectedRacerId: "racer-inactive",
          elapsedMs: 1200 + mistakeIndex,
          outcome: "wrongAnswer",
        },
      ],
    }),
  });
  assert.equal(submitResult.response.status, 201);

  return submitResult;
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

  const profileBeforeUpdate = await callFunction("getMyProfile", {
    method: "GET",
    headers: {Authorization: `Bearer ${idToken}`},
  });
  assert.equal(profileBeforeUpdate.response.status, 200);
  assert.equal(profileBeforeUpdate.body.uid, localId);
  assert.equal(profileBeforeUpdate.body.displayName, "Integration Tester");
  assert.equal(profileBeforeUpdate.body.nickname, null);
  assert.equal(profileBeforeUpdate.body.rankingDisplayName, "Integration Tester");
  assert.equal(profileBeforeUpdate.body.region, null);
  assert.deepEqual(profileBeforeUpdate.body.quizProgress, {
    totalAttempts: 0,
    attemptCountsByMode: {},
    clearedModeIds: [],
    lastAttemptModeId: null,
    lastClearedModeId: null,
  });

  const carefulSessionBeforeUnlock = await callFunction("createQuizSession", {
    method: "POST",
    headers: authHeaders,
    body: JSON.stringify({modeId: "careful"}),
  });
  assert.equal(carefulSessionBeforeUnlock.response.status, 403);
  assert.equal(carefulSessionBeforeUnlock.body.error, "mode_locked");

  const profileUpdate = await callFunction("updateMyProfile", {
    method: "POST",
    headers: authHeaders,
    body: JSON.stringify({
      nickname: "テスト太郎",
      region: {
        category: "prefecture",
        code: "tokyo",
      },
    }),
  });
  assert.equal(profileUpdate.response.status, 200);
  assert.equal(profileUpdate.body.nickname, "テスト太郎");
  assert.equal(profileUpdate.body.rankingDisplayName, "テスト太郎");
  assert.deepEqual(profileUpdate.body.region, {
    category: "prefecture",
    code: "tokyo",
    label: "東京都",
  });
  const submitResult = await submitResultWithMistake(
    authHeaders,
    sessionResult.body.sessionId,
    0,
  );
  assert.equal(submitResult.response.status, 201);
  assert.equal(typeof submitResult.body.resultId, "string");
  assert.equal(submitResult.body.rankingEligible, true);

  const storedMistakes = await db
    .collection("users")
    .doc(localId)
    .collection("quiz_mistakes")
    .orderBy("sortKey", "desc")
    .get();
  assert.equal(storedMistakes.size, 1);
  assert.equal(storedMistakes.docs[0].get("prompt"), "この選手は誰？ #0");
  assert.equal(storedMistakes.docs[0].get("selectedRacerId"), "racer-inactive");

  const quizMistakesResult = await callFunction("getMyQuizMistakes", {
    method: "GET",
    headers: {Authorization: `Bearer ${idToken}`},
  });
  assert.equal(quizMistakesResult.response.status, 200);
  assert.equal(quizMistakesResult.body.mistakes.length, 1);
  assert.equal(quizMistakesResult.body.mistakes[0].prompt, "この選手は誰？ #0");
  assert.equal(quizMistakesResult.body.mistakes[0].correctOption.label, "Active Racer");
  assert.equal(quizMistakesResult.body.mistakes[0].selectedOption.label, "Inactive Racer");

  const highScoreRef = db
    .collection("users")
    .doc(localId)
    .collection("quiz_high_scores")
    .doc("quick_2026-H1");
  const highScoreSnapshot = await highScoreRef.get();
  assert.equal(highScoreSnapshot.exists, true);
  assert.deepEqual(highScoreSnapshot.data(), {
    uid: localId,
    modeId: "quick",
    periodKeyTerm: "2026-H1",
    bestScore: 7,
    resultId: submitResult.body.resultId,
    sessionId: sessionResult.body.sessionId,
    createdAt: highScoreSnapshot.get("createdAt"),
    updatedAt: highScoreSnapshot.get("updatedAt"),
  });

  const lowerScoreSessionResult = await callFunction("createQuizSession", {
    method: "POST",
    headers: authHeaders,
    body: JSON.stringify({modeId: "quick"}),
  });
  assert.equal(lowerScoreSessionResult.response.status, 201);

  const lowerScoreResult = await callFunction("submitQuizResult", {
    method: "POST",
    headers: authHeaders,
    body: JSON.stringify({
      sessionId: lowerScoreSessionResult.body.sessionId,
      modeId: "quick",
      modeLabel: "さくっと",
      score: 5,
      correctAnswers: 5,
      totalQuestions: 10,
      totalAnswerTimeMs: 4321,
      endReason: "wrongAnswer",
      rankingEligible: true,
      continuedByAd: false,
      clientFinishedAt: "2026-03-15T10:05:00Z",
    }),
  });
  assert.equal(lowerScoreResult.response.status, 201);

  const highScoreAfterLowerResult = await highScoreRef.get();
  assert.equal(highScoreAfterLowerResult.get("bestScore"), 7);
  assert.equal(highScoreAfterLowerResult.get("resultId"), submitResult.body.resultId);
  assert.equal(highScoreAfterLowerResult.get("sessionId"), sessionResult.body.sessionId);

  const higherScoreSessionResult = await callFunction("createQuizSession", {
    method: "POST",
    headers: authHeaders,
    body: JSON.stringify({modeId: "quick"}),
  });
  assert.equal(higherScoreSessionResult.response.status, 201);

  const higherScoreResult = await callFunction("submitQuizResult", {
    method: "POST",
    headers: authHeaders,
    body: JSON.stringify({
      sessionId: higherScoreSessionResult.body.sessionId,
      modeId: "quick",
      modeLabel: "さくっと",
      score: 9,
      correctAnswers: 9,
      totalQuestions: 9,
      totalAnswerTimeMs: 4000,
      endReason: "completed",
      rankingEligible: true,
      continuedByAd: false,
      clientFinishedAt: "2026-03-15T10:10:00Z",
    }),
  });
  assert.equal(higherScoreResult.response.status, 201);

  const carefulSessionAfterUnlock = await callFunction("createQuizSession", {
    method: "POST",
    headers: authHeaders,
    body: JSON.stringify({modeId: "careful"}),
  });
  assert.equal(carefulSessionAfterUnlock.response.status, 201);

  const challengeSessionBeforeUnlock = await callFunction("createQuizSession", {
    method: "POST",
    headers: authHeaders,
    body: JSON.stringify({modeId: "challenge"}),
  });
  assert.equal(challengeSessionBeforeUnlock.response.status, 403);
  assert.equal(challengeSessionBeforeUnlock.body.error, "mode_locked");

  const highScoreAfterHigherResult = await highScoreRef.get();
  assert.equal(highScoreAfterHigherResult.get("bestScore"), 9);
  assert.equal(highScoreAfterHigherResult.get("resultId"), higherScoreResult.body.resultId);
  assert.equal(
    highScoreAfterHigherResult.get("sessionId"),
    higherScoreSessionResult.body.sessionId,
  );

  const customSessionResult = await callFunction("createQuizSession", {
    method: "POST",
    headers: authHeaders,
    body: JSON.stringify({modeId: "custom"}),
  });
  assert.equal(customSessionResult.response.status, 201);

  const customSubmitResult = await callFunction("submitQuizResult", {
    method: "POST",
    headers: authHeaders,
    body: JSON.stringify({
      sessionId: customSessionResult.body.sessionId,
      modeId: "custom",
      modeLabel: "カスタム",
      score: 8,
      correctAnswers: 8,
      totalQuestions: 8,
      totalAnswerTimeMs: 3900,
      endReason: "completed",
      rankingEligible: false,
      continuedByAd: false,
      clientFinishedAt: "2026-03-15T10:12:00Z",
    }),
  });
  assert.equal(customSubmitResult.response.status, 201);

  const customHighScoreSnapshot = await db
    .collection("users")
    .doc(localId)
    .collection("quiz_high_scores")
    .doc("custom_2026-H1")
    .get();
  assert.equal(customHighScoreSnapshot.exists, false);

  const userSnapshot = await db.collection("users").doc(localId).get();
  assert.equal(userSnapshot.get("quizProgress.totalAttempts"), 4);
  assert.equal(userSnapshot.get("quizProgress.attemptCountsByMode.quick"), 3);
  assert.equal(userSnapshot.get("quizProgress.attemptCountsByMode.custom"), 1);
  assert.deepEqual(userSnapshot.get("quizProgress.clearedModeIds"), ["quick"]);
  assert.equal(userSnapshot.get("quizProgress.lastAttemptModeId"), "custom");
  assert.equal(userSnapshot.get("quizProgress.lastClearedModeId"), "quick");
  assert.ok(userSnapshot.get("quizProgress.lastAttemptAt"));
  assert.ok(userSnapshot.get("quizProgress.lastClearedAt"));
  assert.ok(userSnapshot.get("quizProgress.clearedAtByMode.quick"));

  const profileAfterResults = await callFunction("getMyProfile", {
    method: "GET",
    headers: {Authorization: `Bearer ${idToken}`},
  });
  assert.equal(profileAfterResults.response.status, 200);
  assert.deepEqual(profileAfterResults.body.quizProgress, {
    totalAttempts: 4,
    attemptCountsByMode: {
      quick: 3,
      custom: 1,
    },
    clearedModeIds: ["quick"],
    lastAttemptModeId: "custom",
    lastClearedModeId: "quick",
  });

  const rankingsResult = await callFunction("getRankings?modeId=quick&period=today&limit=10", {
    method: "GET",
    headers: {Authorization: `Bearer ${idToken}`},
  });
  assert.equal(rankingsResult.response.status, 200);
  assert.equal(rankingsResult.body.modeId, "quick");
  assert.equal(rankingsResult.body.period, "today");
  assert.equal(rankingsResult.body.entries.length, 3);
  assert.deepEqual(rankingsResult.body.entries[0], {
    rank: 1,
    userId: localId,
    displayName: "テスト太郎",
    region: {
      category: "prefecture",
      code: "tokyo",
      label: "東京都",
    },
    score: 9,
    totalAnswerTimeMs: 4000,
  });
  assert.deepEqual(rankingsResult.body.entries[1], {
    rank: 2,
    userId: localId,
    displayName: "テスト太郎",
    region: {
      category: "prefecture",
      code: "tokyo",
      label: "東京都",
    },
    score: 7,
    totalAnswerTimeMs: 5432,
  });
  assert.deepEqual(rankingsResult.body.entries[2], {
    rank: 3,
    userId: localId,
    displayName: "テスト太郎",
    region: {
      category: "prefecture",
      code: "tokyo",
      label: "東京都",
    },
    score: 5,
    totalAnswerTimeMs: 4321,
  });

  const publicRankingsResult = await callFunction("getRankings?modeId=quick&period=today&limit=10", {
    method: "GET",
  });
  assert.equal(publicRankingsResult.response.status, 401);
  assert.equal(publicRankingsResult.body.error, "unauthenticated");

  for (let i = 1; i <= 11; i += 1) {
    const nextSessionResult = await callFunction("createQuizSession", {
      method: "POST",
      headers: authHeaders,
      body: JSON.stringify({modeId: "quick"}),
    });
    assert.equal(nextSessionResult.response.status, 201);
    await submitResultWithMistake(authHeaders, nextSessionResult.body.sessionId, i);
  }

  const trimmedMistakes = await db
    .collection("users")
    .doc(localId)
    .collection("quiz_mistakes")
    .get();
  assert.equal(trimmedMistakes.size, 10);

  const latestQuizMistakesResult = await callFunction("getMyQuizMistakes", {
    method: "GET",
    headers: {Authorization: `Bearer ${idToken}`},
  });
  assert.equal(latestQuizMistakesResult.response.status, 200);
  assert.equal(latestQuizMistakesResult.body.mistakes.length, 10);
});
