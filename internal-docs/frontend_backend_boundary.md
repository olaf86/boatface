# Boatface Frontend / Backend Boundary Spec v0.1

Last updated: 2026-03-15

## 1. Goal

This document defines the recommended boundary between frontend and backend for parallel development using separate git worktrees.

The intent is:
- keep quiz play responsive and mostly local on the device
- move persistence and aggregation to the backend
- minimize merge conflicts between frontend and backend branches

## 2. Recommended Split

### Frontend owns
- authentication UI flow
- mode selection UI
- rule explanation UI
- custom mode editing UI
- in-session quiz generation and progression
- local timer handling
- local score calculation during play
- result screen rendering
- ranking screen UI state and presentation
- API client code and DTO mapping

### Backend owns
- user identity source of truth after sign-in
- quiz session issuance and consumption
- persistent racer master data
- quiz result persistence
- ranking aggregation and query endpoints
- minimal session-based validation for leaderboard eligibility
- future official profile ingestion pipeline

## 3. Why This Boundary Fits The Current Code

The current app already models quiz progression as a local state machine:
- [quiz_session.dart](/Users/olaf/Repos/boatface/lib/features/quiz/application/quiz_session.dart)
- [quiz_session_controller.dart](/Users/olaf/Repos/boatface/lib/features/quiz/application/quiz_session_controller.dart)

That makes frontend-owned quiz execution the lowest-risk path.

The current ranking screen is still mock UI:
- [ranking_screen.dart](/Users/olaf/Repos/boatface/lib/features/ranking/presentation/ranking_screen.dart)

That means backend ranking APIs can be developed in parallel without blocking the existing quiz flow.

## 4. Source Of Truth

### Frontend source of truth
- active session state
- current question index
- local timer state
- whether the ad-continue was consumed
- temporary custom mode configuration before starting a run

### Backend source of truth
- authenticated user profile identity
- quiz session lifecycle
- persistent quiz result records
- daily ranking standings
- term ranking standings
- racer master records

## 5. MVP Runtime Flow

Recommended MVP runtime flow:

1. frontend signs the user in via Firebase Auth
2. frontend fetches racer pool
3. frontend requests a backend-issued quiz session
4. frontend generates quiz questions locally from:
   - selected mode config
   - racer pool
   - runtime random values
5. frontend runs the quiz fully on-device
6. frontend submits a completed result payload to backend with the session id
7. backend validates the session, stores the result, and marks leaderboard eligibility
8. frontend fetches ranking data from backend for display

This keeps gameplay latency low while still making backend the authority for persistence and ranking.

## 6. Contracts To Freeze Before Parallel Work Starts

These are the minimum contracts that should be fixed before creating frontend and backend worktrees.

### 6.1 Auth contract
- Firebase Auth is the authentication provider layer
- frontend obtains the ID token
- backend trusts authenticated Firebase user identity
- Firestore documents should use `uid` as the user key

### 6.2 Racer contract

Recommended racer fields:
- `id: string`
- `name: string`
- `registrationNumber: number`
- `imageUrl: string`
- `imageSource: string`
- `updatedAt: timestamp`
- `isActive: boolean`

### 6.3 Mode contract

For MVP, mode definitions should remain frontend-owned.

Reason:
- current mode definitions are already local constants
- rule explanation and custom mode UI are frontend concerns
- backend does not need to block on mode-definition admin features

Relevant current file:
- [quiz_modes.dart](/Users/olaf/Repos/boatface/lib/features/quiz/domain/quiz_modes.dart)

Backend should only validate that submitted results reference an allowed mode id.

### 6.4 Result submission contract

Recommended payload:

```json
{
  "sessionId": "session_123",
  "modeId": "challenge",
  "modeLabel": "チャレンジ",
  "score": 32,
  "correctAnswers": 32,
  "totalQuestions": 50,
  "totalAnswerTimeMs": 28400,
  "endReason": "wrongAnswer",
  "rankingEligible": true,
  "continuedByAd": true,
  "clientFinishedAt": "2026-03-15T10:00:00Z"
}
```

Notes:
- `sessionId` is the primary backend validation anchor
- `totalAnswerTimeMs` should be the canonical wire value, not `Duration`
- `rankingEligible` sent by frontend is advisory only; backend should recompute it from session state

### 6.5 Session contract

Recommended session creation shape:

```text
POST /quiz-sessions
```

Recommended request shape:

```json
{
  "modeId": "challenge"
}
```

Recommended response shape:

```json
{
  "sessionId": "session_123",
  "expiresAt": "2026-03-15T10:15:00Z"
}
```

