# Sign In With Apple Setup

  ## Apple Developer
  - Open the App ID for `com.greenhilledge.reloved`.
  - Enable the `Sign In with Apple` capability.
  - Create a `Services ID` for web/Firebase Auth redirect support if not already present.
  - Create a `Sign in with Apple` key and record:
    - Team ID
    - Key ID
    - Private key `.p8`

  ## Firebase Auth
  - In Firebase Console -> Authentication -> Sign-in method, enable `Apple`.
  - Fill in:
    - Services ID
    - Apple Team ID
    - Key ID
    - Private key contents
  - Add the authorized domain used by Hosting if needed.

  ## iOS Project
  - This repo now includes the iOS entitlement and build settings for Sign in with Apple.
  - Build with `GOOGLE_SIGN_IN_IOS=true` and `PAYMENTS_ENABLED_IOS=false` for App Store submission.

  ## Validation
  - On a real iPhone, verify:
    - New Apple account creation
    - Existing email/password account linking to Apple
    - Existing Google account linking to Apple
    - Account deletion for an Apple-linked account, including the Apple confirmation sheet
