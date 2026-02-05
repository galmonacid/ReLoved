class AppConfig {
  static const String privacyPolicyUrl =
      String.fromEnvironment("PRIVACY_POLICY_URL");
  static const String termsUrl = String.fromEnvironment("TERMS_URL");
  static const String supportEmail = String.fromEnvironment("SUPPORT_EMAIL");
  static const String appCheckWebKey =
      String.fromEnvironment("APP_CHECK_WEB_KEY");

  static bool get hasPrivacyPolicy => privacyPolicyUrl.isNotEmpty;
  static bool get hasTerms => termsUrl.isNotEmpty;
  static bool get hasSupportEmail => supportEmail.isNotEmpty;
  static bool get hasAppCheckWebKey => appCheckWebKey.isNotEmpty;
}
