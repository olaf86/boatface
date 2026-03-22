import path from "node:path";
import {spawn} from "node:child_process";
import {onRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import {defineSecret} from "firebase-functions/params";
import {initializeApp} from "firebase-admin/app";
import {
  FieldValue,
  Firestore,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";
import {getAuth} from "firebase-admin/auth";
import type {DecodedIdToken} from "firebase-admin/auth";
import {getStorage} from "firebase-admin/storage";

initializeApp();

const db = getFirestore();
const auth = getAuth();
const region = "asia-northeast2";
const appHttpOptions = {region, invoker: "public"} as const;
const sessionLifetimeMinutes = 30;
const defaultRankingLimit = 50;
const maxRankingLimit = 100;
const rankingRefreshReadLimit = 200;
const maxNicknameLength = 12;
const guestDisplayName = "ゲスト";
const racerDatasetStateDocPath = "app_config/racer_dataset_state";
const datasetRefreshToken = defineSecret("DATASET_REFRESH_TOKEN");
const allowedModeIds = new Set([
  "quick",
  "careful",
  "challenge",
  "master",
  "custom",
]);
const allowedPeriods = new Set(["today", "term"]);

type UserRegionCategory = "prefecture" | "other";

type UserRegion = {
  category: UserRegionCategory;
  code: string;
  label: string;
};

const supportedUserRegions: readonly UserRegion[] = [
  {category: "prefecture", code: "hokkaido", label: "北海道"},
  {category: "prefecture", code: "aomori", label: "青森県"},
  {category: "prefecture", code: "iwate", label: "岩手県"},
  {category: "prefecture", code: "miyagi", label: "宮城県"},
  {category: "prefecture", code: "akita", label: "秋田県"},
  {category: "prefecture", code: "yamagata", label: "山形県"},
  {category: "prefecture", code: "fukushima", label: "福島県"},
  {category: "prefecture", code: "ibaraki", label: "茨城県"},
  {category: "prefecture", code: "tochigi", label: "栃木県"},
  {category: "prefecture", code: "gunma", label: "群馬県"},
  {category: "prefecture", code: "saitama", label: "埼玉県"},
  {category: "prefecture", code: "chiba", label: "千葉県"},
  {category: "prefecture", code: "tokyo", label: "東京都"},
  {category: "prefecture", code: "kanagawa", label: "神奈川県"},
  {category: "prefecture", code: "niigata", label: "新潟県"},
  {category: "prefecture", code: "toyama", label: "富山県"},
  {category: "prefecture", code: "ishikawa", label: "石川県"},
  {category: "prefecture", code: "fukui", label: "福井県"},
  {category: "prefecture", code: "yamanashi", label: "山梨県"},
  {category: "prefecture", code: "nagano", label: "長野県"},
  {category: "prefecture", code: "gifu", label: "岐阜県"},
  {category: "prefecture", code: "shizuoka", label: "静岡県"},
  {category: "prefecture", code: "aichi", label: "愛知県"},
  {category: "prefecture", code: "mie", label: "三重県"},
  {category: "prefecture", code: "shiga", label: "滋賀県"},
  {category: "prefecture", code: "kyoto", label: "京都府"},
  {category: "prefecture", code: "osaka", label: "大阪府"},
  {category: "prefecture", code: "hyogo", label: "兵庫県"},
  {category: "prefecture", code: "nara", label: "奈良県"},
  {category: "prefecture", code: "wakayama", label: "和歌山県"},
  {category: "prefecture", code: "tottori", label: "鳥取県"},
  {category: "prefecture", code: "shimane", label: "島根県"},
  {category: "prefecture", code: "okayama", label: "岡山県"},
  {category: "prefecture", code: "hiroshima", label: "広島県"},
  {category: "prefecture", code: "yamaguchi", label: "山口県"},
  {category: "prefecture", code: "tokushima", label: "徳島県"},
  {category: "prefecture", code: "kagawa", label: "香川県"},
  {category: "prefecture", code: "ehime", label: "愛媛県"},
  {category: "prefecture", code: "kochi", label: "高知県"},
  {category: "prefecture", code: "fukuoka", label: "福岡県"},
  {category: "prefecture", code: "saga", label: "佐賀県"},
  {category: "prefecture", code: "nagasaki", label: "長崎県"},
  {category: "prefecture", code: "kumamoto", label: "熊本県"},
  {category: "prefecture", code: "oita", label: "大分県"},
  {category: "prefecture", code: "miyazaki", label: "宮崎県"},
  {category: "prefecture", code: "kagoshima", label: "鹿児島県"},
  {category: "prefecture", code: "okinawa", label: "沖縄県"},
  {category: "other", code: "overseas", label: "海外"},
  {category: "other", code: "other", label: "その他"},
];
const supportedUserRegionsByCode = new Map(
  supportedUserRegions.map((region) => [region.code, region]),
);

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

type UserProfileUpdateRequest = {
  nickname?: string | null;
  region?: {
    category?: string;
    code?: string;
  } | null;
};

type QuizSessionRecord = {
  uid: string;
  modeId: string;
  status: "issued" | "consumed" | "expired";
  createdAt: Timestamp;
  expiresAt: Timestamp;
  consumedAt: Timestamp | null;
};

type RankingEntry = {
  rank: number;
  userId: string;
  displayName: string;
  region: UserRegion | null;
  score: number;
  totalAnswerTimeMs: number;
};

type RacerDatasetRefreshRequest = {
  datasetId?: string;
  syncImages?: boolean;
  clear?: boolean;
  setCurrent?: boolean;
};

function setCorsHeaders(response: {
  set: (field: string, value: string) => void;
}) {
  response.set("Access-Control-Allow-Origin", "*");
  response.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  response.set("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
}

function handleOptions(requestMethod: string, response: {
  status: (code: number) => {send: (body?: string) => void};
}) {
  if (requestMethod === "OPTIONS") {
    response.status(204).send("");
    return true;
  }

  return false;
}

function sendError(
  response: {
    status: (code: number) => {json: (body: Record<string, unknown>) => void};
  },
  status: number,
  error: string,
  message: string,
) {
  response.status(status).json({error, message});
}

function requireModeId(modeId: unknown): string | null {
  if (typeof modeId !== "string" || !allowedModeIds.has(modeId)) {
    return null;
  }

  return modeId;
}

function requireString(value: unknown): string | null {
  if (typeof value !== "string" || value.trim().length === 0) {
    return null;
  }

  return value.trim();
}

function requireNonNegativeInteger(value: unknown): number | null {
  if (typeof value !== "number" || !Number.isInteger(value) || value < 0) {
    return null;
  }

  return value;
}

function requireBoolean(value: unknown): boolean | null {
  if (typeof value !== "boolean") {
    return null;
  }

  return value;
}

function parseOptionalBoolean(value: unknown): boolean | null {
  if (typeof value === "boolean") {
    return value;
  }

  if (typeof value !== "string") {
    return null;
  }

  if (value === "true") {
    return true;
  }

  if (value === "false") {
    return false;
  }

  return null;
}

function parseRankingLimit(value: unknown): number {
  if (typeof value !== "string") {
    return defaultRankingLimit;
  }

  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return defaultRankingLimit;
  }

  return Math.min(parsed, maxRankingLimit);
}

function parseClientFinishedAt(value: unknown): string | null {
  const normalized = requireString(value);
  if (!normalized) {
    return null;
  }

  const parsed = new Date(normalized);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }

  return parsed.toISOString();
}

function resolveTokenDisplayName(token: DecodedIdToken): string {
  return typeof token.name === "string" && token.name.trim().length > 0 ?
    token.name.trim() :
    guestDisplayName;
}

function normalizeOptionalNickname(value: unknown): string | null | undefined {
  if (value == null) {
    return null;
  }

  if (typeof value !== "string") {
    return undefined;
  }

  const normalized = value.trim();
  if (!normalized) {
    return null;
  }

  if (normalized.length > maxNicknameLength) {
    return undefined;
  }

  return normalized;
}

function normalizeUserRegion(value: unknown): UserRegion | null | undefined {
  if (value == null) {
    return null;
  }

  if (typeof value !== "object") {
    return undefined;
  }

  const raw = value as {category?: unknown; code?: unknown};
  if (typeof raw.category !== "string" || typeof raw.code !== "string") {
    return undefined;
  }

  const region = supportedUserRegionsByCode.get(raw.code);
  if (!region || region.category !== raw.category) {
    return undefined;
  }

  return region;
}

function readStoredUserRegion(value: unknown): UserRegion | null {
  const normalized = normalizeUserRegion(value);
  return normalized === undefined ? null : normalized;
}

function resolveRankingDisplayName(data: {
  displayName?: unknown;
  nickname?: unknown;
}): string {
  return requireString(data.nickname) ??
    requireString(data.displayName) ??
    guestDisplayName;
}

function buildUserProfileResponse(uid: string, data: Record<string, unknown>) {
  const displayName = requireString(data.displayName) ?? guestDisplayName;
  const nickname = requireString(data.nickname);
  const region = readStoredUserRegion(data.region);

  return {
    uid,
    displayName,
    nickname,
    rankingDisplayName: resolveRankingDisplayName({displayName, nickname}),
    region,
  };
}

function getDefaultStorageBucket(projectId: string): string {
  return `${projectId}.firebasestorage.app`;
}

function timestampToIsoString(value: unknown): string | null {
  return value instanceof Timestamp ? value.toDate().toISOString() : null;
}

function getDatasetUpdatedAtIso(data: Record<string, unknown>): string | null {
  return timestampToIsoString(data.datasetUpdatedAt) ??
    timestampToIsoString(data.updatedAt);
}

function requirePositiveInteger(value: unknown): number | null {
  return typeof value === "number" &&
      Number.isInteger(value) &&
      value > 0 ?
    value :
    null;
}

function getImagePackResponse(data: Record<string, unknown>) {
  const storagePath = typeof data.imagePackStoragePath === "string" &&
      data.imagePackStoragePath ?
    data.imagePackStoragePath :
    null;
  const updatedAt = timestampToIsoString(data.imagePackUpdatedAt);
  const imageCount = requirePositiveInteger(data.imagePackImageCount);
  const byteSize = requirePositiveInteger(data.imagePackByteSize);

  if (!storagePath || !updatedAt || imageCount == null || byteSize == null) {
    return null;
  }

  return {
    storagePath,
    updatedAt,
    imageCount,
    byteSize,
  };
}

function mapRacerResponse(id: string, data: Record<string, unknown>) {
  return {
    id,
    name: data.name ?? null,
    registrationNumber: data.registrationNumber ?? null,
    class: data.class ?? null,
    gender: data.gender ?? null,
    imageUrl: data.imageUrl ?? null,
    imageStoragePath: data.imageStoragePath ?? null,
    imageSource: data.imageSource ?? null,
    updatedAt: timestampToIsoString(data.updatedAt),
    isActive: data.isActive ?? null,
  };
}

async function runLocalNodeScript(
  scriptName: string,
  args: string[],
): Promise<Record<string, unknown> | null> {
  const scriptPath = path.resolve(process.cwd(), "scripts", scriptName);

  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [scriptPath, ...args], {
      stdio: ["ignore", "pipe", "pipe"],
      env: process.env,
    });
    let stdout = "";
    let stderr = "";

    child.stdout.on("data", (chunk) => {
      const text = chunk.toString();
      stdout += text;
      process.stdout.write(text);
    });

    child.stderr.on("data", (chunk) => {
      const text = chunk.toString();
      stderr += text;
      process.stderr.write(text);
    });

    child.on("error", reject);
    child.on("close", (code) => {
      if (code !== 0) {
        reject(new Error(stderr || `${scriptName} exited with code ${code}`));
        return;
      }

      const lines = stdout
        .split("\n")
        .map((line) => line.trim())
        .filter(Boolean);
      const lastLine = lines.at(-1) ?? "";

      try {
        resolve(lastLine ? JSON.parse(lastLine) as Record<string, unknown> : null);
      } catch {
        resolve({rawOutput: stdout});
      }
    });
  });
}

