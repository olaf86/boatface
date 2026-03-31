import * as logger from "firebase-functions/logger";
import {onRequest} from "firebase-functions/v2/https";

import {appHttpOptions, db} from "./shared/firebase.js";
import {handleOptions, sendError, setCorsHeaders} from "./shared/http.js";
import {mapRacerResponse} from "./shared/racerDatasetFormatting.js";
import {resolveRacerDatasetSelection} from "./shared/racerDatasetSelection.js";
import {isAuthError, upsertUserProfile, verifyRequestAuth} from "./shared/userProfile.js";
import {parseOptionalBoolean} from "./shared/validation.js";

export const getRacers = onRequest(appHttpOptions, async (request, response) => {
  setCorsHeaders(response);
  if (handleOptions(request.method, response)) {
    return;
  }

  if (request.method !== "GET") {
    sendError(response, 405, "method_not_allowed", "Use GET for racers.");
    return;
  }

  try {
    const token = await verifyRequestAuth(request);
    await upsertUserProfile(token);

    const active = parseOptionalBoolean(request.query.active);
    const datasetSelection = await resolveRacerDatasetSelection({
      datasetId: request.query.datasetId,
    });
    const datasetRef = db.collection("racer_datasets").doc(datasetSelection.datasetId);
    const datasetSnapshot = await datasetRef.get();
    if (!datasetSnapshot.exists) {
      sendError(response, 404, "dataset_not_found", "Requested racer dataset does not exist.");
      return;
    }

    let query = datasetRef.collection("racers").orderBy("registrationNumber", "asc");
    if (active !== null) {
      query = query.where("isActive", "==", active) as typeof query;
    }

    const snapshot = await query.get();
    const racers = snapshot.docs.map((doc) =>
      mapRacerResponse(doc.id, doc.data() as Record<string, unknown>),
    );

    logger.info("getRacers succeeded", {
      uid: token.uid,
      active,
      datasetId: datasetSelection.datasetId,
      datasetSource: datasetSelection.source,
      count: racers.length,
    });
    response.status(200).json(racers);
  } catch (error) {
    logger.error("getRacers failed", error);
    if (error instanceof Error) {
      if (error.message === "racer_dataset_state_missing") {
        sendError(response, 503, "racer_dataset_state_missing", "No racer dataset state is configured.");
        return;
      }

      if (error.message === "fallback_racer_dataset_missing") {
        sendError(response, 404, "fallback_racer_dataset_missing", "No fallback racer dataset is configured.");
        return;
      }
    }

    if (isAuthError(error)) {
      sendError(response, 401, "unauthenticated", "A valid Firebase ID token is required.");
      return;
    }

    sendError(response, 500, "internal", "Failed to fetch racers.");
  }
});
