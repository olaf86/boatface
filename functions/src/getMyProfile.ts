import * as logger from "firebase-functions/logger";
import {onRequest} from "firebase-functions/v2/https";

import {appHttpOptions, db} from "./shared/firebase.js";
import {handleOptions, sendError, setCorsHeaders} from "./shared/http.js";
import {
  buildUserProfileResponse,
  isAuthError,
  resolveTokenDisplayName,
  upsertUserProfile,
  verifyRequestAuth,
} from "./shared/userProfile.js";

export const getMyProfile = onRequest(appHttpOptions, async (request, response) => {
  setCorsHeaders(response);
  if (handleOptions(request.method, response)) {
    return;
  }

  if (request.method !== "GET") {
    sendError(response, 405, "method_not_allowed", "Use GET for profile reads.");
    return;
  }

  try {
    const token = await verifyRequestAuth(request);
    await upsertUserProfile(token);

    const snapshot = await db.collection("users").doc(token.uid).get();
    const data = (snapshot.data() ?? {
      displayName: resolveTokenDisplayName(token),
    }) as Record<string, unknown>;

    response.status(200).json(buildUserProfileResponse(token.uid, data));
  } catch (error) {
    logger.error("getMyProfile failed", error);
    if (isAuthError(error)) {
      sendError(response, 401, "unauthenticated", "A valid Firebase ID token is required.");
      return;
    }

    sendError(response, 500, "internal", "Failed to fetch profile.");
  }
});
