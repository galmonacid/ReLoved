# Decisions and Risks Log

## Decisions
- 2026-02-01: MVP release target is iOS first.
- 2026-02-01: Location UX uses map picker + approximate pin + geohash.
- 2026-02-01: Authenticated users only.
- 2026-02-01: SendGrid selected for transactional email.
- 2026-02-01: Contact flow uses email (no in-app messaging in MVP).

## Risks
- Email deliverability depends on SendGrid domain verification.
- Spam/abuse risk on contact flow; ensure rate limits and monitoring.
- Geohash search accuracy may need tuning for radius filters.
- iOS privacy compliance requires clear disclosure for photo/location usage.

## Open questions
- Do we need a staging Firebase project?
- Should we add in-app reporting or blocking in MVP?
