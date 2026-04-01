# BoatFace Backend Contracts v0.1

Last updated: 2026-03-31

## 1. Purpose

This document freezes the first backend-facing contracts needed to let frontend and backend move independently.

This version assumes:
- Firebase Authentication is used
- Firestore is used
- Cloud Functions is used
- quiz generation remains frontend-owned for MVP
- backend only performs minimal session-based validation
- staging and production use separate Firebase projects

## 2. Environment Assumptions

Recommended Firebase project layout:
- `boatface-stg`
- `boatface-prod`

Reason:
- safer Firestore rule iteration
- safer ranking and aggregation testing
- no accidental pollution of production leaderboard data

Frontend and backend should treat environment selection as config, not as code branching.

## 3. Auth Contract

Authentication providers for MVP:
- anonymous
- Google
- Game Center

Backend assumptions:
- every protected backend entry point requires a verified Firebase Auth user
- backend uses `uid` as the canonical user identifier
- user profile metadata is stored in Firestore under `users/{uid}`

Recommended `users/{uid}` shape:

```json
{
  "displayName": "ゲスト",
  "nickname": "ボート好き",
  "region": {
    "category": "prefecture",
    "code": "tokyo",
    "label": "東京都"
  },
  "quizProgress": {
    "totalAttempts": 12,
    "attemptCountsByMode": {
      "quick": 5,
      "careful": 4,
      "custom": 3
    },
    "clearedModeIds": ["quick", "careful"],
    "clearedAtByMode": {
      "quick": "server timestamp",
      "careful": "server timestamp"
    },
    "lastAttemptAt": "server timestamp",
    "lastAttemptModeId": "custom",
    "lastClearedAt": "server timestamp",
    "lastClearedModeId": "careful",
    "updatedAt": "server timestamp"
  },
  "authProviders": ["anonymous"],
  "createdAt": "server timestamp",
  "updatedAt": "server timestamp"
}
```

Profile read/update endpoints:
- `GET /getMyProfile`
- `POST /updateMyProfile`

Recommended profile response:

```json
{
  "uid": "uid_123",
  "displayName": "Auth Display Name",
  "nickname": "ボート好き",
  "rankingDisplayName": "ボート好き",
  "region": {
    "category": "prefecture",
    "code": "tokyo",
    "label": "東京都"
  }
}
```

## 4. Session Contract

The backend issues one quiz session before each run.

### Create session

Operation:
- `POST /quiz-sessions`

Request:

```json
{
  "modeId": "challenge"
}
```

Response:

```json
{
  "sessionId": "qs_01HQ...",
  "expiresAt": "2026-03-15T10:15:00Z"
}
```

Rules:
- backend generates `sessionId`
- a session belongs to exactly one `uid`
- a session is valid for one result submission only
- expired sessions cannot be consumed
- mode ids are validated against an allowlist on the backend

Recommended `quiz_sessions/{sessionId}` shape:

```json
{
  "uid": "firebase uid",
  "modeId": "challenge",
  "status": "issued",
  "createdAt": "server timestamp",
  "expiresAt": "server timestamp",
  "consumedAt": null
}
```

Operational note:
- configure a Firestore TTL policy on `quiz_sessions.expiresAt`
- prefer disabling single-field indexing for that TTL field to avoid unnecessary timestamp hotspotting

Allowed `status` values:
- `issued`
- `consumed`
- `expired`

## 5. Result Submission Contract

Operation:
- `POST /quiz-results`

Request:

