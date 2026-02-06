# Decisions and Risks Log

## Decisions
- 2026-02-01: MVP release target is iOS first.
- 2026-02-01: Location UX uses map picker + approximate pin + geohash.
- 2026-02-06: Public browsing enabled; auth required to publish or contact.
- 2026-02-01: SendGrid selected for transactional email.
- 2026-02-01: Contact flow uses email (no in-app messaging in MVP).
- 2026-02-05: Add Firebase Analytics + Crashlytics for MVP funnel monitoring.
- 2026-02-05: App Check enabled for production (debug providers for local).

## Risks
- Email deliverability depends on SendGrid domain verification.
- Spam/abuse risk on contact flow; ensure rate limits and monitoring.
- Geohash search accuracy may need tuning for radius filters.
- iOS privacy compliance requires clear disclosure for photo/location usage.
- Legal texts are draft and require review before App Store submission.

## Open questions
- Do we need a staging Firebase project?
- Should we add in-app reporting or blocking in MVP?