async function refreshRacerDataset(datasetId: string, options?: {
  syncImages?: boolean;
  clear?: boolean;
  setCurrent?: boolean;
}): Promise<Record<string, unknown>> {
  const projectId = process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT;
  if (!projectId) {
    throw new Error("missing_project_id");
  }

  const syncImages = options?.syncImages ?? true;
  const clear = options?.clear ?? true;
  const setCurrent = options?.setCurrent ?? true;
  const bucket = getDefaultStorageBucket(projectId);

  const args = [
    "--dataset",
    datasetId,
    "--project",
    projectId,
    "--bucket",
    bucket,
  ];
  if (!clear) {
    args.push("--no-clear");
  }
  if (!setCurrent) {
    args.push("--no-set-current");
  }
  if (!syncImages) {
    args.push("--skip-images");
  }

  const result = await runLocalNodeScript("refresh-racer-dataset.mjs", args);

  return {
    datasetId,
    projectId,
    bucket: syncImages ? bucket : null,
    syncImages,
    clear,
    setCurrent,
    result,
  };
}

function requireRefreshToken(request: {
  headers: Record<string, string | string[] | undefined>;
}): boolean {
  const headerValue = request.headers["x-boatface-admin-token"];
  const token =
    typeof headerValue === "string" ? headerValue.trim() :
      Array.isArray(headerValue) ? (headerValue[0] ?? "").trim() :
      "";

  return Boolean(token) && token === datasetRefreshToken.value();
}

