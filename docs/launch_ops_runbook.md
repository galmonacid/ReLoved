# Launch Ops Runbook

## Scope
This covers early-adopter launch operations for UK traffic on Firebase, with expected usage below 10k users.

## Daily Checks
- Firebase Functions error rate and cold-start spikes
- Firestore read/write volume and rejected requests
- Storage bandwidth and failed uploads
- Crashlytics fatal issues
- SendGrid delivery failures for contact emails
- Stripe webhook failures and stuck checkout sessions
- Moderation queues: `chatReports`, `listingReports`, `userReports`

## Alerts To Configure
- Cloud Functions error count above baseline
- Firestore quota usage above 70%
- Storage egress spikes above baseline
- SendGrid API failures or bounce spikes
- Stripe webhook non-2xx responses
- Repeated abuse reports against the same user or listing

## Manual Response Paths
- Abuse reports: review Firestore report docs, suspend abusive accounts through Firebase Auth, and anonymize chat data if required
- Failed contact emails: check `contactRequests` for `sent=false` and SendGrid logs
- Billing issues: check `stripeWebhookEvents`, `billingCustomers`, and `monetizationProfiles`
- Deletion issues: inspect `deleteMyAccount` function logs and confirm removal of `users`, `items`, `contactRequests`, and moderation docs

## Pre-Launch Checklist
- `flutter analyze`
- `flutter test`
- `npm --prefix backend/functions run test:functions`
- Backend emulator suite on Java 21
- iOS no-codesign release build in CI
- Firebase deploy dry run from main branch credentials
- Legal pages published and accessible
