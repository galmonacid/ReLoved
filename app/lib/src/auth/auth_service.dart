import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/foundation.dart";
import "package:google_sign_in/google_sign_in.dart";

enum AuthLinkStrategy { password, google, unsupported }

AuthLinkStrategy resolveLinkStrategy(List<String> methods) {
  if (methods.contains(EmailAuthProvider.EMAIL_PASSWORD_SIGN_IN_METHOD)) {
    return AuthLinkStrategy.password;
  }
  if (methods.contains(GoogleAuthProvider.GOOGLE_SIGN_IN_METHOD)) {
    return AuthLinkStrategy.google;
  }
  return AuthLinkStrategy.unsupported;
}

bool isGoogleSignInSupported({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  return isWeb || platform == TargetPlatform.iOS;
}

typedef LinkPasswordPrompt =
    Future<String?> Function(String email, String providerLabel);

class SocialSignInResult {
  const SocialSignInResult({
    required this.userCredential,
    required this.loginMethod,
    required this.isNewUser,
    this.didLinkProvider = false,
  });

  final UserCredential userCredential;
  final String loginMethod;
  final bool isNewUser;
  final bool didLinkProvider;
}

class AuthServiceException implements Exception {
  const AuthServiceException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => "AuthServiceException($code): $message";
}

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: const ["email"]);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  bool get _googleSupported =>
      isGoogleSignInSupported(isWeb: kIsWeb, platform: defaultTargetPlatform);

  Future<SocialSignInResult> signInWithGoogle({
    LinkPasswordPrompt? requestPasswordForLinking,
  }) async {
    if (!_googleSupported) {
      throw const AuthServiceException(
        code: "unsupported-platform",
        message: "Google sign-in is currently available on iOS and Web only.",
      );
    }

    if (kIsWeb) {
      final provider = GoogleAuthProvider()..addScope("email");
      return _signInWithProviderWeb(
        provider: provider,
        loginMethod: "google",
        requestPasswordForLinking: requestPasswordForLinking,
      );
    }

    final credential = await _buildGoogleCredential();
    return _signInWithCredential(
      credential: credential,
      loginMethod: "google",
      requestPasswordForLinking: requestPasswordForLinking,
    );
  }

  Future<void> upsertUserProfileFromAuthUser(User user) async {
    final userRef = _firestore.collection("users").doc(user.uid);
    final userSnap = await userRef.get();
    final fallbackDisplayName = _fallbackDisplayName(user);

    if (!userSnap.exists) {
      await userRef.set({
        "displayName": fallbackDisplayName,
        "email": user.email ?? "",
        "createdAt": FieldValue.serverTimestamp(),
        "ratingAvg": 0,
        "ratingCount": 0,
      });
      return;
    }

    final data = userSnap.data() ?? <String, dynamic>{};
    final updates = <String, dynamic>{};
    final existingDisplayName = (data["displayName"] as String?)?.trim() ?? "";
    final existingEmail = (data["email"] as String?)?.trim() ?? "";

    if (existingDisplayName.isEmpty) {
      updates["displayName"] = fallbackDisplayName;
    }
    if (existingEmail.isEmpty && (user.email ?? "").isNotEmpty) {
      updates["email"] = user.email;
    }

    if (updates.isNotEmpty) {
      await userRef.set(updates, SetOptions(merge: true));
    }
  }

  Future<SocialSignInResult> _signInWithProviderWeb({
    required AuthProvider provider,
    required String loginMethod,
    LinkPasswordPrompt? requestPasswordForLinking,
  }) async {
    try {
      final credential = await _auth.signInWithPopup(provider);
      final user = credential.user;
      if (user == null) {
        throw const AuthServiceException(
          code: "user-missing",
          message: "Authentication succeeded but no user was returned.",
        );
      }
      await upsertUserProfileFromAuthUser(user);
      return SocialSignInResult(
        userCredential: credential,
        loginMethod: loginMethod,
        isNewUser: credential.additionalUserInfo?.isNewUser ?? false,
      );
    } on FirebaseAuthException catch (error) {
      if (error.code == "account-exists-with-different-credential") {
        final linkedCredential =
            await _resolveAccountExistsWithDifferentCredential(
              loginMethod: loginMethod,
              email: error.email,
              pendingCredential: error.credential,
              requestPasswordForLinking: requestPasswordForLinking,
            );
        return linkedCredential;
      }
      throw _toAuthServiceException(error);
    }
  }

  Future<SocialSignInResult> _signInWithCredential({
    required AuthCredential credential,
    required String loginMethod,
    LinkPasswordPrompt? requestPasswordForLinking,
  }) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        throw const AuthServiceException(
          code: "user-missing",
          message: "Authentication succeeded but no user was returned.",
        );
      }
      await upsertUserProfileFromAuthUser(user);
      return SocialSignInResult(
        userCredential: userCredential,
        loginMethod: loginMethod,
        isNewUser: userCredential.additionalUserInfo?.isNewUser ?? false,
      );
    } on FirebaseAuthException catch (error) {
      if (error.code == "account-exists-with-different-credential") {
        return _resolveAccountExistsWithDifferentCredential(
          loginMethod: loginMethod,
          email: error.email,
          pendingCredential: error.credential ?? credential,
          requestPasswordForLinking: requestPasswordForLinking,
        );
      }
      throw _toAuthServiceException(error);
    }
  }

  Future<SocialSignInResult> _resolveAccountExistsWithDifferentCredential({
    required String loginMethod,
    required String? email,
    required AuthCredential? pendingCredential,
    LinkPasswordPrompt? requestPasswordForLinking,
  }) async {
    if (email == null || email.trim().isEmpty) {
      throw const AuthServiceException(
        code: "missing-email-for-linking",
        message:
            "This account is already registered with another provider. Try signing in with your existing method first.",
      );
    }
    if (pendingCredential == null) {
      throw const AuthServiceException(
        code: "missing-pending-credential",
        message:
            "Could not link this provider automatically. Sign in with your existing method and try again.",
      );
    }

    final resolvedCredential = await _resolveExistingSignInMethod(
      email: email,
      attemptedLoginMethod: loginMethod,
      requestPasswordForLinking: requestPasswordForLinking,
    );

    await _safeLinkCredential(resolvedCredential.user, pendingCredential);

    final user = resolvedCredential.user;
    if (user == null) {
      throw const AuthServiceException(
        code: "user-missing",
        message: "Authentication succeeded but no user was returned.",
      );
    }

    await upsertUserProfileFromAuthUser(user);
    return SocialSignInResult(
      userCredential: resolvedCredential,
      loginMethod: loginMethod,
      isNewUser: resolvedCredential.additionalUserInfo?.isNewUser ?? false,
      didLinkProvider: true,
    );
  }

  Future<UserCredential> _resolveExistingSignInMethod({
    required String email,
    required String attemptedLoginMethod,
    LinkPasswordPrompt? requestPasswordForLinking,
  }) async {
    AuthServiceException? lastKnownError;

    if (requestPasswordForLinking != null) {
      try {
        final password = await requestPasswordForLinking(
          email,
          "email/password",
        );
        if (password != null && password.isNotEmpty) {
          return await _auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        }
      } on FirebaseAuthException catch (error) {
        lastKnownError = _toAuthServiceException(error);
      }
    }

    if (_googleSupported && attemptedLoginMethod != "google") {
      try {
        if (kIsWeb) {
          return await _auth.signInWithPopup(
            GoogleAuthProvider()..addScope("email"),
          );
        }
        final credential = await _buildGoogleCredential();
        return await _auth.signInWithCredential(credential);
      } on AuthServiceException catch (error) {
        lastKnownError = error;
      } on FirebaseAuthException catch (error) {
        lastKnownError = _toAuthServiceException(error);
      }
    }

    throw lastKnownError ??
        const AuthServiceException(
          code: "linking-required",
          message:
              "This email is already registered with a different sign-in method. Sign in with your existing method first, then try again.",
        );
  }

  Future<void> _safeLinkCredential(
    User? user,
    AuthCredential pendingCredential,
  ) async {
    if (user == null) {
      return;
    }
    try {
      await user.linkWithCredential(pendingCredential);
    } on FirebaseAuthException catch (error) {
      final ignorable = {
        "provider-already-linked",
        "credential-already-in-use",
      };
      if (!ignorable.contains(error.code)) {
        throw _toAuthServiceException(error);
      }
    }
  }

  Future<AuthCredential> _buildGoogleCredential() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw const AuthServiceException(
          code: "google-cancelled",
          message: "Google sign-in was cancelled.",
        );
      }

      final authentication = await account.authentication;
      if ((authentication.idToken ?? "").isEmpty &&
          (authentication.accessToken ?? "").isEmpty) {
        throw const AuthServiceException(
          code: "google-missing-token",
          message:
              "Google sign-in is not configured correctly. Check iOS GoogleService-Info.plist OAuth client settings.",
        );
      }

      return GoogleAuthProvider.credential(
        idToken: authentication.idToken,
        accessToken: authentication.accessToken,
      );
    } on AuthServiceException {
      rethrow;
    } catch (_) {
      throw const AuthServiceException(
        code: "google-unexpected-error",
        message: "Could not complete Google sign-in.",
      );
    }
  }

  AuthServiceException _toAuthServiceException(FirebaseAuthException error) {
    switch (error.code) {
      case "popup-closed-by-user":
      case "cancelled-popup-request":
      case "web-context-cancelled":
        return const AuthServiceException(
          code: "cancelled",
          message: "Authentication was cancelled.",
        );
      case "network-request-failed":
        return const AuthServiceException(
          code: "network-request-failed",
          message: "Network error. Check your connection and try again.",
        );
      case "user-disabled":
        return const AuthServiceException(
          code: "user-disabled",
          message: "This account is disabled.",
        );
      case "operation-not-allowed":
        return const AuthServiceException(
          code: "operation-not-allowed",
          message: "This sign-in provider is not enabled in Firebase Auth.",
        );
      case "invalid-credential":
        return const AuthServiceException(
          code: "invalid-credential",
          message: "Invalid credential. Try signing in again.",
        );
      default:
        return AuthServiceException(
          code: error.code,
          message: error.message ?? "Authentication failed.",
        );
    }
  }

  String _fallbackDisplayName(User user) {
    final displayName = user.displayName?.trim() ?? "";
    if (displayName.isNotEmpty) {
      return displayName;
    }
    final email = user.email?.trim() ?? "";
    if (email.isNotEmpty && email.contains("@")) {
      return email.split("@").first;
    }
    return "User";
  }
}
