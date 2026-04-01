const alwaysUnlockedModeIds = new Set([
  "quick",
  "custom",
]);

const prerequisiteModeIdsByModeId = new Map([
  ["careful", "quick"],
  ["challenge", "careful"],
  ["master", "challenge"],
]);

function readClearedModeIds(value: unknown): Set<string> {
  if (typeof value !== "object" || value == null || !("clearedModeIds" in value)) {
    return new Set();
  }

  const clearedModeIds = value.clearedModeIds;
  if (!Array.isArray(clearedModeIds)) {
    return new Set();
  }

  return new Set(clearedModeIds.filter((item): item is string => typeof item === "string"));
}

export function isQuizModeUnlocked(modeId: string, quizProgress: unknown): boolean {
  if (alwaysUnlockedModeIds.has(modeId)) {
    return true;
  }

  const prerequisiteModeId = prerequisiteModeIdsByModeId.get(modeId);
  if (!prerequisiteModeId) {
    return true;
  }

  return readClearedModeIds(quizProgress).has(prerequisiteModeId);
}

export function getQuizModeUnlockPrerequisite(modeId: string): string | null {
  return prerequisiteModeIdsByModeId.get(modeId) ?? null;
}
