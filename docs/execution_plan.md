# Execution Plan (MVP)

## Decisions (MVP defaults)
- Email provider: SendGrid (simpler setup, solid docs, good free tier).
- Location UX: Map picker with approximate pin + geohash (avoid geocoding).
- Access model: Authenticated users only.
- Release target: iOS first.
- Firebase project ID: reloved-greenhilledge.
- iOS bundle ID: com.greenhilledge.reloved.

## Plan (start from scratch)
1. [COMPLETE] **Engineering + agentic workflow (guardrails)**
   - [COMPLETE] Define MVP Definition of Done in `docs/definition_of_done.md`.
   - [COMPLETE] Establish agentic change protocol in `docs/agentic_protocol.md`.
   - [COMPLETE] Document environments/secrets in `docs/environments_secrets.md`.
   - [COMPLETE] Maintain decisions + risks log in `docs/decisions_risks_log.md`.
2. [COMPLETE] **Product + UX definition**
   - [COMPLETE] Confirm MVP scope and screens from `docs/`.
   - [COMPLETE] Define flows: sign up/in, create item, browse/search, item detail, contact, rating.
   - [COMPLETE] Choose minimal design system for speed.
   - [COMPLETE] Output: `docs/ux_flows.md`
3. [COMPLETE] **Project bootstrap**
   - [COMPLETE] Create Flutter app in `app/`.
   - [COMPLETE] Create Firebase project and enable Auth, Firestore, Storage, Functions.
   - [COMPLETE] Run FlutterFire configure and add iOS bundle ID.
4. [COMPLETE] **Data model + security**
   - [COMPLETE] Implement Firestore rules with required fields, ownerId locking, and rating constraints.
   - [COMPLETE] Add Storage rules for item photos.
   - [COMPLETE] Add Firestore indexes for geo + recent ordering.
5. [COMPLETE] **Backend (Functions)**
   - [COMPLETE] Implement `sendContactEmail` with SendGrid integration.
   - [COMPLETE] Validate auth, item ownership, and rate limits.
   - [COMPLETE] Store full `contactRequests` record.
6. [] **App core features**
   - [] Auth screens + profile creation.
   - [] Item create: photo upload + map pin selection + geohash.
   - [] Search: radius filter (5 km / 20 km) + recent ordering.
   - [] Item detail: contact form + send request.
   - [] Ratings flow after exchange.
   - [] Empty/loading/error states for each screen.
   - [] Basic accessibility pass (labels, tap targets, contrast).
   - [] Permission handling for photos and location (if needed).
7. [] **Quality + tooling**
   - [] Set up emulators for Firestore/Functions/Storage.
   - [COMPLETE] Add unit tests for shared utils/models (geo + mapping).
   - [COMPLETE] Add local verification script `scripts/verify_local.sh`.
   - [] Add rules tests for Firestore + Storage with emulators.
   - [] Add function tests (mock SendGrid, validate inputs, rate limit).
   - [] Add integration tests for critical flows (auth, publish, contact).
   - [COMPLETE] Configure CI for Flutter analyze/test.
   - [COMPLETE] Configure CI for Functions build.
   - [] Configure CI for rules tests.
8. [] **Release hardening + compliance**
   - [] Add Crashlytics and basic analytics events for the funnel.
   - [] Add privacy policy + terms and App Store privacy details.
   - [] Configure Firebase App Check (production and emulator).
   - [] Add data retention + account deletion process.
   - [] Add performance hygiene (image compression, basic caching).
9. [] **iOS release prep**
   - [] App icons, launch screen, and basic App Store metadata.
   - [] Build and distribute via TestFlight.
   - [] Deploy Firestore rules, indexes, Storage rules, and Functions.

## Dependencies / prerequisites
- [] Apple Developer account (TestFlight + App Store).
- [] SendGrid account and API key.
