import "package:cloud_firestore/cloud_firestore.dart";
import "package:cloud_functions/cloud_functions.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_storage/firebase_storage.dart";
import "package:flutter/foundation.dart";

import "../../firebase_options.dart";

class E2EConfig {
  const E2EConfig._();

  static const bool enabled = bool.fromEnvironment("USE_FIREBASE_EMULATORS");
  static const String projectId = String.fromEnvironment(
    "E2E_PROJECT_ID",
    defaultValue: "demo-reloved-e2e",
  );

  static const String authHost = String.fromEnvironment(
    "AUTH_EMULATOR_HOST",
    defaultValue: "127.0.0.1",
  );
  static const int authPort = int.fromEnvironment(
    "AUTH_EMULATOR_PORT",
    defaultValue: 9099,
  );

  static const String firestoreHost = String.fromEnvironment(
    "FIRESTORE_EMULATOR_HOST",
    defaultValue: "127.0.0.1",
  );
  static const int firestorePort = int.fromEnvironment(
    "FIRESTORE_EMULATOR_PORT",
    defaultValue: 8080,
  );

  static const String functionsHost = String.fromEnvironment(
    "FUNCTIONS_EMULATOR_HOST",
    defaultValue: "127.0.0.1",
  );
  static const int functionsPort = int.fromEnvironment(
    "FUNCTIONS_EMULATOR_PORT",
    defaultValue: 5001,
  );
  static const String chatFunctionsRegion = String.fromEnvironment(
    "CHAT_FUNCTIONS_REGION",
    defaultValue: "europe-west2",
  );

  static const String storageHost = String.fromEnvironment(
    "STORAGE_EMULATOR_HOST",
    defaultValue: "127.0.0.1",
  );
  static const int storagePort = int.fromEnvironment(
    "STORAGE_EMULATOR_PORT",
    defaultValue: 9199,
  );

  static const String controlBaseUrl = String.fromEnvironment(
    "E2E_CONTROL_BASE_URL",
  );
  static const String fixedPostcode = String.fromEnvironment(
    "E2E_FIXED_POSTCODE",
    defaultValue: "MK9 3QA",
  );
  static const bool disableAnalyticsByDefine = bool.fromEnvironment(
    "E2E_DISABLE_ANALYTICS",
  );
  static const bool disableFirebaseSideEffectsByDefine = bool.fromEnvironment(
    "E2E_DISABLE_FIREBASE_SIDE_EFFECTS",
  );

  static bool get hasControlServer => controlBaseUrl.trim().isNotEmpty;
  static bool get disableAnalytics => enabled || disableAnalyticsByDefine;
  static bool get disableFirebaseSideEffects =>
      enabled || disableFirebaseSideEffectsByDefine;

  static FirebaseOptions get firebaseOptions {
    if (!enabled || !kIsWeb) {
      return DefaultFirebaseOptions.currentPlatform;
    }

    return FirebaseOptions(
      apiKey: "demo-api-key",
      appId: "1:1234567890:web:relovede2e",
      messagingSenderId: "1234567890",
      projectId: projectId,
      authDomain: "$projectId.firebaseapp.com",
      storageBucket: "$projectId.appspot.com",
    );
  }

  static Future<void> configureFirebaseServices() async {
    if (!enabled) {
      return;
    }

    await FirebaseAuth.instance.useAuthEmulator(authHost, authPort);
    FirebaseFirestore.instance.useFirestoreEmulator(
      firestoreHost,
      firestorePort,
    );
    final functionRegions = <String>{"us-central1", chatFunctionsRegion};
    for (final region in functionRegions) {
      FirebaseFunctions.instanceFor(
        region: region,
      ).useFunctionsEmulator(functionsHost, functionsPort);
    }
    FirebaseStorage.instance.useStorageEmulator(storageHost, storagePort);
  }
}