Notes:
- session ids should be backend-generated
- one session is consumed by at most one submitted result
- expired sessions are rejected on result submission

### 6.6 Ranking query contract

Recommended query shape:

```text
GET /rankings?modeId=challenge&period=today&limit=50
```

Recommended response shape:

```json
{
  "modeId": "challenge",
  "period": "today",
  "generatedAt": "2026-03-15T10:01:00Z",
  "entries": [
    {
      "rank": 1,
      "userId": "uid_123",
      "displayName": "あなた",
      "score": 50,
      "totalAnswerTimeMs": 9100
    }
  ]
}
```

## 7. Backend Validation Responsibility

The backend should not try to fully reconstruct or rejudge the quiz run for MVP.

Recommended validation is intentionally minimal:
- authenticated `uid`
- `sessionId` exists
- session belongs to the same `uid`
- session is not yet consumed
- session is not expired

If those conditions pass, the backend may accept the submitted summary as a valid result for MVP leaderboard purposes.

This does not prevent a determined user from modifying their own client-side score.  
It does make casual API abuse, duplicate submissions, and non-session-based result posting much harder.

## 8. Firestore Recommendation

Recommended top-level collections:
- `users`
- `quiz_sessions`
- `racers`
- `quiz_results`
- `ranking_snapshots`

### `users/{uid}`

Recommended fields:
- `displayName`
- `authProviders`
- `createdAt`
- `updatedAt`

### `quiz_sessions/{sessionId}`

Recommended fields:
- `uid`
- `modeId`
- `status`
- `createdAt`
- `expiresAt`
- `consumedAt`

### `racers/{racerId}`

Recommended fields:
- racer contract fields

### `quiz_results/{resultId}`

Recommended fields:
- `uid`
- `sessionId`
- `modeId`
- `score`
- `correctAnswers`
- `totalQuestions`
- `totalAnswerTimeMs`
- `endReason`
- `rankingEligible`
- `continuedByAd`
- `periodKeyDaily`
- `periodKeyTerm`
- `createdAt`

### `ranking_snapshots/{snapshotId}`

Recommended use:
- materialized ranking documents for fast reads
- one document per `modeId + period + bucket`

## 9. Ranking Aggregation Recommendation

For MVP, do not compute rankings on every client read from raw results.

Recommended:
- result write lands in `quiz_results`
- Cloud Function updates the relevant ranking snapshot
- frontend reads pre-aggregated ranking snapshot

Reason:
- simpler client
- predictable read cost
- easier to review ranking behavior

## 10. Worktree-Friendly Responsibility Split

Recommended `frontend` worktree scope:
- `lib/`
- frontend Firebase wiring for auth and API calls
- DTOs and repositories used by Flutter UI

Recommended `backend` worktree scope:
- `functions/` or equivalent Cloud Functions workspace
- Firestore rules
- Firestore indexes
- `firebase.json`
- schema and aggregation logic

Potential shared/conflict files:
- `pubspec.yaml`
- `pubspec.lock`
- `firebase.json`
- `firestore.rules`
- `firestore.indexes.json`
- `internal-docs/`

To reduce collisions:
- keep frontend-only package additions isolated to one branch at a time
- keep backend Firebase config changes isolated to backend branch
- avoid editing the same internal doc from both branches

## 11. Concrete Recommendation For This Repository

Best current boundary:

### Frontend branch should implement next
- replace mock auth with Firebase Auth integration
- replace mock racer repository with backend-backed repository
- add result submission repository
- replace mock ranking screen data with repository-driven state
- keep quiz generation local for MVP

### Backend branch should implement next
- define Firestore collections and indexes
- add Cloud Functions for:
  - quiz session create
  - result submission
  - ranking read
- add minimal session-based validation for result payloads

## 12. Deliberate Non-Goals For MVP

These should not block frontend/backend parallelization:
- moving quiz generation to backend
- full anti-cheat protection
- dynamic backend-driven mode configuration
- friend ranking
- official profile ingestion

## 13. Decisions That Still Need Review

These are the remaining decisions I would want explicit approval on before cutting worktrees:
- keep mode definitions frontend-owned for MVP
- keep question generation frontend-owned for MVP
- backend validates sessions but does not fully reconstruct the whole run
- ranking is served from aggregated snapshot documents, not raw-query sorting

## 14. Suggested Next Step

If this boundary is accepted, the next document should be:
- `internal-docs/backend_contracts.md`

That document should freeze:
- quiz session DTO
- Firestore collection schemas
- result submission DTO
- ranking response DTO