```json
{
  "sessionId": "qs_01HQ...",
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

Backend minimum validation:
- authenticated user exists
- `sessionId` exists
- `sessionId` belongs to the authenticated `uid`
- `sessionId` is not yet consumed
- `sessionId` is not expired

Backend intentionally does not:
- reconstruct each question
- re-score the whole run
- verify each answer

This is acceptable for MVP because the goal is to prevent casual abuse, not determined client-side tampering.

Recommended `quiz_results/{resultId}` shape:

```json
{
  "uid": "firebase uid",
  "sessionId": "qs_01HQ...",
  "modeId": "challenge",
  "modeLabel": "チャレンジ",
  "score": 32,
  "correctAnswers": 32,
  "totalQuestions": 50,
  "totalAnswerTimeMs": 28400,
  "endReason": "wrongAnswer",
  "rankingEligible": true,
  "continuedByAd": true,
  "clientFinishedAt": "2026-03-15T10:00:00Z",
  "periodKeyDaily": "2026-03-15",
  "periodKeyTerm": "2026-H1",
  "createdAt": "server timestamp"
}
```

Backend write behavior:
- store the result
- mark the referenced session as `consumed`
- increment `users/{uid}.quizProgress.totalAttempts` and `users/{uid}.quizProgress.attemptCountsByMode.{modeId}`
- when a non-custom mode ends with `endReason = completed`, record it under `users/{uid}.quizProgress.clearedModeIds`
- trigger ranking snapshot refresh for the relevant buckets
- for non-custom modes, update `users/{uid}/quiz_high_scores/{modeId}_{termKey}` when the submitted score exceeds the stored term high score

Recommended `users/{uid}/quiz_high_scores/{modeId}_{termKey}` shape:

```json
{
  "uid": "firebase uid",
  "modeId": "challenge",
  "periodKeyTerm": "2026-H1",
  "bestScore": 32,
  "resultId": "result_123",
  "sessionId": "qs_01HQ...",
  "createdAt": "server timestamp",
  "updatedAt": "server timestamp"
}
```

Notes:
- term high scores are tracked per `uid + modeId + periodKeyTerm`
- custom mode does not create or update a term high score record

### Mistake review snapshot

To support later review without bloating leaderboard-oriented result rows, keep recent quiz mistakes in a separate per-user collection:

`users/{uid}/quiz_mistakes/{mistakeId}`

Recommended rules:
- store at question level, not at run level
- keep only the most recent 10 records per user
- write it alongside result submission
- include enough denormalized prompt and option data to render a review UI without re-generating the quiz

Recommended `users/{uid}/quiz_mistakes/{mistakeId}` shape:

```json
{
  "resultId": "qr_01HQ...",
  "sessionId": "qs_01HQ...",
  "modeId": "challenge",
  "modeLabel": "チャレンジ",
  "questionIndex": 7,
  "mistakeSequence": 0,
  "promptType": "faceToName",
  "prompt": "この選手は誰？",
  "promptImageUrl": "https://...",
  "options": [
    {
      "racerId": "racer_1",
      "label": "山田 太郎",
      "labelReading": "やまだ たろう",
      "imageUrl": null
    }
  ],
  "correctIndex": 0,
  "selectedIndex": 2,
  "correctRacerId": "racer_1",
  "selectedRacerId": "racer_3",
  "elapsedMs": 1430,
  "outcome": "wrongAnswer",
  "sortKey": 1711846800000,
  "createdAt": "server timestamp"
}
```

Recommended review read endpoint:
- `GET /getMyQuizMistakes`

Recommended review response:

```json
{
  "mistakes": [
    {
      "mistakeId": "mistake_123",
      "resultId": "qr_01HQ...",
      "sessionId": "qs_01HQ...",
      "modeId": "challenge",
      "modeLabel": "チャレンジ",
      "questionIndex": 7,
      "mistakeSequence": 0,
      "promptType": "faceToName",
      "prompt": "この選手は誰？",
      "promptImageUrl": "https://...",
      "options": [],
      "correctIndex": 0,
      "selectedIndex": 2,
      "correctRacerId": "racer_1",
      "selectedRacerId": "racer_3",
      "correctOption": {
        "racerId": "racer_1",
        "label": "山田 太郎",
        "labelReading": "やまだ たろう",
        "imageUrl": null
      },
      "selectedOption": {
        "racerId": "racer_3",
        "label": "佐藤 花子",
        "labelReading": "さとう はなこ",
        "imageUrl": null
      },
      "elapsedMs": 1430,
      "outcome": "wrongAnswer",
      "createdAt": "2026-03-22T12:00:00.000Z"
    }
  ]
}
```

## 6. Ranking Read Contract

Operation:
- `GET /rankings?modeId=challenge&period=today&limit=50`

Authentication:
- required

Allowed `period` values:
- `today`
- `term`

Response:

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
      "region": {
        "category": "prefecture",
        "code": "tokyo",
        "label": "東京都"
      },
      "score": 50,
      "totalAnswerTimeMs": 9100
    }
  ]
}
```

