import * as logger from "firebase-functions/logger";
import {onRequest} from "firebase-functions/v2/https";

import {appHttpOptions, db} from "./shared/firebase.js";
import {handleOptions, sendError, setCorsHeaders} from "./shared/http.js";
import {getDatasetUpdatedAtIso, getImagePackResponse} from "./shared/racerDatasetFormatting.js";
import {resolveRacerDatasetSelection} from "./shared/racerDatasetSelection.js";
import {isAuthError, upsertUserProfile, verifyRequestAuth} from "./shared/userProfile.js";
import {requireNonNegativeInteger} from "./shared/validation.js";

export const getRacerDatasetManifest = onRequest(appHttpOptions, async (request, response) => {
  setCorsHeaders(response);
  if (handleOptions(request.method, response)) {
    return;
  }

  if (request.method !== "GET") {
    sendError(response, 405, "method_not_allowed", "Use GET for racer dataset manifest.");
    return;
  }

  try {
    const token = await verifyRequestAuth(request);
    await upsertUserProfile(token);

    const datasetSelection = await resolveRacerDatasetSelection({
      datasetId: request.query.datasetId,
    });
    const datasetRef = db.collection("racer_datasets").doc(datasetSelection.datasetId);
    const datasetSnapshot = await datasetRef.get();
    if (!datasetSnapshot.exists) {
      sendError(response, 404, "dataset_not_found", "Requested racer dataset does not exist.");
      return;
    }

    const datasetData = datasetSnapshot.data() ?? {};
    const datasetUpdatedAt = getDatasetUpdatedAtIso(datasetData);
    if (!datasetUpdatedAt) {
      sendError(response, 500, "dataset_metadata_incomplete", "Dataset metadata is incomplete.");
      return;
    }

    const recordCount = requireNonNegativeInteger(datasetData.racerCount) ?? 0;
    response.status(200).json({
      datasetId: datasetSelection.datasetId,
      datasetUpdatedAt,
      recordCount,
      imagePack: getImagePackResponse(datasetData),
    });
  } catch (error) {
    logger.error("getRacerDatasetManifest failed", error);
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

    sendError(response, 500, "internal", "Failed to fetch racer dataset manifest.");
  }
});
