import "package:firebase_auth/firebase_auth.dart";
import "package:cloud_functions/cloud_functions.dart";
import "package:flutter/foundation.dart";

class AccountDeletionService {
  AccountDeletionService({FirebaseAuth? auth, FirebaseFunctions? functions})
    : _auth = auth ?? FirebaseAuth.instance,
      _functions =
          functions ?? FirebaseFunctions.instanceFor(region: "europe-west2");

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  static bool userProviderIdsRequireAppleRevocation(
    Iterable<String> providerIds,
  ) {
    return providerIds.contains(AppleAuthProvider.PROVIDER_ID);
  }

  static bool canRevokeAppleTokens({
    required bool isWeb,
    required TargetPlatform platform,
  }) {
    return !isWeb && platform == TargetPlatform.iOS;
  }

  Future<void> deleteCurrentAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    await _revokeAppleIfNeeded(user);
    final callable = _functions.httpsCallable("deleteMyAccount");
    await callable.call(<String, dynamic>{});
    await _auth.signOut();
  }

  Future<void> _revokeAppleIfNeeded(User user) async {
    final providerIds = user.providerData
        .map((provider) => provider.providerId)
        .where((providerId) => providerId.isNotEmpty);
    if (!userProviderIdsRequireAppleRevocation(providerIds)) {
      return;
    }
    if (!canRevokeAppleTokens(isWeb: kIsWeb, platform: defaultTargetPlatform)) {
      throw FirebaseException(
        plugin: "firebase_auth",
        code: "apple-revocation-unsupported",
        message:
            "Delete this Apple-linked account from the iPhone app so Apple revocation can be completed.",
      );
    }

    final credential = await user.reauthenticateWithProvider(
      AppleAuthProvider()..addScope("email"),
    );
    final authorizationCode =
        credential.additionalUserInfo?.authorizationCode?.trim() ?? "";
    if (authorizationCode.isEmpty) {
      throw FirebaseException(
        plugin: "firebase_auth",
        code: "missing-authorization-code",
        message:
            "Apple did not return a revocation code. Try again to confirm account deletion.",
      );
    }
    await _auth.revokeTokenWithAuthorizationCode(authorizationCode);
  }
}