Ranking sort order:
- `score` descending
- `totalAnswerTimeMs` ascending

Recommended source:
- aggregated snapshot documents, not raw ad hoc result queries

## 7. Racer Read Contract

For MVP, frontend only needs a read-only racer pool.

Operation:
- `GET /racers`

Optional filters:
- `active=true`

Response item shape:

```json
{
  "id": "racer-1234",
  "name": "選手1234",
  "registrationNumber": 1234,
  "imageUrl": "https://...",
  "imageSource": "official-profile",
  "updatedAt": "2026-03-15T00:00:00Z",
  "isActive": true
}
```

Recommended `racers/{racerId}` shape:

```json
{
  "name": "選手1234",
  "registrationNumber": 1234,
  "imageUrl": "https://...",
  "imageSource": "official-profile",
  "updatedAt": "server timestamp",
  "isActive": true
}
```

## 8. Snapshot Storage Contract

Recommended `ranking_snapshots/{snapshotId}` shape:

```json
{
  "modeId": "challenge",
  "period": "today",
  "generatedAt": "server timestamp",
  "entries": [
    {
      "rank": 1,
      "userId": "uid_123",
      "displayName": "ゲスト",
      "region": null,
      "score": 50,
      "totalAnswerTimeMs": 9100
    }
  ]
}
```

Recommended snapshot id convention:
- `today_challenge_2026-03-15`
- `term_challenge_2026-H1`

## 9. Period Key Rules

Daily bucket:
- JST day boundary at `00:00`

Term bucket:
- `H1`: January 1 to June 30
- `H2`: July 1 to December 31

Recommended stored keys:
- `periodKeyDaily`: `YYYY-MM-DD`
- `periodKeyTerm`: `YYYY-H1` or `YYYY-H2`

## 10. Firestore Rules Direction

Recommended security posture:
- clients do not write directly to `quiz_sessions`
- clients do not write directly to `quiz_results`
- clients do not write directly to `ranking_snapshots`
- client writes are limited to fields explicitly owned by the client, if any
- privileged writes happen through Cloud Functions using admin SDK

This keeps leaderboard-critical writes out of direct client control.

## 11. Cloud Functions Surface

Recommended first functions:
- `createQuizSession`
- `submitQuizResult`
- `getRankings`
- `getRacers`

Implementation style:
- HTTP functions are acceptable for MVP
- callable functions are also acceptable if frontend chooses Firebase Functions SDK integration

Recommendation:
- use HTTP functions first because the contracts are easier to review as explicit request/response DTOs

## 12. Staging Checklist

Before backend integration starts against real Firebase, the user should prepare:
- a staging Firebase project
- Authentication enabled for anonymous and Google
- Firestore enabled
- Cloud Functions enabled
- chosen Firestore location
- chosen Functions region

Recommended to confirm later:
- staging `projectId`: `boatface-stg`
- production `projectId`
- Functions region
- Firestore location

Current staging Storage bucket:
- `gs://boatface-stg.firebasestorage.app`

## 13. Open Decisions

Still open, but not blocking this scaffold:
- exact session TTL
- whether rankings should be top 50 or top 100 by default
- whether racer read is direct Firestore read or via Cloud Function
- whether HTTP or callable functions should be the final API surface
