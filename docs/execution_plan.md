# Execution Plan (MVP)

## Decisions (MVP defaults)
- Email provider: SendGrid (simpler setup, solid docs, good free tier).
- Location UX: Map picker with postcode lookup (UK) + approximate pin + geohash.
- Access model: Public browsing; auth required to publish or contact.
- Release target: iOS first.
- Firebase project ID: reloved-greenhilledge.
- iOS bundle ID: com.greenhilledge.reloved.
- Visual direction: white backgrounds with sage green as the primary accent.

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
6. [COMPLETE] **App core features**
   - [COMPLETE] Auth screens + profile creation.
   - [COMPLETE] Item create: photo upload + map pin selection + geohash.
   - [COMPLETE] UK postcode lookup for location selection.
   - [COMPLETE] Item description field for listings.
   - [COMPLETE] Search: radius filter (5 km / 20 km) + recent ordering.
   - [COMPLETE] Keyword search across title + description.
   - [COMPLETE] Item detail: contact form + send request.
   - [COMPLETE] Ratings flow after exchange.
   - [COMPLETE] "Mis items" list for owners with status updates.
   - [COMPLETE] Empty/loading/error states for each screen.
   - [COMPLETE] Basic accessibility pass (labels, tap targets, contrast).
   - [COMPLETE] Permission handling for photos and location (if needed).
   - [COMPLETE] Default location uses device position.
7. [COMPLETE] **Quality + tooling**
   - [COMPLETE] Set up emulators for Firestore/Functions/Storage.
   - [COMPLETE] Add unit tests for shared utils/models (geo + mapping).
   - [COMPLETE] Add local verification script `scripts/verify_local.sh`.
   - [COMPLETE] Add rules tests for Firestore + Storage with emulators.
   - [COMPLETE] Add function tests (mock SendGrid, validate inputs).
   - [COMPLETE] Add integration tests for critical flows (auth, publish, contact).
   - [COMPLETE] Configure CI for Flutter analyze/test.
   - [COMPLETE] Configure CI for Functions build.
   - [COMPLETE] Configure CI for rules tests.
8. [COMPLETE] **Release hardening + compliance**
   - [COMPLETE] Add Crashlytics and basic analytics events for the funnel.
   - [COMPLETE] Add privacy policy + terms and App Store privacy details (draft docs).
   - [COMPLETE] Configure Firebase App Check (production and emulator).
   - [COMPLETE] Add data retention + account deletion process (manual MVP flow).
   - [COMPLETE] Add performance hygiene (image compression, basic caching).
9. [] **iOS release prep**
   - [] Enroll in Apple Developer Program (UK, £79/year) and obtain Team ID.
   - [] Create App Store Connect record and capture App Store ID.
   - [] App icons, launch screen, and basic App Store metadata.
   - [] Build and distribute via TestFlight.
   - [] Deploy Firestore rules, indexes, Storage rules, and Functions.

10. [] **Post-release growth + insights**
   - [] Create analytics funnels in Firebase (login → publish → contact).
