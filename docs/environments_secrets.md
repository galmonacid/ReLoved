# Environments and Secrets

## Environments
- Local development (emulators)
- Staging (optional)
- Production

## Required Firebase configuration
- Project ID: reloved-greenhilledge
- iOS bundle ID: com.greenhilledge.reloved

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
