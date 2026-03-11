import "package:app/src/auth/account_deletion_service.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/foundation.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("AccountDeletionService helpers", () {
    test("requires Apple revocation when apple provider is linked", () {
      expect(
        AccountDeletionService.userProviderIdsRequireAppleRevocation([
          AppleAuthProvider.PROVIDER_ID,
          GoogleAuthProvider.PROVIDER_ID,
        ]),
        isTrue,
      );
    });

    test("does not require Apple revocation for non-apple providers", () {
      expect(
        AccountDeletionService.userProviderIdsRequireAppleRevocation([
          GoogleAuthProvider.PROVIDER_ID,
          EmailAuthProvider.PROVIDER_ID,
        ]),
        isFalse,
      );
    });

    test("apple revocation is supported on iOS only", () {
      expect(
        AccountDeletionService.canRevokeAppleTokens(
          isWeb: false,
          platform: TargetPlatform.iOS,
        ),
        isTrue,
      );
      expect(
        AccountDeletionService.canRevokeAppleTokens(
          isWeb: true,
          platform: TargetPlatform.iOS,
        ),
        isFalse,
      );
      expect(
        AccountDeletionService.canRevokeAppleTokens(
          isWeb: false,
          platform: TargetPlatform.android,
        ),
        isFalse,
      );
    });
  });
}
