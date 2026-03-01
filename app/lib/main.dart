import "package:firebase_analytics/firebase_analytics.dart";
import "package:firebase_app_check/firebase_app_check.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "firebase_options.dart";
import "src/auth/auth_gate.dart";
import "src/config/app_config.dart";
import "src/home/item_detail_screen.dart";
import "theme/app_theme.dart";

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
        providerWeb: ReCaptchaV3Provider(AppConfig.appCheckWebKey),
      );
      return;
    }
    await FirebaseAppCheck.instance.activate(
      providerAndroid:
          kDebugMode
              ? const AndroidDebugProvider()
              : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  } catch (_) {
    if (!kDebugMode) {
      rethrow;
    }
  }
}

class ReLovedApp extends StatelessWidget {
  const ReLovedApp({super.key});

  static String? _itemIdFromRouteName(String? routeName) {
    if (routeName == null || routeName.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(routeName);
    if (uri == null) {
      return null;
    }
    return _itemIdFromUri(uri);
  }

  static String? _itemIdFromUri(Uri uri) {
    if (uri.pathSegments.length < 2) {
      return null;
    }
    if (uri.pathSegments.first != "items") {
      return null;
    }
    final itemId = uri.pathSegments[1].trim();
    return itemId.isEmpty ? null : itemId;
  }

  static Route<void> _homeRoute([RouteSettings? settings]) {
    return MaterialPageRoute<void>(
      builder: (_) => const AuthGate(),
      settings: settings,
    );
  }

  static Route<void> _itemRoute(String itemId, [RouteSettings? settings]) {
    return MaterialPageRoute<void>(
      builder: (_) => ItemDetailScreen(itemId: itemId),
      settings: settings,
    );
  }

  @override
  Widget build(BuildContext context) {
    final analyticsEnabled = !(kIsWeb && kDebugMode);
    final sharedItemId = _itemIdFromUri(Uri.base);
    return MaterialApp(
      title: 'ReLoved',
      theme: AppTheme.light,
      onGenerateInitialRoutes: (initialRoute) {
        final routes = <Route<void>>[_homeRoute()];
        final itemId = _itemIdFromRouteName(initialRoute) ?? sharedItemId;
        if (itemId != null) {
          routes.add(_itemRoute(itemId));
        }
        return routes;
      },
      onGenerateRoute: (settings) {
        final itemId = _itemIdFromRouteName(settings.name);
        if (itemId != null) {
          return _itemRoute(itemId, settings);
        }
        return _homeRoute(settings);
      },
      navigatorObservers:
          analyticsEnabled
              ? [FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)]
              : const [],
    );
  }
}
