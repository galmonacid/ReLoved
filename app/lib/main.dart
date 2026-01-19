import "package:firebase_core/firebase_core.dart";
import "package:flutter/material.dart";
import "firebase_options.dart";
import "src/auth/auth_gate.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ReLovedApp());
}

class ReLovedApp extends StatelessWidget {
  const ReLovedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReLoved',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
      ),
      home: const AuthGate(),
    );
  }
}
