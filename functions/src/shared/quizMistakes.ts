import {FieldValue} from "firebase-admin/firestore";

import {db} from "./firebase.js";
import type {
  QuizMistakeRecord,
  QuizMistakeStoredOption,
  QuizMistakeSubmitItem,
} from "./types.js";
import {
  allowedQuizMistakeOutcomes,
  allowedQuizPromptTypes,
  requireNonNegativeInteger,
  requireOptionalNullableString,
  requireString,
} from "./validation.js";

export const maxStoredQuizMistakes = 20;

export type ParsedQuizMistake = {
  questionIndex: number;
  mistakeSequence: number;
  promptType: string;
  prompt: string;
  promptImageUrl: string | null;
  options: QuizMistakeStoredOption[];
  correctIndex: number;
  selectedIndex: number | null;
  correctRacerId: string;
  selectedRacerId: string | null;
  elapsedMs: number;
  outcome: string;
};

export function parseQuizMistakes(value: unknown): ParsedQuizMistake[] | null {
  if (value == null) {
    return [];
  }

  if (!Array.isArray(value)) {
    return null;
  }

  const mistakes: ParsedQuizMistake[] = [];
  for (const item of value) {
    const parsed = parseQuizMistakeItem(item);
    if (!parsed) {
      return null;
    }
    mistakes.push(parsed);
  }

  return mistakes;
}

export function trimRecentQuizMistakes(mistakes: ParsedQuizMistake[]): ParsedQuizMistake[] {
  return mistakes.length <= maxStoredQuizMistakes ?
    mistakes :
    mistakes.slice(mistakes.length - maxStoredQuizMistakes);
}

export function buildQuizMistakeWriteData(params: {
  resultId: string;
  sessionId: string;
  modeId: string;
  modeLabel: string;
  mistake: ParsedQuizMistake;
  submittedAtMs: number;
}) {
  const {resultId, sessionId, modeId, modeLabel, mistake, submittedAtMs} = params;
  return {
    resultId,
    sessionId,
    modeId,
    modeLabel,
    questionIndex: mistake.questionIndex,
    mistakeSequence: mistake.mistakeSequence,
    promptType: mistake.promptType,
    prompt: mistake.prompt,
    promptImageUrl: mistake.promptImageUrl,
    options: mistake.options,
    correctIndex: mistake.correctIndex,
    selectedIndex: mistake.selectedIndex,
    correctRacerId: mistake.correctRacerId,
    selectedRacerId: mistake.selectedRacerId,
    elapsedMs: mistake.elapsedMs,
    outcome: mistake.outcome,
    sortKey: submittedAtMs * 100 + mistake.mistakeSequence,
    createdAt: FieldValue.serverTimestamp(),
  };
}

export function serializeQuizMistake(snapshotId: string, record: QuizMistakeRecord) {
  const correctOption = record.options[record.correctIndex] ?? null;
  const selectedOption = record.selectedIndex == null ?
    null :
    (record.options[record.selectedIndex] ?? null);

  return {
    mistakeId: snapshotId,
    resultId: record.resultId,
    sessionId: record.sessionId,
    modeId: record.modeId,
    modeLabel: record.modeLabel,
    questionIndex: record.questionIndex,
    mistakeSequence: record.mistakeSequence,
    promptType: record.promptType,
    prompt: record.prompt,
    promptImageUrl: record.promptImageUrl,
    options: record.options,
    correctIndex: record.correctIndex,
    selectedIndex: record.selectedIndex,
    correctRacerId: record.correctRacerId,
    selectedRacerId: record.selectedRacerId,
    correctOption,
    selectedOption,
    elapsedMs: record.elapsedMs,
    outcome: record.outcome,
    createdAt: record.createdAt.toDate().toISOString(),
  };
}

export function quizMistakesCollection(uid: string) {
  return db.collection("users").doc(uid).collection("quiz_mistakes");
}

function parseQuizMistakeItem(value: unknown): ParsedQuizMistake | null {
  if (typeof value !== "object" || value == null) {
    return null;
  }

  const raw = value as QuizMistakeSubmitItem;
  const questionIndex = requireNonNegativeInteger(raw.questionIndex);
  const mistakeSequence = requireNonNegativeInteger(raw.mistakeSequence);
  const promptType = requireString(raw.promptType);
  const prompt = requireString(raw.prompt);
  const promptImageUrl = requireOptionalNullableString(raw.promptImageUrl);
  const options = parseQuizMistakeOptions(raw.options);
  const correctIndex = requireNonNegativeInteger(raw.correctIndex);
  const selectedIndex = parseNullableIndex(raw.selectedIndex);
  const correctRacerId = requireString(raw.correctRacerId);
  const selectedRacerId = requireOptionalNullableString(raw.selectedRacerId);
  const elapsedMs = requireNonNegativeInteger(raw.elapsedMs);
  const outcome = requireString(raw.outcome);

  if (
    questionIndex == null ||
    mistakeSequence == null ||
    !promptType ||
    !prompt ||
    promptImageUrl === undefined ||
    options == null ||
    correctIndex == null ||
    selectedIndex === undefined ||
    !correctRacerId ||
    selectedRacerId === undefined ||
    elapsedMs == null ||
    !outcome
  ) {
    return null;
  }

  if (!allowedQuizPromptTypes.has(promptType) || !allowedQuizMistakeOutcomes.has(outcome)) {
    return null;
  }

  if (options.length < 2 || correctIndex >= options.length) {
    return null;
  }

  if (selectedIndex != null && selectedIndex >= options.length) {
    return null;
  }

  if (options[correctIndex]?.racerId !== correctRacerId) {
    return null;
  }

  if (selectedIndex == null) {
    if (selectedRacerId != null) {
      return null;
    }
  } else if (options[selectedIndex]?.racerId !== selectedRacerId) {
    return null;
  }

  return {
    questionIndex,
    mistakeSequence,
    promptType,
    prompt,
    promptImageUrl,
    options,
    correctIndex,
    selectedIndex,
    correctRacerId,
    selectedRacerId,
    elapsedMs,
    outcome,
  };
}

function parseQuizMistakeOptions(value: unknown): QuizMistakeStoredOption[] | null {
  if (!Array.isArray(value)) {
    return null;
  }

  const options: QuizMistakeStoredOption[] = [];
  for (const item of value) {
    if (typeof item !== "object" || item == null) {
      return null;
    }

    const raw = item as {
      racerId?: unknown;
      label?: unknown;
      labelReading?: unknown;
      imageUrl?: unknown;
    };
    const racerId = requireString(raw.racerId);
    const label = requireString(raw.label);
    const labelReading = requireOptionalNullableString(raw.labelReading);
    const imageUrl = requireOptionalNullableString(raw.imageUrl);
    if (!racerId || !label || labelReading === undefined || imageUrl === undefined) {
      return null;
    }

    options.push({racerId, label, labelReading, imageUrl});
  }

  return options;
}

function parseNullableIndex(value: unknown): number | null | undefined {
  if (value == null) {
    return null;
  }

  return requireNonNegativeInteger(value) ?? undefined;
}
