# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is this app?

BoatFace is a Flutter quiz app for learning Japanese boat racers by face, name, and registration number. Players answer multiple-choice questions in timed sessions. The app uses Firebase for auth, Firestore for persistence, and Cloud Functions for ranking aggregation.

## Commands

```bash
# Run the app
flutter run --flavor stg          # Staging
flutter run --flavor prod         # Production

# Testing
flutter test                      # All tests
flutter test test/features/quiz/  # Single feature
flutter test test/features/quiz/application/quiz_session_test.dart  # Single file

# Analysis
flutter analyze

# Firebase config (required before first run)
./scripts/configure_firebase.sh stg
./scripts/configure_firebase.sh prod
```

## Architecture

The app uses **clean architecture** with Riverpod for state management. Each feature under `lib/features/` is split into:

- `domain/` — models and interfaces (pure Dart, no Flutter)
- `application/` — Riverpod providers/notifiers, business logic
- `data/` — repositories, API clients, local caching
- `presentation/` — screens and widgets

Shared utilities (ads, auth, environment config) live in `lib/shared/`.

## Quiz System

This is the core of the app. Understanding the quiz flow requires reading multiple files:

**Question generation** (`quiz_session_factory.dart`):
- Takes a `QuizModeConfig` (defines segments, time limits, prompt types)
- Expands segments into "plan slots" with racer filter conditions
- Materializes slots into `QuizQuestion` objects at runtime
- Racer selection prioritizes fresh racers as targets, similar racers as distractors

**Session lifecycle** (`quiz_session.dart`):
- `QuizSession` is a plain Dart class (not a provider) managing game state
- `QuizSessionController` (Riverpod `AutoDisposeNotifierProviderFamily`) bridges session state to UI
- Timer uses a Stopwatch + periodic ticker; time freeze hint pauses it
- Game ends on wrong answer, timeout, or abandon; one ad-supported continue is allowed

**Quiz modes** (`quiz_modes.dart`): quick (10q/10s), careful (30q/no limit), challenge (50q/partial faces), master (~200q). Modes unlock progressively based on `userProfileProvider`.

**Partial face variants** (`PartialFaceVariant` enum): `zoomOutCenter`, `spotlights`, `tileReveal` — animated reveal effects used in challenge/master modes. Variant selection shifts across quiz progress (zoom early, tiles late).

## State Management Patterns

```dart
// Parameterized provider — quiz session is keyed by mode config
final quizSessionControllerProvider =
  AutoDisposeNotifierProviderFamily<QuizSessionController, QuizSessionState, QuizModeConfig>(...);

// Async value pattern in screens
ref.watch(userProfileProvider).when(
  data: (profile) => ...,
  loading: () => ...,
  error: (err, stack) => ...,
);

// Test overrides
ProviderContainer(overrides: [
  racerRepositoryProvider.overrideWithValue(fakeRepo),
])
```

## Key Models

- **`RacerProfile`** — boat racer with image, name, registration number, class, branch
- **`QuizModeConfig`** — mode definition: segments, time limits, hint allowances
- **`QuizQuestion`** — prompt type, image, 4 options, correct index, partial face variant
- **`QuizResultSummary`** — score, timing, end reason, ranking eligibility, mistakes list
- **`UserProfile`** — uid, region, `quizProgress` (cleared modes, attempt history)

## Frontend/Backend Boundary

- **Frontend owns**: quiz generation, local session state, UI
- **Backend owns**: session issuance, result persistence, ranking aggregation via Cloud Functions
- Racer data is cached locally (`RacerMasterLocalStore`, zip download) to keep quiz generation fully offline-capable
- Rankings are pre-aggregated snapshots (not real-time queries)

## Firebase Flavors

- `stg`: bundle ID `dev.asobo.boatface.stg`
- `prod`: bundle ID `dev.asobo.boatface`

Config files: `android/app/src/{stg,prod}/google-services.json`, `ios/Firebase/{stg,prod}/GoogleService-Info.plist`

## Testing Conventions

- Widget tests use `flutter_test` with Riverpod `ProviderContainer` overrides
- Repositories have fake implementations for testing
- `Completer`/deferred futures are used to test async loading states
