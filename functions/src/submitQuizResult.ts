import * as logger from "firebase-functions/logger";
import {onRequest} from "firebase-functions/v2/https";
import {FieldValue} from "firebase-admin/firestore";

import {appHttpOptions, db} from "./shared/firebase.js";
import {handleOptions, sendError, setCorsHeaders} from "./shared/http.js";
import {
  buildQuizMistakeWriteData,
  maxStoredQuizMistakes,
  parseQuizMistakes,
  quizMistakesCollection,
  trimRecentQuizMistakes,
} from "./shared/quizMistakes.js";
import {getNowJstParts, refreshRankingSnapshots} from "./shared/rankings.js";
import type {QuizResultSubmitRequest, QuizSessionRecord} from "./shared/types.js";
import {isAuthError, upsertUserProfile, verifyRequestAuth} from "./shared/userProfile.js";
import {
  parseClientFinishedAt,
  requireBoolean,
  requireModeId,
  requireNonNegativeInteger,
  requireString,
} from "./shared/validation.js";

export const submitQuizResult = onRequest(appHttpOptions, async (request, response) => {
  setCorsHeaders(response);
  if (handleOptions(request.method, response)) {
    return;
  }

  if (request.method !== "POST") {
    sendError(response, 405, "method_not_allowed", "Use POST for result submission.");
    return;
  }

  try {
    const token = await verifyRequestAuth(request);
    await upsertUserProfile(token);

    const body = (request.body ?? {}) as QuizResultSubmitRequest;
    const sessionId = requireString(body.sessionId);
    const modeId = requireModeId(body.modeId);
    const modeLabel = requireString(body.modeLabel);
    const endReason = requireString(body.endReason);
    const score = requireNonNegativeInteger(body.score);
    const correctAnswers = requireNonNegativeInteger(body.correctAnswers);
    const totalQuestions = requireNonNegativeInteger(body.totalQuestions);
    const totalAnswerTimeMs = requireNonNegativeInteger(body.totalAnswerTimeMs);
    const continuedByAd = requireBoolean(body.continuedByAd);
    const clientFinishedAt = parseClientFinishedAt(body.clientFinishedAt);
    const submittedMistakes = parseQuizMistakes(body.mistakes);

    if (
      !sessionId ||
      !modeId ||
      !modeLabel ||
      !endReason ||
      score === null ||
      correctAnswers === null ||
      totalQuestions === null ||
      totalAnswerTimeMs === null ||
      continuedByAd === null ||
      !clientFinishedAt ||
      submittedMistakes == null
    ) {
      sendError(response, 400, "invalid_payload", "Request body does not match the result contract.");
      return;
    }

    if (score !== correctAnswers) {
      sendError(response, 400, "invalid_score", "score must match correctAnswers for MVP.");
      return;
    }

    if (correctAnswers > totalQuestions) {
      sendError(response, 400, "invalid_correct_answers", "correctAnswers cannot exceed totalQuestions.");
      return;
    }

    if (submittedMistakes.length > totalQuestions) {
      sendError(response, 400, "invalid_mistakes", "mistakes cannot exceed totalQuestions.");
      return;
    }

    for (const mistake of submittedMistakes) {
      if (mistake.questionIndex >= totalQuestions) {
        sendError(response, 400, "invalid_mistakes", "questionIndex must be within totalQuestions.");
        return;
      }
    }

    const periodKeys = getNowJstParts(new Date());
    const rankingEligible = body.rankingEligible === true;
    const resultRef = db.collection("quiz_results").doc();
    const recentMistakes = trimRecentQuizMistakes(submittedMistakes);
    const submittedAtMs = Date.now();

    await db.runTransaction(async (transaction) => {
      const sessionRef = db.collection("quiz_sessions").doc(sessionId);
      const sessionSnapshot = await transaction.get(sessionRef);

      if (!sessionSnapshot.exists) {
        throw new Error("session_not_found");
      }

      const session = sessionSnapshot.data() as QuizSessionRecord;
      if (session.uid !== token.uid) {
        throw new Error("session_uid_mismatch");
      }

      if (session.modeId !== modeId) {
        throw new Error("mode_id_mismatch");
      }

      if (session.status !== "issued") {
        throw new Error("session_already_consumed");
      }

      if (session.expiresAt.toMillis() <= Date.now()) {
        transaction.update(sessionRef, {status: "expired"});
        throw new Error("session_expired");
      }

      if (recentMistakes.length > 0) {
        const mistakesRef = quizMistakesCollection(token.uid);
        const existingMistakesSnapshot = await transaction.get(
          mistakesRef.orderBy("sortKey", "asc"),
        );
        const overflowCount = Math.max(
          0,
          existingMistakesSnapshot.docs.length + recentMistakes.length - maxStoredQuizMistakes,
        );

        for (const doc of existingMistakesSnapshot.docs.slice(0, overflowCount)) {
          transaction.delete(doc.ref);
        }

        for (const mistake of recentMistakes) {
          transaction.set(
            mistakesRef.doc(),
            buildQuizMistakeWriteData({
              resultId: resultRef.id,
              sessionId,
              modeId,
              modeLabel,
              mistake,
              submittedAtMs,
            }),
          );
        }
      }

      transaction.set(resultRef, {
        uid: token.uid,
        sessionId,
        modeId,
        modeLabel,
        score,
        correctAnswers,
        totalQuestions,
        totalAnswerTimeMs,
        endReason,
        rankingEligible,
        continuedByAd,
        clientFinishedAt,
        periodKeyDaily: periodKeys.daily,
        periodKeyTerm: periodKeys.term,
        createdAt: FieldValue.serverTimestamp(),
      });

      transaction.update(sessionRef, {
        status: "consumed",
        consumedAt: FieldValue.serverTimestamp(),
      });
    });

    await refreshRankingSnapshots(modeId, periodKeys.daily, periodKeys.term);
    logger.info("submitQuizResult succeeded", {
      uid: token.uid,
      sessionId,
      modeId,
      resultId: resultRef.id,
    });

    response.status(201).json({
      resultId: resultRef.id,
      rankingEligible,
      periodKeyDaily: periodKeys.daily,
      periodKeyTerm: periodKeys.term,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "unknown_error";
    logger.error("submitQuizResult failed", error);

    if (message === "session_not_found") {
      sendError(response, 404, "session_not_found", "sessionId does not exist.");
      return;
    }

    if (message === "session_uid_mismatch") {
      sendError(response, 403, "forbidden", "The session does not belong to this user.");
      return;
    }

    if (message === "mode_id_mismatch") {
      sendError(response, 400, "mode_id_mismatch", "Submitted modeId does not match the session.");
      return;
    }

    if (message === "session_already_consumed") {
      sendError(response, 409, "session_already_consumed", "This session has already been consumed.");
      return;
    }

    if (message === "session_expired") {
      sendError(response, 409, "session_expired", "This session has expired.");
      return;
    }

    if (isAuthError(error)) {
      sendError(response, 401, "unauthenticated", "A valid Firebase ID token is required.");
      return;
    }

    sendError(response, 500, "internal", "Failed to submit quiz result.");
  }
});
