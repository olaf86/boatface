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
  mistakes?: QuizMistakeSubmitItem[];
};

export type QuizMistakeSubmitOption = {
  racerId?: string;
  label?: string;
  labelReading?: string | null;
  imageUrl?: string | null;
};

export type QuizMistakeSubmitItem = {
  questionIndex?: number;
  mistakeSequence?: number;
  promptType?: string;
  prompt?: string;
  promptImageUrl?: string | null;
  options?: QuizMistakeSubmitOption[];
  correctIndex?: number;
  selectedIndex?: number | null;
  correctRacerId?: string;
  selectedRacerId?: string | null;
  elapsedMs?: number;
  outcome?: string;
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

export type QuizMistakeRecord = {
  resultId: string;
  sessionId: string;
  modeId: string;
  modeLabel: string;
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
  sortKey: number;
  createdAt: Timestamp;
};

export type QuizMistakeStoredOption = {
  racerId: string;
  label: string;
  labelReading: string | null;
  imageUrl: string | null;
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
