// ignore_for_file: depend_on_referenced_packages

import "dart:async";
import "dart:io";

import "package:flutter_driver/flutter_driver.dart";
import "package:integration_test/integration_test_driver_extended.dart";

Future<FlutterDriver> _connectWithRetry() async {
  final DateTime deadline = DateTime.now().add(const Duration(minutes: 2));
  Object? lastError;
  StackTrace? lastStackTrace;
  int attempt = 0;

  while (DateTime.now().isBefore(deadline)) {
    attempt += 1;
    try {
      stderr.writeln("Connecting FlutterDriver (attempt $attempt)...");
      return await FlutterDriver.connect(
        timeout: const Duration(seconds: 20),
        printCommunication: true,
      );
    } catch (error, stackTrace) {
      lastError = error;
      lastStackTrace = stackTrace;
      stderr.writeln("FlutterDriver.connect failed: $error");
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  if (lastError != null && lastStackTrace != null) {
    Error.throwWithStackTrace(lastError, lastStackTrace);
  }
  throw StateError("FlutterDriver.connect failed without an error.");
}

Future<void> main() async {
  final FlutterDriver driver = await _connectWithRetry();
  await integrationDriver(driver: driver, writeResponseOnFailure: true);
}
