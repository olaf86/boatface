import {FieldValue, Timestamp} from "firebase-admin/firestore";
import type {Firestore} from "firebase-admin/firestore";

import {db} from "./firebase.js";
import type {QuizSessionRecord, RankingEntry, UserRegion} from "./types.js";
import {buildUserProfileResponse} from "./userProfile.js";

const maxRankingLimit = 100;
const rankingRefreshReadLimit = 200;

export function buildSessionId(): string {
  return `qs_${db.collection("_session_ids").doc().id}`;
}

export function getNowJstParts(date: Date): {daily: string; term: string} {
  const jstDate = new Date(date.getTime() + 9 * 60 * 60 * 1000);
  const year = jstDate.getUTCFullYear();
  const month = jstDate.getUTCMonth() + 1;
  const day = jstDate.getUTCDate();
  const daily = `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
  const term = `${year}-${month <= 6 ? "H1" : "H2"}`;

  return {daily, term};
}

export async function buildRankingEntries(
  firestore: Firestore,
  modeId: string,
  period: "today" | "term",
  periodKey: string,
  limit: number,
): Promise<RankingEntry[]> {
  const periodField = period === "today" ? "periodKeyDaily" : "periodKeyTerm";
  const resultSnapshot = await firestore.collection("quiz_results")
    .where("modeId", "==", modeId)
    .where(periodField, "==", periodKey)
    .orderBy("score", "desc")
    .orderBy("totalAnswerTimeMs", "asc")
    .limit(Math.max(limit, rankingRefreshReadLimit))
    .get();

  const eligibleResults = resultSnapshot.docs
    .filter((doc) => doc.get("rankingEligible") === true)
    .slice(0, limit);

  const userIds = [...new Set(
    eligibleResults
      .map((doc) => doc.get("uid"))
      .filter((uid): uid is string => typeof uid === "string"),
  )];

  const userProfiles = new Map<string, {
    displayName: string;
    region: UserRegion | null;
  }>();
  await Promise.all(userIds.map(async (uid) => {
    const userSnapshot = await firestore.collection("users").doc(uid).get();
    const data = userSnapshot.data() as Record<string, unknown> | undefined;
    const profile = buildUserProfileResponse(uid, data ?? {});
    userProfiles.set(uid, {
      displayName: profile.rankingDisplayName,
      region: profile.region,
    });
  }));

  return eligibleResults.map((doc, index) => ({
    rank: index + 1,
    userId: doc.get("uid") as string,
    displayName:
      userProfiles.get(doc.get("uid") as string)?.displayName ??
      "ゲスト",
    region: userProfiles.get(doc.get("uid") as string)?.region ?? null,
    score: doc.get("score") as number,
    totalAnswerTimeMs: doc.get("totalAnswerTimeMs") as number,
  }));
}

export async function refreshRankingSnapshots(modeId: string, dailyKey: string, termKey: string) {
  const [todayEntries, termEntries] = await Promise.all([
    buildRankingEntries(db, modeId, "today", dailyKey, maxRankingLimit),
    buildRankingEntries(db, modeId, "term", termKey, maxRankingLimit),
  ]);

  const generatedAt = FieldValue.serverTimestamp();
  await Promise.all([
    db.collection("ranking_snapshots").doc(`today_${modeId}_${dailyKey}`).set({
      modeId,
      period: "today",
      periodKey: dailyKey,
      generatedAt,
      entries: todayEntries,
    }),
    db.collection("ranking_snapshots").doc(`term_${modeId}_${termKey}`).set({
      modeId,
      period: "term",
      periodKey: termKey,
      generatedAt,
      entries: termEntries,
    }),
  ]);
}

export {QuizSessionRecord, Timestamp};
