# Execution Plan (MVP)

## Decisions (MVP defaults)
- Email provider: SendGrid (simpler setup, solid docs, good free tier).
- Location UX: Map picker with approximate pin + geohash (avoid geocoding).
- Access model: Authenticated users only.
- Release target: iOS first.
- Firebase project ID: reloved-greenhilledge.
- iOS bundle ID: com.greenhilledge.reloved.

## Plan (start from scratch)
1. **Product + UX definition**
   - Confirm MVP scope and screens from `docs/`.
   - Define flows: sign up/in, create item, browse/search, item detail, contact, rating.
   - Choose minimal design system for speed.
   - Output: `docs/ux_flows.md`
2. **Project bootstrap**
   - Create Flutter app in `app/`.
   - Create Firebase project and enable Auth, Firestore, Storage, Functions.
   - Run FlutterFire configure and add iOS bundle ID.
3. **Data model + security**
   - Implement Firestore rules with required fields, ownerId locking, and rating constraints.
   - Add Storage rules for item photos.
   - Add Firestore indexes for geo + recent ordering.
4. **Backend (Functions)**
   - Implement `sendContactEmail` with SendGrid integration.
   - Validate auth, item ownership, and rate limits.
   - Store full `contactRequests` record.
5. **App core features**
   - Auth screens + profile creation.
   - Item create: photo upload + map pin selection + geohash.
   - Search: radius filter (5 km / 20 km) + recent ordering.
   - Item detail: contact form + send request.
   - Ratings flow after exchange.
6. **Quality + tooling**
   - Set up emulators for Firestore/Functions/Storage.
   - Add basic tests for rules and function validations.
   - Configure CI for Flutter analyze/test (optional for MVP).
7. **iOS release prep**
   - App icons, launch screen, and basic App Store metadata.
   - Build and distribute via TestFlight.
   - Deploy Firestore rules, indexes, Storage rules, and Functions.

## Dependencies / prerequisites
- Apple Developer account (TestFlight + App Store).
- SendGrid account and API key.
