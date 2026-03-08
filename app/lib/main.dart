import "dart:async";

import "package:app_links/app_links.dart";
import "package:firebase_analytics/firebase_analytics.dart";
import "package:firebase_app_check/firebase_app_check.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "src/auth/auth_gate.dart";
import "src/analytics/app_analytics.dart";
import "src/config/app_config.dart";
import "src/config/e2e_config.dart";
import "src/home/item_detail_screen.dart";
import "theme/app_theme.dart";

bool _firebaseCoreInitialized = false;
bool _firebaseServicesConfigured = false;
bool _firebaseSideEffectsConfigured = false;

Future<void> main() async {
  await ensureAppInitialized();
  runApp(const ReLovedApp());
}

Future<void> ensureAppInitialized() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!_firebaseCoreInitialized) {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: E2EConfig.firebaseOptions);
    }
    _firebaseCoreInitialized = true;
  }
  if (!_firebaseServicesConfigured) {
    await E2EConfig.configureFirebaseServices();
    _firebaseServicesConfigured = true;
  }
  if (!_firebaseSideEffectsConfigured) {
    await _configureFirebase();
    _firebaseSideEffectsConfigured = true;
  }
}

Future<void> _configureFirebase() async {
  if (E2EConfig.disableFirebaseSideEffects) {
    return;
  }
  if (!kIsWeb) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );
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
      providerAndroid: kDebugMode
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

class ReLovedApp extends StatefulWidget {
  const ReLovedApp({super.key});

  @override
  State<ReLovedApp> createState() => _ReLovedAppState();
}

class _ReLovedAppState extends State<ReLovedApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _linkSubscription;
  String? _lastOpenedItemId;
  String? _lastSupportCheckoutResult;

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
    if (uri.host == "items" && uri.pathSegments.isNotEmpty) {
      final itemId = uri.pathSegments.first.trim();
      return itemId.isEmpty ? null : itemId;
    }
    if (uri.pathSegments.length < 2) {
      return null;
    }
    if (uri.pathSegments.first != "items") {
      return null;
    }
    final itemId = uri.pathSegments[1].trim();
    return itemId.isEmpty ? null : itemId;
  }

  static String? _itemIdFromSharedQuery(Uri uri) {
    final sharedItemId = uri.queryParameters["shared_item_id"]?.trim();
    if (sharedItemId == null || sharedItemId.isEmpty) {
      return null;
    }
    return sharedItemId;
  }

  static String? _supportCheckoutResultFromUri(Uri uri) {
    final queryValue = uri.queryParameters["support_checkout"]?.trim();
    if (queryValue == "success" || queryValue == "cancel") {
      return queryValue;
    }
    if (uri.scheme != "reloved" || uri.host != "support") {
      return null;
    }
    if (uri.pathSegments.isEmpty) {
      return null;
    }
    final action = uri.pathSegments.first.trim();
    if (action == "success" || action == "cancel") {
      return action;
    }
    return null;
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
  void initState() {
    super.initState();
    _initIosDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _initIosDeepLinks() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    final appLinks = AppLinks();
    appLinks.getInitialLink().then(_handleDeepLinkUri).catchError((_) {});
    _linkSubscription = appLinks.uriLinkStream.listen(
      _handleDeepLinkUri,
      onError: (_) {},
    );
  }

  void _handleSupportCheckoutResult(String result) {
    if (_lastSupportCheckoutResult == result) {
      return;
    }
    _lastSupportCheckoutResult = result;
    AppAnalytics.logEvent(
      name: result == "success"
          ? "support_checkout_success"
          : "support_checkout_cancel",
      parameters: const {},
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentContext = _navigatorKey.currentContext;
      if (currentContext == null) {
        return;
      }
      final messenger = ScaffoldMessenger.of(currentContext);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result == "success"
                ? "Thanks for supporting ReLoved."
                : "Checkout canceled.",
          ),
        ),
      );
    });
  }

  void _handleDeepLinkUri(Uri? uri) {
    if (uri == null) {
      return;
    }
    final supportCheckout = _supportCheckoutResultFromUri(uri);
    if (supportCheckout != null) {
      _handleSupportCheckoutResult(supportCheckout);
      return;
    }
    final itemId = _itemIdFromUri(uri);
    if (itemId == null || _lastOpenedItemId == itemId) {
      return;
    }
    _lastOpenedItemId = itemId;
    final nav = _navigatorKey.currentState;
    if (nav == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final deferredNav = _navigatorKey.currentState;
        if (deferredNav == null) {
          return;
        }
        deferredNav.push(_itemRoute(itemId));
      });
      return;
    }
    nav.push(_itemRoute(itemId));
  }

  @override
  Widget build(BuildContext context) {
    final analyticsEnabled =
        !E2EConfig.disableAnalytics && !(kIsWeb && kDebugMode);
    final sharedItemId =
        _itemIdFromUri(Uri.base) ?? _itemIdFromSharedQuery(Uri.base);
    final supportCheckoutResult = _supportCheckoutResultFromUri(Uri.base);
    if (supportCheckoutResult != null) {
      _handleSupportCheckoutResult(supportCheckoutResult);
    }
    return MaterialApp(
      navigatorKey: _navigatorKey,
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
      navigatorObservers: analyticsEnabled
          ? [FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)]
          : const [],
    );
  }
}
