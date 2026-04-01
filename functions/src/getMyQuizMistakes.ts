import * as logger from "firebase-functions/logger";
import {onRequest} from "firebase-functions/v2/https";

import {appHttpOptions} from "./shared/firebase.js";
import {handleOptions, sendError, setCorsHeaders} from "./shared/http.js";
import {maxStoredQuizMistakes, quizMistakesCollection, serializeQuizMistake} from "./shared/quizMistakes.js";
import type {QuizMistakeRecord} from "./shared/types.js";
import {isAuthError, upsertUserProfile, verifyRequestAuth} from "./shared/userProfile.js";

export const getMyQuizMistakes = onRequest(appHttpOptions, async (request, response) => {
  setCorsHeaders(response);
  if (handleOptions(request.method, response)) {
    return;
  }

  if (request.method !== "GET") {
    sendError(response, 405, "method_not_allowed", "Use GET for quiz mistake reads.");
    return;
  }

  try {
    const token = await verifyRequestAuth(request);
    await upsertUserProfile(token);

    const snapshot = await quizMistakesCollection(token.uid)
      .orderBy("sortKey", "desc")
      .limit(maxStoredQuizMistakes)
      .get();

    response.status(200).json({
      mistakes: snapshot.docs.map((doc) => serializeQuizMistake(
        doc.id,
        doc.data() as QuizMistakeRecord,
      )),
    });
  } catch (error) {
    logger.error("getMyQuizMistakes failed", error);
    if (isAuthError(error)) {
      sendError(response, 401, "unauthenticated", "A valid Firebase ID token is required.");
      return;
    }

    sendError(response, 500, "internal", "Failed to fetch quiz mistakes.");
  }
});
