import "package:firebase_analytics/firebase_analytics.dart";
import "package:flutter/foundation.dart";

class AppAnalytics {
  const AppAnalytics._();

  static bool get _enabled => !(kIsWeb && kDebugMode);

  static Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    if (!_enabled) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (_) {}
  }

  static Future<void> logLogin({String? loginMethod}) async {
    if (!_enabled) return;
    try {
      await FirebaseAnalytics.instance.logLogin(loginMethod: loginMethod);
    } catch (_) {}
  }

  static Future<void> logSignUp({required String signUpMethod}) async {
    if (!_enabled) return;
    try {
      await FirebaseAnalytics.instance.logSignUp(signUpMethod: signUpMethod);
    } catch (_) {}
  }
}
