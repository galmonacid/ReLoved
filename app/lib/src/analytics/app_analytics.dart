import "package:firebase_analytics/firebase_analytics.dart";
import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:flutter/foundation.dart";

import "../config/e2e_config.dart";

class AppAnalytics {
  const AppAnalytics._();

  static bool get _enabled =>
      !E2EConfig.disableAnalytics && !(kIsWeb && kDebugMode);

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

  static Future<void> logLocationBootstrapStep({
    required String screen,
    required String phase,
    required String status,
    int? elapsedMs,
    String? reason,
  }) async {
    if (!_enabled) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: "location_bootstrap_step",
        parameters: {
          "screen": screen,
          "phase": phase,
          "status": status,
          if (elapsedMs != null) "elapsed_ms": elapsedMs,
          if (reason != null) "reason": reason,
        },
      );
    } catch (_) {}
  }

  static Future<void> recordNonFatal({
    required String reason,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) async {
    if (kIsWeb || E2EConfig.disableFirebaseSideEffects) {
      return;
    }
    try {
      final information = <Object>[
        for (final entry in context?.entries ?? const Iterable.empty())
          "${entry.key}=${entry.value}",
      ];
      await FirebaseCrashlytics.instance.recordError(
        error ?? StateError(reason),
        stackTrace ?? StackTrace.current,
        reason: reason,
        information: information,
        fatal: false,
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