async function verifyRequestAuth(request: {
  headers: Record<string, string | string[] | undefined>;
}): Promise<DecodedIdToken> {
  const authorization = request.headers.authorization;
  if (typeof authorization !== "string" || !authorization.startsWith("Bearer ")) {
    throw new Error("missing_bearer_token");
  }

  const idToken = authorization.slice("Bearer ".length).trim();
  if (!idToken) {
    throw new Error("missing_bearer_token");
  }

  return auth.verifyIdToken(idToken);
}

function isAuthError(error: unknown): boolean {
  if (error instanceof Error && error.message === "missing_bearer_token") {
    return true;
  }

  if (typeof error !== "object" || error === null || !("code" in error)) {
    return false;
  }

  return typeof error.code === "string" && error.code.startsWith("auth/");
}

async function upsertUserProfile(token: DecodedIdToken) {
  const providerId =
    typeof token.firebase?.sign_in_provider === "string" ?
      token.firebase.sign_in_provider :
      "custom";
  const userRef = db.collection("users").doc(token.uid);
  const snapshot = await userRef.get();
  const updates: Record<string, unknown> = {
    displayName: resolveTokenDisplayName(token),
    authProviders: FieldValue.arrayUnion(providerId),
    updatedAt: FieldValue.serverTimestamp(),
  };
  if (!snapshot.exists || !snapshot.get("createdAt")) {
    updates.createdAt = FieldValue.serverTimestamp();
  }

  await userRef.set(updates, {merge: true});
}

