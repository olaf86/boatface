import * as logger from "firebase-functions/logger";
import {onRequest} from "firebase-functions/v2/https";
import {Timestamp} from "firebase-admin/firestore";

import {appHttpOptions, db} from "./shared/firebase.js";
import {handleOptions, sendError, setCorsHeaders} from "./shared/http.js";
import {getNowJstParts, refreshRankingSnapshots} from "./shared/rankings.js";
import type {RankingEntry} from "./shared/types.js";
import {isAuthError, verifyRequestAuth} from "./shared/userProfile.js";
import {allowedPeriods, parseRankingLimit, requireModeId} from "./shared/validation.js";

export const getRankings = onRequest(appHttpOptions, async (request, response) => {
  setCorsHeaders(response);
  if (handleOptions(request.method, response)) {
    return;
  }

  if (request.method !== "GET") {
    sendError(response, 405, "method_not_allowed", "Use GET for rankings.");
    return;
  }

  try {
    const token = await verifyRequestAuth(request);
    const modeId = requireModeId(request.query.modeId);
    const period =
      typeof request.query.period === "string" && allowedPeriods.has(request.query.period) ?
        request.query.period as "today" | "term" :
        null;
    const limit = parseRankingLimit(request.query.limit);

    if (!modeId || !period) {
      sendError(response, 400, "invalid_query", "modeId and period must be valid query parameters.");
      return;
    }

    const periodKeys = getNowJstParts(new Date());
    const periodKey = period === "today" ? periodKeys.daily : periodKeys.term;
    const snapshotId = `${period}_${modeId}_${periodKey}`;
    const snapshotRef = db.collection("ranking_snapshots").doc(snapshotId);
    let snapshot = await snapshotRef.get();

    if (!snapshot.exists) {
      await refreshRankingSnapshots(modeId, periodKeys.daily, periodKeys.term);
      snapshot = await snapshotRef.get();
    }

    const generatedAt = snapshot.get("generatedAt");
    const entries = Array.isArray(snapshot.get("entries")) ?
      (snapshot.get("entries") as RankingEntry[]).slice(0, limit) :
      [];

    logger.info("getRankings succeeded", {uid: token.uid, modeId, period, limit});
    response.status(200).json({
      modeId,
      period,
      generatedAt:
        generatedAt instanceof Timestamp ?
          generatedAt.toDate().toISOString() :
          new Date().toISOString(),
      entries,
    });
  } catch (error) {
    logger.error("getRankings failed", error);
    if (isAuthError(error)) {
      sendError(response, 401, "unauthenticated", "A valid Firebase ID token is required.");
      return;
    }

    sendError(response, 500, "internal", "Failed to fetch rankings.");
  }
});
