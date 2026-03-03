import "package:flutter/foundation.dart";
import "package:flutter_test/flutter_test.dart";
import "package:app/src/auth/auth_service.dart";
import "package:firebase_auth/firebase_auth.dart";

void main() {
  group("resolveLinkStrategy", () {
    test("prioritizes password when available", () {
      final strategy = resolveLinkStrategy([
        EmailAuthProvider.EMAIL_PASSWORD_SIGN_IN_METHOD,
        GoogleAuthProvider.GOOGLE_SIGN_IN_METHOD,
      ]);
      expect(strategy, AuthLinkStrategy.password);
    });

    test("returns google when only google method exists", () {
      final strategy = resolveLinkStrategy([
        GoogleAuthProvider.GOOGLE_SIGN_IN_METHOD,
      ]);
      expect(strategy, AuthLinkStrategy.google);
    });

    test("returns unsupported when no known methods exist", () {
      final strategy = resolveLinkStrategy(["phone"]);
      expect(strategy, AuthLinkStrategy.unsupported);
    });
  });

  group("platform support", () {
    test("google is supported on web", () {
      expect(
        isGoogleSignInSupported(isWeb: true, platform: TargetPlatform.android),
        isTrue,
      );
    });

    test("google is supported on iOS native", () {
      expect(
        isGoogleSignInSupported(isWeb: false, platform: TargetPlatform.iOS),
        isTrue,
      );
    });

    test("google is not supported on Android native in this release", () {
      expect(
        isGoogleSignInSupported(isWeb: false, platform: TargetPlatform.android),
        isFalse,
      );
    });
  });
}
