# Execution Plan (MVP)

## Decisions (MVP defaults)
- Email provider: SendGrid.
- Location UX: map picker + postcode lookup (UK) + approximate pin + geohash.
- Access model: public browsing; auth required to publish/contact.
- Release target: iOS first.
- Firebase project ID: reloved-greenhilledge.
- iOS bundle ID: com.greenhilledge.reloved.
- Visual direction: white backgrounds with sage green accent.

## Plan status
1. [COMPLETE] Engineering guardrails and docs baseline.
2. [COMPLETE] Product/UX baseline for auth, publish, search, detail, email contact, rating.
3. [COMPLETE] Flutter app + Firebase bootstrap.
4. [COMPLETE] Firestore/Storage model and security base.
5. [COMPLETE] Backend function `sendContactEmail` + contact audit trail.
6. [COMPLETE] Core app features (auth/publish/search/detail/contact/rating/profile).
7. [COMPLETE] Quality tooling (tests, CI for flutter/backend/rules).
8. [COMPLETE] Compliance baseline (privacy/terms/retention, app check).
9. [IN PROGRESS] iOS release prep and distribution.
10. [IN PROGRESS] Post-release analytics funnel expansion.

## Chat rollout (implemented)
11. [COMPLETE] Internal chat by item with email coexistence
   - [COMPLETE] Add `contactPreference` in item model (`email`, `chat`, `both`).
   - [COMPLETE] Add callable functions for chat lifecycle:
     - `upsertItemConversation`
     - `sendChatMessage`
     - `markConversationRead`
     - `closeConversationByDonor`
     - `reopenConversationByDonor`
     - `setItemContactPreference`
     - `blockConversationParticipant`
     - `reportConversation`
   - [COMPLETE] Add conversation archive trigger when item becomes unavailable.
   - [COMPLETE] Add scheduled retention/redaction job for chat data.
   - [COMPLETE] Add admin callable for account-deletion chat anonymization.
   - [COMPLETE] Extend Firestore rules for conversations/messages/chatReports.
   - [COMPLETE] Add Firestore indexes for chat queries.
   - [COMPLETE] Add Inbox tab and Chat thread screens in Flutter.
   - [COMPLETE] Update Item Detail CTA routing by `contactPreference`.
   - [COMPLETE] Keep email contact flow as fallback/parallel path.
   - [COMPLETE] Add analytics events for chat/contact channel selection.

## Validation checklist
- Flutter:
  - `flutter analyze`
  - `flutter test`
- Functions:
  - `npm --prefix backend/functions run build`
  - `npm --prefix backend/functions run test:functions`
  - `npm --prefix backend/functions run test:integration`
- Rules:
  - `npm --prefix backend/functions run test:rules` (requires Firestore emulator)

## Notes
- Rules/integration tests depend on Firebase emulators and compatible Java runtime.
- Chat push notifications are intentionally out of scope for this phase.
