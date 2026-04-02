import * as logger from "firebase-functions/logger";
import {onRequest} from "firebase-functions/v2/https";

import {appHttpOptions, db} from "./shared/firebase.js";
import {handleOptions, sendError, setCorsHeaders} from "./shared/http.js";
import {getNowJstParts} from "./shared/rankings.js";
import {isAuthError, verifyRequestAuth} from "./shared/userProfile.js";
import {requireModeId} from "./shared/validation.js";

function buildUserHighScoreDocId(modeId: string, termKey: string): string {
  return `${modeId}_${termKey}`;
}

export const getMyQuizHighScore = onRequest(appHttpOptions, async (request, response) => {
  setCorsHeaders(response);
  if (handleOptions(request.method, response)) {
    return;
  }

  if (request.method !== "GET") {
    sendError(response, 405, "method_not_allowed", "Use GET for quiz high score.");
    return;
  }

  try {
    const token = await verifyRequestAuth(request);
    const modeId = requireModeId(request.query.modeId);

    if (!modeId) {
      sendError(response, 400, "invalid_query", "modeId must be a valid query parameter.");
      return;
    }

    const periodKeyTerm = getNowJstParts(new Date()).term;
    const highScoreSnapshot = await db
      .collection("users")
      .doc(token.uid)
      .collection("quiz_high_scores")
      .doc(buildUserHighScoreDocId(modeId, periodKeyTerm))
      .get();
    const bestScoreValue = highScoreSnapshot.get("bestScore");
    const bestScore = typeof bestScoreValue === "number" ? bestScoreValue : null;

    logger.info("getMyQuizHighScore succeeded", {uid: token.uid, modeId, periodKeyTerm});
    response.status(200).json({
      modeId,
      periodKeyTerm,
      bestScore,
    });
  } catch (error) {
    logger.error("getMyQuizHighScore failed", error);
    if (isAuthError(error)) {
      sendError(response, 401, "unauthenticated", "A valid Firebase ID token is required.");
      return;
    }

    sendError(response, 500, "internal", "Failed to fetch quiz high score.");
  }
});
