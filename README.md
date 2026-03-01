# ReLoved

ReLoved is a mobile app concept focused on giving items you no longer need a **second life** — so someone else can enjoy them. The MVP prioritizes speed of delivery using **Flutter + Firebase**.

## Repo structure
- `docs/` — product & technical documentation
- `app/` — Flutter mobile app
- `backend/functions/` — Firebase Cloud Functions (TypeScript) for email contact (MVP)
- `firebase/` — Firestore/Storage rules and Firestore indexes

## Planning
- `docs/execution_plan.md` — end-to-end MVP execution plan

## Quick start (local)
### Prereqs
- Flutter SDK
- VS Code + Flutter/Dart extensions
- Firebase CLI
- Node.js (for Cloud Functions)

### 1) Connect the app to Firebase (recommended: FlutterFire CLI)
From the repo root:
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```
This generates `lib/firebase_options.dart` and adds platform config files.

### 2) Run the app
```bash
cd app
flutter run --dart-define=SHARE_BASE_URL=https://reloved-greenhilledge.web.app
```

### 3) Initialize Firebase resources (once)
From the repo root:
```bash
firebase login
firebase init firestore storage functions
```
Copy/keep rules and indexes from the `firebase/` folder.

### 4) Deploy backend (rules, indexes, functions)
```bash
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

## MVP scope
- User registration/login (email + password)
- Public browsing; auth required to publish or contact
- Create item listing (photo, title, description, UK postcode, automatic date)
- Search items within 3 mi / 10 mi + keyword search
- Contact owner via email form (no in-app chat in MVP)
- Simple user ratings (1–5)

## Fast follower
- In-app chat (text-only) after MVP is validated

## GitHub Actions (CI + Deploy)
This repo includes two workflows:
- **CI (Flutter)**: runs `flutter analyze` + `flutter test` on PRs and pushes to `main`.
- **Deploy (Firebase backend)**: deploys Firestore rules/indexes, Storage rules, and Functions after backend CI succeeds.

### Required secrets
To enable Firebase deploy from GitHub Actions, configure **one** of:
- WIF (recommended): `GCP_WORKLOAD_IDENTITY_PROVIDER` + `GCP_SERVICE_ACCOUNT`
- Service account JSON (legacy): `FIREBASE_SERVICE_ACCOUNT`

Notes:
- The Firebase project used by default is set in `.firebaserc` (`default: reloved-greenhilledge`).
