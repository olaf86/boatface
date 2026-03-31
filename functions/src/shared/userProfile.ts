import {FieldValue} from "firebase-admin/firestore";
import type {DecodedIdToken} from "firebase-admin/auth";

import {auth, db} from "./firebase.js";
import type {UserRegion} from "./types.js";
import {requireString} from "./validation.js";

const maxNicknameLength = 12;
const guestDisplayName = "ゲスト";

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

export function resolveTokenDisplayName(token: DecodedIdToken): string {
  return typeof token.name === "string" && token.name.trim().length > 0 ?
    token.name.trim() :
    guestDisplayName;
}

export function normalizeOptionalNickname(value: unknown): string | null | undefined {
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

export function normalizeUserRegion(value: unknown): UserRegion | null | undefined {
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

export function readStoredUserRegion(value: unknown): UserRegion | null {
  const normalized = normalizeUserRegion(value);
  return normalized === undefined ? null : normalized;
}

export function resolveRankingDisplayName(data: {
  displayName?: unknown;
  nickname?: unknown;
}): string {
  return requireString(data.nickname) ??
    requireString(data.displayName) ??
    guestDisplayName;
}

export function buildUserProfileResponse(uid: string, data: Record<string, unknown>) {
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

export async function verifyRequestAuth(request: {
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

export function isAuthError(error: unknown): boolean {
  if (error instanceof Error && error.message === "missing_bearer_token") {
    return true;
  }

  if (typeof error !== "object" || error === null || !("code" in error)) {
    return false;
  }

  return typeof error.code === "string" && error.code.startsWith("auth/");
}

export async function upsertUserProfile(token: DecodedIdToken) {
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

export {guestDisplayName, maxNicknameLength};
