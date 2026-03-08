import "package:app/firebase_options.dart";
import "package:cloud_firestore/cloud_firestore.dart";
import "package:cloud_functions/cloud_functions.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_storage/firebase_storage.dart";
import "package:flutter/foundation.dart";
import "package:flutter/widgets.dart";

const bool _useFirebaseEmulators = bool.fromEnvironment(
  "USE_FIREBASE_EMULATORS",
);

const String _e2eProjectId = String.fromEnvironment(
  "E2E_PROJECT_ID",
  defaultValue: "demo-reloved-e2e",
);

const String _authHost = String.fromEnvironment(
  "AUTH_EMULATOR_HOST",
  defaultValue: "127.0.0.1",
);
const int _authPort = int.fromEnvironment(
  "AUTH_EMULATOR_PORT",
  defaultValue: 9099,
);

const String _firestoreHost = String.fromEnvironment(
  "FIRESTORE_EMULATOR_HOST",
  defaultValue: "127.0.0.1",
);
const int _firestorePort = int.fromEnvironment(
  "FIRESTORE_EMULATOR_PORT",
  defaultValue: 8080,
);

const String _functionsHost = String.fromEnvironment(
  "FUNCTIONS_EMULATOR_HOST",
  defaultValue: "127.0.0.1",
);
const int _functionsPort = int.fromEnvironment(
  "FUNCTIONS_EMULATOR_PORT",
  defaultValue: 5001,
);
const String _chatFunctionsRegion = String.fromEnvironment(
  "CHAT_FUNCTIONS_REGION",
  defaultValue: "europe-west2",
);

const String _storageHost = String.fromEnvironment(
  "STORAGE_EMULATOR_HOST",
  defaultValue: "127.0.0.1",
);
const int _storagePort = int.fromEnvironment(
  "STORAGE_EMULATOR_PORT",
  defaultValue: 9199,
);

bool _initialized = false;

FirebaseOptions _firebaseOptions() {
  if (!_useFirebaseEmulators || !kIsWeb) {
    return DefaultFirebaseOptions.currentPlatform;
  }
  return FirebaseOptions(
    apiKey: "demo-api-key",
    appId: "1:1234567890:web:relovede2e",
    messagingSenderId: "1234567890",
    projectId: _e2eProjectId,
    authDomain: "$_e2eProjectId.firebaseapp.com",
    storageBucket: "$_e2eProjectId.appspot.com",
  );
}

Future<void> ensureFirebaseTestInitialized() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_initialized) {
    return;
  }

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: _firebaseOptions());
  }

  if (_useFirebaseEmulators) {
    await FirebaseAuth.instance.useAuthEmulator(_authHost, _authPort);
    FirebaseFirestore.instance.useFirestoreEmulator(
      _firestoreHost,
      _firestorePort,
    );
    final functionRegions = <String>{"us-central1", _chatFunctionsRegion};
    for (final region in functionRegions) {
      FirebaseFunctions.instanceFor(
        region: region,
      ).useFunctionsEmulator(_functionsHost, _functionsPort);
    }
    FirebaseStorage.instance.useStorageEmulator(_storageHost, _storagePort);
  }

  _initialized = true;
}
