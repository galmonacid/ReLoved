# Environments and Secrets

## Environments
- Local development (emulators)
- Staging (optional)
- Production

## Required Firebase configuration
- Project ID: reloved-greenhilledge
- iOS bundle ID: com.greenhilledge.reloved
- Firebase Auth providers enabled:
  - Google
  - Apple
- Authorized domains:
  - reloved-greenhilledge.web.app
  - reloved-greenhilledge.firebaseapp.com
  - localhost

## Cloud Functions config (production)
- SendGrid API key
- SendGrid from email

Example (do not commit secrets):
```
firebase functions:config:set sendgrid.key="REDACTED" sendgrid.from="noreply@yourdomain.com"
firebase functions:config:get
```

## Local setup notes
- Use Firebase emulators for Firestore, Functions, and Storage.
- For local SendGrid testing, mock the mailer or use a sandbox key.
 - Use `firebase emulators:start` when developing functions and rules locally.

## Secrets handling
- Do not store secrets in the repo.
- Use `firebase functions:config:set` or environment variables.
- Document any new required keys here.

## App build-time config (Flutter --dart-define)
- PRIVACY_POLICY_URL (public URL)
- TERMS_URL (public URL)
- SUPPORT_EMAIL (support inbox for deletion requests)
- APP_CHECK_WEB_KEY (reCAPTCHA v3 site key for App Check on web)
- SHARE_BASE_URL (base URL for share links, recommended: https://reloved-greenhilledge.web.app)
- IOS_TEAM_ID (Apple Developer Team ID for Universal Links): QUJ832A56F
- IOS_APP_STORE_ID (App Store ID for app store fallback): 6759441963
- ANDROID_PACKAGE_NAME (package name for Android deep link fallback)
 - APP_STORE_DISPLAY_NAME (App Store name): ReLoved - Give & Find
  - This is the public App Store listing name (separate from the internal app name).

## Chat operations config
- No new external secret is required for chat core flows.
- Optional operational requirement: admin custom claim for invoking `anonymizeUserChatData`.
- Chat retention job (`purgeOldChatData`) runs on Cloud Scheduler / PubSub.

## Apple App ID setup (iOS)
- Capabilities enabled on App ID: Associated Domains (for Universal Links), Push Notifications.
- Implementation is pending; enable now to avoid reissuing profiles later.
- Sign in with Apple capability enabled for `com.greenhilledge.reloved`.
- Firebase Apple provider configured with Team ID, Service ID, Key ID and private key.

## iOS Google Sign-In setup
- `GoogleService-Info.plist` must contain OAuth keys (`CLIENT_ID` and `REVERSED_CLIENT_ID`).
- `Info.plist` must include `CFBundleURLTypes` scheme for `REVERSED_CLIENT_ID`.
- If missing, regenerate iOS Firebase config after enabling Google provider and update plist files.

## Current status - iOS Google Sign-In
- Resolved in repository:
  - `app/ios/Runner/Info.plist` now uses a real `REVERSED_CLIENT_ID` URL scheme.
  - `app/ios/Runner/GoogleService-Info.plist` includes `CLIENT_ID` and `REVERSED_CLIENT_ID`.
- Keep this as a pre-release check for future Firebase plist rotations.

## Runbook: resolve iOS Google Sign-In configuration
1. In Firebase Console (`reloved-greenhilledge`), open Authentication -> Sign-in method.
2. Enable Google provider and set project support email.
3. In Firebase Console -> Project settings -> Your apps -> iOS app (`com.greenhilledge.reloved`), download fresh `GoogleService-Info.plist`.
4. Replace `app/ios/Runner/GoogleService-Info.plist` with the downloaded file.
5. Verify the new plist contains non-empty `CLIENT_ID` and `REVERSED_CLIENT_ID`.
6. Update `app/ios/Runner/Info.plist`:
   - In `CFBundleURLTypes`, replace placeholder scheme with the exact `REVERSED_CLIENT_ID`.
7. Validate locally:
   - `cd app && flutter clean`
   - `cd app && flutter pub get`
   - `cd app && flutter analyze`
   - `cd app && flutter test`
   - `cd app && flutter run -d ios` and verify Google sign-in end-to-end.
8. Release safety check before TestFlight:
   - Ensure no `REPLACE_WITH_REVERSED_CLIENT_ID` string remains in app config files.

## Hosting (legal pages)
- Privacy policy URL (Hosting): /privacy.html
- Terms of service URL (Hosting): /terms.html
- Support URL (Hosting): /support.html
- Hosting serves Flutter web from `app/build/web`.
- Deploy workflow copies `public/privacy.html`, `public/terms.html`, `public/support.html`, and `public/item_link.html` into `app/build/web`.

## Share deep links behavior
- Shared links use `/items/{itemId}` on `SHARE_BASE_URL`.
- Hosting rewrites `/items/**` to `/item_link.html` (smart link handler), then catch-all to `/index.html`.
- iPhone:
  - App installed: opens app via `reloved://items/{itemId}`.
  - App not installed: redirects to App Store (`IOS_APP_STORE_ID`).
- Android/desktop: redirects to the web detail flow (`/?shared_item_id={itemId}`).

## GitHub Actions (iOS TestFlight)
Required secrets:
- ASC_KEY_ID (App Store Connect API key ID)
- ASC_ISSUER_ID (App Store Connect API issuer ID)
- ASC_KEY_CONTENT (App Store Connect API .p8 key, base64)
- IOS_CERT_P12_BASE64 (App Store signing cert .p12, base64)
- IOS_CERT_PASSWORD (password for .p12)
- IOS_PROFILE_BASE64 (App Store provisioning profile, base64)
- IOS_PROFILE_NAME (provisioning profile name, e.g. "ReLoved AppStore")
- KEYCHAIN_PASSWORD (temporary CI keychain password)
