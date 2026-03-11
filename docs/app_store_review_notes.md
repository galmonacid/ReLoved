# App Store Review Notes

## Reviewer Summary
ReLoved is a local reuse app for giving away items. Users can create listings, browse nearby items, contact donors by in-app chat or email, rate exchanges, report abuse, and delete their account in-app.

## Authentication
- Email/password sign-in is available on iOS.
- Google sign-in is available on iOS.
- Sign in with Apple is available on iOS.

## Payments
- Payments are disabled on iOS for this release.
- The shipped iOS build uses `PAYMENTS_ENABLED_IOS=false`.
- Optional supporter payments remain web-only.

## Account Deletion
- Path: `Profile` -> `Delete account`
- This starts deletion directly in-app and does not require contacting support by email.

## Reporting / Safety
- Listing report path: open any non-owned item -> overflow menu -> `Report listing`
- User report path: open any non-owned item -> overflow menu -> `Report user`
- Chat report path remains available from chat surfaces.

## Location Handling
- Listings use an approximate area and geospatial search radius.
- Exact home addresses are not collected or displayed in the app.

## Support
- Support URL: `https://reloved-greenhilledge.web.app/support.html`
- Privacy URL: `https://reloved-greenhilledge.web.app/privacy.html`
- Terms URL: `https://reloved-greenhilledge.web.app/terms.html`
