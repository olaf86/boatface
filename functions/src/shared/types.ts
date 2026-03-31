import type {Timestamp} from "firebase-admin/firestore";

export type UserRegionCategory = "prefecture" | "other";

export type UserRegion = {
  category: UserRegionCategory;
  code: string;
  label: string;
};

export type QuizSessionCreateRequest = {
  modeId?: string;
};

export type QuizResultSubmitRequest = {
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

export type UserProfileUpdateRequest = {
  nickname?: string | null;
  region?: {
    category?: string;
    code?: string;
  } | null;
};

export type QuizSessionRecord = {
  uid: string;
  modeId: string;
  status: "issued" | "consumed" | "expired";
  createdAt: Timestamp;
  expiresAt: Timestamp;
  consumedAt: Timestamp | null;
};

export type UserQuizHighScoreRecord = {
  uid: string;
  modeId: string;
  periodKeyTerm: string;
  bestScore: number;
  resultId: string;
  sessionId: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
};

export type RankingEntry = {
  rank: number;
  userId: string;
  displayName: string;
  region: UserRegion | null;
  score: number;
  totalAnswerTimeMs: number;
};

export type RacerDatasetRefreshRequest = {
  datasetId?: string;
  syncImages?: boolean;
  clear?: boolean;
  setCurrent?: boolean;
};

export type RacerDatasetSelection = {
  datasetId: string;
  source: "current" | "fallback" | "explicit";
};