function buildSessionId(): string {
  return `qs_${db.collection("_session_ids").doc().id}`;
}

function getNowJstParts(date: Date): {daily: string; term: string} {
  const jstDate = new Date(date.getTime() + 9 * 60 * 60 * 1000);
  const year = jstDate.getUTCFullYear();
  const month = jstDate.getUTCMonth() + 1;
  const day = jstDate.getUTCDate();
  const daily = `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
  const term = `${year}-${month <= 6 ? "H1" : "H2"}`;

  return {daily, term};
}

async function buildRankingEntries(
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
      guestDisplayName,
    region: userProfiles.get(doc.get("uid") as string)?.region ?? null,
    score: doc.get("score") as number,
    totalAnswerTimeMs: doc.get("totalAnswerTimeMs") as number,
  }));
}

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

async function refreshRankingSnapshots(modeId: string, dailyKey: string, termKey: string) {
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

type RacerDatasetSelection = {
  datasetId: string;
  source: "current" | "fallback" | "explicit";
};

async function resolveRacerDatasetSelection(query: {
  datasetId?: unknown;
}): Promise<RacerDatasetSelection> {
  const explicitDatasetId = requireString(query.datasetId);
  if (explicitDatasetId) {
    return {
      datasetId: explicitDatasetId,
      source: "explicit",
    };
  }

  const stateSnapshot = await db.doc(racerDatasetStateDocPath).get();
  if (!stateSnapshot.exists) {
    throw new Error("racer_dataset_state_missing");
  }

  const currentDatasetId = requireString(stateSnapshot.get("currentDatasetId"));
  if (currentDatasetId) {
    return {
      datasetId: currentDatasetId,
      source: "current",
    };
  }

  const fallbackDatasetId = requireString(stateSnapshot.get("fallbackDatasetId"));
  if (!fallbackDatasetId) {
    throw new Error("fallback_racer_dataset_missing");
  }

  return {
    datasetId: fallbackDatasetId,
    source: "fallback",
  };
}

export const createQuizSession = onRequest(appHttpOptions, async (request, response) => {
  setCorsHeaders(response);
  if (handleOptions(request.method, response)) {
    return;
  }

  if (request.method !== "POST") {
    sendError(response, 405, "method_not_allowed", "Use POST for session creation.");
    return;
  }

  try {
    const token = await verifyRequestAuth(request);
    await upsertUserProfile(token);

    const body = (request.body ?? {}) as QuizSessionCreateRequest;
    const modeId = requireModeId(body.modeId);
    if (!modeId) {
      sendError(response, 400, "invalid_mode_id", "modeId must be one of the allowed values.");
      return;
    }

    const sessionId = buildSessionId();
    const expiresAt = Timestamp.fromDate(
      new Date(Date.now() + sessionLifetimeMinutes * 60 * 1000),
    );

    const session: QuizSessionRecord = {
      uid: token.uid,
      modeId,
      status: "issued",
      createdAt: Timestamp.now(),
      expiresAt,
      consumedAt: null,
    };

    await db.collection("quiz_sessions").doc(sessionId).set(session);
    logger.info("createQuizSession succeeded", {uid: token.uid, sessionId, modeId});

    response.status(201).json({
      sessionId,
      expiresAt: expiresAt.toDate().toISOString(),
    });
  } catch (error) {
    logger.error("createQuizSession failed", error);
    if (isAuthError(error)) {
      sendError(response, 401, "unauthenticated", "A valid Firebase ID token is required.");
      return;
    }

    sendError(response, 500, "internal", "Failed to create quiz session.");
  }
});

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
      !clientFinishedAt
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

    const periodKeys = getNowJstParts(new Date());
    const rankingEligible = body.rankingEligible === true;
    const resultRef = db.collection("quiz_results").doc();

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

export const getRacerDatasetSnapshot = onRequest(appHttpOptions, async (request, response) => {
  setCorsHeaders(response);
  if (handleOptions(request.method, response)) {
    return;
  }

  if (request.method !== "GET") {
    sendError(response, 405, "method_not_allowed", "Use GET for racer dataset snapshot.");
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

    const racersSnapshot = await datasetRef.collection("racers")
      .orderBy("registrationNumber", "asc")
      .get();
    const racers = racersSnapshot.docs.map((doc) =>
      mapRacerResponse(doc.id, doc.data() as Record<string, unknown>),
    );
    const imagePack = getImagePackResponse(datasetData);

    logger.info("getRacerDatasetSnapshot succeeded", {
      uid: token.uid,
      datasetId: datasetSelection.datasetId,
      datasetSource: datasetSelection.source,
      count: racers.length,
    });
    response.status(200).json({
      datasetId: datasetSelection.datasetId,
      datasetUpdatedAt,
      recordCount: racers.length,
      imagePack,
      racers,
    });
  } catch (error) {
    logger.error("getRacerDatasetSnapshot failed", error);
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

    sendError(response, 500, "internal", "Failed to fetch racer dataset snapshot.");
  }
});

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

export const refreshRacerDatasetOnSchedule = onSchedule({
  region,
  schedule: "0 0 1 1,7 *",
  timeZone: "Asia/Tokyo",
  timeoutSeconds: 540,
  memory: "1GiB",
}, async (event) => {
  const datasetId = getNowJstParts(new Date(event.scheduleTime)).term;
  logger.info("refreshRacerDatasetOnSchedule started", {datasetId});
  const result = await refreshRacerDataset(datasetId, {
    syncImages: true,
    clear: true,
    setCurrent: true,
  });
  logger.info("refreshRacerDatasetOnSchedule completed", result);
});

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
