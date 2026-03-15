import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

const region = "asia-northeast1";

type QuizSessionCreateRequest = {
  modeId?: string;
};

type QuizResultSubmitRequest = {
  sessionId?: string;
  modeId?: string;
  modeLabel?: string;
  score?: number;
  correctAnswers?: number;
  totalQuestions?: number;
  totalAnswerTimeMs?: number;
  endReason?: string;
  rankingEligible?: boolean;
  continuedByAd?: boolean;
  clientFinishedAt?: string;
};

export const createQuizSession = onRequest({region}, async (request, response) => {
  if (request.method !== "POST") {
    response.status(405).json({error: "method_not_allowed"});
    return;
  }

  const body = request.body as QuizSessionCreateRequest;
  logger.info("createQuizSession called", {modeId: body.modeId ?? null});

  response.status(501).json({
    error: "not_implemented",
    message: "Session creation contract is scaffolded but not implemented yet.",
  });
});

export const submitQuizResult = onRequest({region}, async (request, response) => {
  if (request.method !== "POST") {
    response.status(405).json({error: "method_not_allowed"});
    return;
  }

  const body = request.body as QuizResultSubmitRequest;
  logger.info("submitQuizResult called", {
    sessionId: body.sessionId ?? null,
    modeId: body.modeId ?? null,
  });

  response.status(501).json({
    error: "not_implemented",
    message: "Result submission contract is scaffolded but not implemented yet.",
  });
});

export const getRankings = onRequest({region}, async (request, response) => {
  if (request.method !== "GET") {
    response.status(405).json({error: "method_not_allowed"});
    return;
  }

  logger.info("getRankings called", {
    modeId: request.query.modeId ?? null,
    period: request.query.period ?? null,
  });

  response.status(501).json({
    error: "not_implemented",
    message: "Ranking read contract is scaffolded but not implemented yet.",
  });
});

export const getRacers = onRequest({region}, async (request, response) => {
  if (request.method !== "GET") {
    response.status(405).json({error: "method_not_allowed"});
    return;
  }

  logger.info("getRacers called", {
    active: request.query.active ?? null,
  });

  response.status(501).json({
    error: "not_implemented",
    message: "Racer read contract is scaffolded but not implemented yet.",
  });
});
