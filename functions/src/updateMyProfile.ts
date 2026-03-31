import * as logger from "firebase-functions/logger";
import {onRequest} from "firebase-functions/v2/https";
import {FieldValue} from "firebase-admin/firestore";

import {appHttpOptions, db} from "./shared/firebase.js";
import {handleOptions, sendError, setCorsHeaders} from "./shared/http.js";
import type {UserProfileUpdateRequest} from "./shared/types.js";
import {
  buildUserProfileResponse,
  isAuthError,
  maxNicknameLength,
  normalizeOptionalNickname,
  normalizeUserRegion,
  resolveTokenDisplayName,
  upsertUserProfile,
  verifyRequestAuth,
} from "./shared/userProfile.js";

export const updateMyProfile = onRequest(appHttpOptions, async (request, response) => {
  setCorsHeaders(response);
  if (handleOptions(request.method, response)) {
    return;
  }

  if (request.method !== "POST") {
    sendError(response, 405, "method_not_allowed", "Use POST for profile updates.");
    return;
  }

  try {
    const token = await verifyRequestAuth(request);
    await upsertUserProfile(token);

    const body = (request.body ?? {}) as UserProfileUpdateRequest;
    const hasNickname = Object.prototype.hasOwnProperty.call(body, "nickname");
    const hasRegion = Object.prototype.hasOwnProperty.call(body, "region");

    if (!hasNickname && !hasRegion) {
      sendError(response, 400, "invalid_payload", "nickname or region must be provided.");
      return;
    }

    const nickname = hasNickname ?
      normalizeOptionalNickname(body.nickname) :
      undefined;
    const userRegion = hasRegion ?
      normalizeUserRegion(body.region) :
      undefined;

    if (hasNickname && nickname === undefined) {
      sendError(
        response,
        400,
        "invalid_nickname",
        `nickname must be ${maxNicknameLength} characters or fewer.`,
      );
      return;
    }

    if (hasRegion && userRegion === undefined) {
      sendError(
        response,
        400,
        "invalid_region",
        "region must be one of the supported prefecture or other region options.",
      );
      return;
    }

    const updates: Record<string, unknown> = {
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (hasNickname) {
      updates.nickname = nickname;
    }
    if (hasRegion) {
      updates.region = userRegion;
    }

    const userRef = db.collection("users").doc(token.uid);
    await userRef.set(updates, {merge: true});

    const snapshot = await userRef.get();
    const data = (snapshot.data() ?? {
      displayName: resolveTokenDisplayName(token),
    }) as Record<string, unknown>;

    response.status(200).json(buildUserProfileResponse(token.uid, data));
  } catch (error) {
    logger.error("updateMyProfile failed", error);
    if (isAuthError(error)) {
      sendError(response, 401, "unauthenticated", "A valid Firebase ID token is required.");
      return;
    }

    sendError(response, 500, "internal", "Failed to update profile.");
  }
});
