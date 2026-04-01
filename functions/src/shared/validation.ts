const defaultRankingLimit = 50;
const maxRankingLimit = 100;

export const allowedModeIds = new Set([
  "quick",
  "careful",
  "challenge",
  "master",
  "custom",
]);

export const allowedPeriods = new Set(["today", "term"]);
export const allowedQuizPromptTypes = new Set([
  "faceToName",
  "nameToFace",
  "partialFaceToName",
  "registrationToFace",
  "faceToRegistration",
]);
export const allowedQuizMistakeOutcomes = new Set([
  "wrongAnswer",
  "timeout",
  "abandoned",
]);

export function requireModeId(modeId: unknown): string | null {
  if (typeof modeId !== "string" || !allowedModeIds.has(modeId)) {
    return null;
  }

  return modeId;
}

export function requireString(value: unknown): string | null {
  if (typeof value !== "string" || value.trim().length === 0) {
    return null;
  }

  return value.trim();
}

export function requireNonNegativeInteger(value: unknown): number | null {
  if (typeof value !== "number" || !Number.isInteger(value) || value < 0) {
    return null;
  }

  return value;
}

export function requirePositiveInteger(value: unknown): number | null {
  return typeof value === "number" &&
      Number.isInteger(value) &&
      value > 0 ?
    value :
    null;
}

export function requireBoolean(value: unknown): boolean | null {
  if (typeof value !== "boolean") {
    return null;
  }

  return value;
}

export function requireOptionalNullableString(value: unknown): string | null | undefined {
  if (value == null) {
    return null;
  }

  if (typeof value !== "string") {
    return undefined;
  }

  const normalized = value.trim();
  return normalized ? normalized : null;
}

export function parseOptionalBoolean(value: unknown): boolean | null {
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

export function parseRankingLimit(value: unknown): number {
  if (typeof value !== "string") {
    return defaultRankingLimit;
  }

  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return defaultRankingLimit;
  }

  return Math.min(parsed, maxRankingLimit);
}

export function parseClientFinishedAt(value: unknown): string | null {
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
