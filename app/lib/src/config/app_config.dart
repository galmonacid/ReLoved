class AppConfig {
  static const String _privacyPolicyUrl =
      String.fromEnvironment("PRIVACY_POLICY_URL");
  static const String _termsUrl = String.fromEnvironment("TERMS_URL");
  static const String supportEmail = String.fromEnvironment("SUPPORT_EMAIL");
  static const String appCheckWebKey =
      String.fromEnvironment("APP_CHECK_WEB_KEY");
  static const String _shareBaseUrl =
      String.fromEnvironment("SHARE_BASE_URL");
  static const String iosTeamId = String.fromEnvironment("IOS_TEAM_ID");
  static const String iosAppStoreId =
      String.fromEnvironment("IOS_APP_STORE_ID");
  static const String androidPackageName =
      String.fromEnvironment("ANDROID_PACKAGE_NAME");

  static const String _defaultPrivacyPolicyUrl =
      "https://reloved-greenhilledge.web.app/privacy.html";
  static const String _defaultTermsUrl =
      "https://reloved-greenhilledge.web.app/terms.html";
  static const String _defaultShareBaseUrl =
      "https://reloved-greenhilledge.web.app";

  static String get privacyPolicyUrl =>
      _privacyPolicyUrl.isNotEmpty ? _privacyPolicyUrl : _defaultPrivacyPolicyUrl;
  static String get termsUrl =>
      _termsUrl.isNotEmpty ? _termsUrl : _defaultTermsUrl;
  static String get shareBaseUrl =>
      _shareBaseUrl.isNotEmpty ? _shareBaseUrl : _defaultShareBaseUrl;

  static bool get hasPrivacyPolicy => privacyPolicyUrl.isNotEmpty;
  static bool get hasTerms => termsUrl.isNotEmpty;
  static bool get hasSupportEmail => supportEmail.isNotEmpty;
  static bool get hasAppCheckWebKey => appCheckWebKey.isNotEmpty;
  static bool get hasShareBaseUrl => shareBaseUrl.isNotEmpty;
}
