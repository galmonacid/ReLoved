# Next Steps (Resume Guide)

Date: 2026-02-20

## Project State Snapshot
- Phase 9 (iOS release prep) is mostly complete.
- App icons regenerated from `docs/img/reloved_logo.png` (cropped 10%, no padding).
- Launch screen updated with copy:
  - “Less waste. Give what you don’t need. Find what you need.”
- App Store metadata drafted in `docs/app_store_metadata.md`.
- Support page created at `public/support.html`.
- Distances are in **miles** (3 mi / 10 mi) across docs and metadata.

## What’s Still Pending (Phase 9)
1. **TestFlight build upload** (requires GitHub Actions or a Mac with Xcode).
2. **Firebase deploy** (rules/indexes/storage/functions).

## GitHub Actions TestFlight Setup (Required Before Upload)
Workflow added:
- `.github/workflows/ios_testflight.yml`

Fastlane setup:
- `app/ios/fastlane/Fastfile`
- `app/ios/fastlane/Appfile`
- `app/ios/ExportOptions.plist.template`

Secrets needed (documented in `docs/environments_secrets.md`):
- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_KEY_CONTENT` (base64 of .p8)
- `IOS_CERT_P12_BASE64` (base64 of .p12)
- `IOS_CERT_PASSWORD`
- `IOS_PROFILE_BASE64` (base64 of .mobileprovision)
- `IOS_PROFILE_NAME`
- `KEYCHAIN_PASSWORD`

After secrets are added:
- Run GitHub Actions → **iOS TestFlight** → Run workflow.

## Firebase Deploy (Needs Approval)
Command to run:
```
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```
Target project: `reloved-greenhilledge`

## TestFlight (Internal Testers)
Add these internal testers in App Store Connect:
- sarabarrena@gmail.com
- guillermoalmonacid@gmail.com

## Latest Validations
- `flutter analyze` passed.
- `flutter test` passed.
- iOS build was not run locally (Xcode not installed).

## Suggested Prompt for Next Session
“Resume Phase 9. Use `docs/next_steps.md`. Help me set GitHub Actions secrets for TestFlight and run the workflow, then deploy Firebase.”

## Prompt (ES)
“Retoma la Fase 9. Usa `docs/next_steps.md`. Ayúdame a configurar los secrets de GitHub Actions para TestFlight y a ejecutar el workflow; después haz el deploy de Firebase.”
