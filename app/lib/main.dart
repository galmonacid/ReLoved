import "package:firebase_analytics/firebase_analytics.dart";
import "package:firebase_app_check/firebase_app_check.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "firebase_options.dart";
import "src/auth/auth_gate.dart";
import "src/config/app_config.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await _configureFirebase();
  runApp(const ReLovedApp());
}

Future<void> _configureFirebase() async {
  if (!kIsWeb) {
    FlutterError.onError =
        FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance
          .recordError(error, stack, fatal: true);
      return true;
    };
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);
  }

  try {
    if (kIsWeb) {
      if (!AppConfig.hasAppCheckWebKey) {
        return;
      }
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider(AppConfig.appCheckWebKey),
      );
      return;
    }
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode
          ? AppleProvider.debug
          : AppleProvider.appAttestWithDeviceCheckFallback,
    );
  } catch (_) {
    if (!kDebugMode) {
      rethrow;
    }
  }
}

class ReLovedApp extends StatelessWidget {
  const ReLovedApp({super.key});

  @override
  Widget build(BuildContext context) {
    const sageGreen = Color(0xFF9CAF88);
    final analytics = FirebaseAnalytics.instance;
    return MaterialApp(
      title: 'ReLoved',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: sageGreen,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          surfaceTintColor: Colors.white,
          elevation: 0,
        ),
      ),
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: analytics),
      ],
      home: const AuthGate(),
    );
  }
}
