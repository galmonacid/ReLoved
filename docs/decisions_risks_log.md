# Decisions and Risks Log

## Decisions
- 2026-02-01: MVP release target is iOS first.
- 2026-02-01: Location UX uses map picker + approximate pin + geohash.
- 2026-02-06: Public browsing enabled; auth required to publish or contact.
- 2026-02-01: SendGrid selected for transactional email.
- 2026-02-05: Add Firebase Analytics + Crashlytics for MVP funnel monitoring.
- 2026-02-05: App Check enabled for production (debug providers for local).
- 2026-03-01: Contact model upgraded to per-item channel preference (`email` | `chat` | `both`).
- 2026-03-01: Chat scope fixed to 1:1 per item + interested user (no global user chat).
- 2026-03-01: Donor can close/reopen chat; auto-archive when item is unavailable.
- 2026-03-01: Chat notifications limited to in-app inbox (no push in this phase).
- 2026-03-01: Safety baseline for chat: rate limiting + block + report.

## Risks
- Email deliverability depends on SendGrid domain verification.
- Spam/abuse risk on contact flow and chat flow.
- Chat moderation is basic/manual in current phase.
- Geohash search accuracy may need tuning for radius filters.
- iOS privacy compliance requires clear disclosure for photo/location/chat usage.
- Legal texts require periodic compliance review.
- Firebase composite indexes for chat queries must remain in sync with app/query changes.

## Open questions
- Do we need a staging Firebase project?
- Should push notifications be prioritized for chat response rates?
- Should we add automatic content moderation for reported chats?
