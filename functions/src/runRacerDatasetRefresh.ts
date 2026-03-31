import * as logger from "firebase-functions/logger";
import {onRequest} from "firebase-functions/v2/https";

import {region} from "./shared/firebase.js";
import {sendError} from "./shared/http.js";
import {getNowJstParts} from "./shared/rankings.js";
import {
  datasetRefreshToken,
  refreshRacerDataset,
  requireRefreshToken,
} from "./shared/racerDatasetRefresh.js";
import type {RacerDatasetRefreshRequest} from "./shared/types.js";
import {requireString} from "./shared/validation.js";

export const runRacerDatasetRefresh = onRequest({
  region,
  timeoutSeconds: 540,
  memory: "1GiB",
  secrets: [datasetRefreshToken],
}, async (request, response) => {
  if (request.method !== "POST") {
    sendError(response, 405, "method_not_allowed", "Use POST for manual dataset refresh.");
    return;
  }

  if (!requireRefreshToken(request)) {
    sendError(response, 401, "unauthorized", "A valid dataset refresh token is required.");
    return;
  }

  try {
    const body = (request.body ?? {}) as RacerDatasetRefreshRequest;
    const datasetId = requireString(body.datasetId) ?? getNowJstParts(new Date()).term;
    const syncImages = body.syncImages ?? true;
    const clear = body.clear ?? true;
    const setCurrent = body.setCurrent ?? true;

    const result = await refreshRacerDataset(datasetId, {
      syncImages,
      clear,
      setCurrent,
    });
    logger.info("runRacerDatasetRefresh completed", result);
    response.status(200).json(result);
  } catch (error) {
    logger.error("runRacerDatasetRefresh failed", error);
    sendError(response, 500, "internal", "Failed to refresh the racer dataset.");
  }
});
