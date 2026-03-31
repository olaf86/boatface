import path from "node:path";
import * as logger from "firebase-functions/logger";
import {onRequest} from "firebase-functions/v2/https";
import {getStorage} from "firebase-admin/storage";

import {appHttpOptions, db} from "./shared/firebase.js";
import {handleOptions, sendError, setCorsHeaders} from "./shared/http.js";
import {getImagePackResponse} from "./shared/racerDatasetFormatting.js";
import {resolveRacerDatasetSelection} from "./shared/racerDatasetSelection.js";
import {isAuthError, upsertUserProfile, verifyRequestAuth} from "./shared/userProfile.js";

export const getRacerDatasetImagePack = onRequest(appHttpOptions, async (request, response) => {
  setCorsHeaders(response);
  if (handleOptions(request.method, response)) {
    return;
  }

  if (request.method !== "GET") {
    sendError(response, 405, "method_not_allowed", "Use GET for racer dataset image pack.");
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
    const imagePack = getImagePackResponse(datasetData);
    if (!imagePack) {
      sendError(response, 404, "image_pack_not_found", "Requested racer image pack does not exist.");
      return;
    }

    const bucket = getStorage().bucket();
    const file = bucket.file(imagePack.storagePath);
    const [exists] = await file.exists();
    if (!exists) {
      sendError(response, 404, "image_pack_not_found", "Requested racer image pack does not exist.");
      return;
    }

    logger.info("getRacerDatasetImagePack succeeded", {
      uid: token.uid,
      datasetId: datasetSelection.datasetId,
      datasetSource: datasetSelection.source,
      storagePath: imagePack.storagePath,
    });
    response.set("Content-Type", "application/zip");
    response.set("Content-Disposition", `attachment; filename="${path.basename(imagePack.storagePath)}"`);
    response.set("Cache-Control", "private, max-age=0, must-revalidate");
    response.set("Content-Length", String(imagePack.byteSize));
    file.createReadStream()
      .on("error", (error) => {
        logger.error("getRacerDatasetImagePack stream failed", error);
        if (!response.headersSent) {
          sendError(response, 500, "internal", "Failed to fetch racer image pack.");
        } else {
          response.end();
        }
      })
      .pipe(response);
  } catch (error) {
    logger.error("getRacerDatasetImagePack failed", error);
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

    sendError(response, 500, "internal", "Failed to fetch racer image pack.");
  }
});
