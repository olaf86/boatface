import * as logger from "firebase-functions/logger";
import {onRequest} from "firebase-functions/v2/https";

import {Timestamp} from "firebase-admin/firestore";

import {appHttpOptions, db} from "./shared/firebase.js";
import {handleOptions, sendError, setCorsHeaders} from "./shared/http.js";
import {getQuizModeUnlockPrerequisite, isQuizModeUnlocked} from "./shared/quizModeUnlocks.js";
import {buildSessionId} from "./shared/rankings.js";
import type {QuizSessionCreateRequest, QuizSessionRecord} from "./shared/types.js";
import {isAuthError, upsertUserProfile, verifyRequestAuth} from "./shared/userProfile.js";
import {requireModeId} from "./shared/validation.js";

const sessionLifetimeMinutes = 30;

export const createQuizSession = onRequest(appHttpOptions, async (request, response) => {
  setCorsHeaders(response);
  if (handleOptions(request.method, response)) {
    return;
  }

  if (request.method !== "POST") {
    sendError(response, 405, "method_not_allowed", "Use POST for session creation.");
    return;
  }

  try {
    const token = await verifyRequestAuth(request);
    await upsertUserProfile(token);

    const body = (request.body ?? {}) as QuizSessionCreateRequest;
    const modeId = requireModeId(body.modeId);
    if (!modeId) {
      sendError(response, 400, "invalid_mode_id", "modeId must be one of the allowed values.");
      return;
    }

    const userSnapshot = await db.collection("users").doc(token.uid).get();
    const userData = userSnapshot.data() ?? {};
    if (!isQuizModeUnlocked(modeId, userData.quizProgress)) {
      const prerequisiteModeId = getQuizModeUnlockPrerequisite(modeId);
      sendError(
        response,
        403,
        "mode_locked",
        prerequisiteModeId ?
          `modeId ${modeId} is locked until ${prerequisiteModeId} is cleared.` :
          `modeId ${modeId} is locked.`,
      );
      return;
    }

    const sessionId = buildSessionId();
    const expiresAt = Timestamp.fromDate(
      new Date(Date.now() + sessionLifetimeMinutes * 60 * 1000),
    );

    const session: QuizSessionRecord = {
      uid: token.uid,
      modeId,
      status: "issued",
      createdAt: Timestamp.now(),
      expiresAt,
      consumedAt: null,
    };

    await db.collection("quiz_sessions").doc(sessionId).set(session);
    logger.info("createQuizSession succeeded", {uid: token.uid, sessionId, modeId});

    response.status(201).json({
      sessionId,
      expiresAt: expiresAt.toDate().toISOString(),
    });
  } catch (error) {
    logger.error("createQuizSession failed", error);
    if (isAuthError(error)) {
      sendError(response, 401, "unauthenticated", "A valid Firebase ID token is required.");
      return;
    }

    sendError(response, 500, "internal", "Failed to create quiz session.");
  }
});
