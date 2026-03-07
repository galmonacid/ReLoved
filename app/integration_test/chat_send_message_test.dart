// ignore_for_file: avoid_print

import "dart:ui";

import "package:app/src/home/chat_thread_screen.dart";
import "package:app/src/testing/test_keys.dart";
import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:integration_test/integration_test.dart";

import "support/e2e_control_client.dart";
import "support/firebase_test_bootstrap.dart";
import "support/test_app_harness.dart";
import "support/test_robot.dart";

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final originalFlutterError = FlutterError.onError;
  final originalPlatformError = PlatformDispatcher.instance.onError;

  FlutterError.onError = (details) {
    final reportData = binding.reportData ??= <String, dynamic>{};
    reportData["chat_send_flutter_error"] = details.exceptionAsString();
    reportData["chat_send_flutter_error_stack"] = details.stack.toString();
    originalFlutterError?.call(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    final reportData = binding.reportData ??= <String, dynamic>{};
    reportData["chat_send_platform_error"] = error.toString();
    reportData["chat_send_platform_error_stack"] = stack.toString();
    return originalPlatformError?.call(error, stack) ?? false;
  };

  testWidgets("chat send message persists and renders in thread", (
    tester,
  ) async {
    binding.reportData = <String, dynamic>{"chat_send_step": "reset_fixture"};
    TestRobot? robot;

    try {
      const control = E2EControlClient();
      print("E2E chat_send reset fixture");
      await control.reset();
      final fixture = await control.seedChatBase();

      binding.reportData!["chat_send_step"] = "init_app";
      print("E2E chat_send init app");
      await ensureFirebaseTestInitialized();
      robot = TestRobot(tester);

      binding.reportData!["chat_send_step"] = "sign_in_programmatic";
      print("E2E chat_send sign in");
      await robot.signInProgrammatically(
        email: fixture.interested.email,
        password: fixture.interested.password,
        waitForSignedInShell: false,
      );
      binding.reportData!["chat_send_step"] = "mount_chat_thread_start";
      print("E2E chat_send mount chat thread");
      await pumpTestApp(
        tester,
        ChatThreadScreen(conversationId: fixture.conversation.id),
      );
      binding.reportData!["chat_send_step"] = "mount_chat_thread_done";
      binding.reportData!["chat_send_current_user"] =
          FirebaseAuth.instance.currentUser?.uid ?? "null";
      final pendingException = tester.takeException();
      if (pendingException != null) {
        throw TestFailure(
          "Pending framework exception after sign-in: $pendingException",
        );
      }

      binding.reportData!["chat_send_step"] = "wait_chat_thread";
      print("E2E chat_send wait chat thread");
      await robot.waitFor(
        find.byKey(const ValueKey(TestKeys.chatMessageField)).hitTestable(),
      );

      final message =
          "E2E send ${DateTime.now().millisecondsSinceEpoch} ${fixture.item.id}";
      binding.reportData!["chat_send_step"] = "send_message";
      binding.reportData!["chat_send_message"] = message;
      print("E2E chat_send send message");
      await robot.enterTextByKey(TestKeys.chatMessageField, message);
      final composerBeforeSend = robot.readTextByKey(TestKeys.chatMessageField);
      if (composerBeforeSend != message) {
        throw TestFailure(
          "Composer text mismatch before send. "
          "Expected '$message' but found '${composerBeforeSend ?? "null"}'.",
        );
      }
      await robot.pressByKey(TestKeys.chatSendButton);
      await tester.pump(const Duration(milliseconds: 500));
      binding.reportData!["chat_send_step"] = "wait_send_complete";
      final sendDeadline = DateTime.now().add(const Duration(seconds: 20));
      var previewMatched = false;
      while (DateTime.now().isBefore(sendDeadline)) {
        await tester.pump(const Duration(milliseconds: 250));
        final pendingException = tester.takeException();
        if (pendingException != null) {
          throw TestFailure(
            "Pending framework exception while waiting for send completion: "
            "$pendingException",
          );
        }
        final composerText =
            robot.readTextByKey(TestKeys.chatMessageField) ?? "";
        final conversationSnap = await FirebaseFirestore.instance
            .collection("conversations")
            .doc(fixture.conversation.id)
            .get();
        final preview =
            conversationSnap.data()?["lastMessagePreview"] as String?;
        if (composerText.isEmpty && preview == message) {
          previewMatched = true;
          break;
        }
      }
      if (!previewMatched) {
        final composerText =
            robot.readTextByKey(TestKeys.chatMessageField) ?? "";
        final conversationSnap = await FirebaseFirestore.instance
            .collection("conversations")
            .doc(fixture.conversation.id)
            .get();
        throw TestFailure(
          "Message send did not complete in time. "
          "Composer='$composerText'. "
          "Preview='${conversationSnap.data()?["lastMessagePreview"] ?? "null"}'.",
        );
      }
      await robot.waitFor(find.text(message));

      binding.reportData!["chat_send_step"] = "verify_firestore";
      print("E2E chat_send verify firestore");
      final conversationSnap = await FirebaseFirestore.instance
          .collection("conversations")
          .doc(fixture.conversation.id)
          .get();
      expect(conversationSnap.get("lastMessagePreview"), message);

      final messagesSnap = await FirebaseFirestore.instance
          .collection("conversations")
          .doc(fixture.conversation.id)
          .collection("messages")
          .get();
      final texts = messagesSnap.docs
          .map((doc) => doc.data()["text"] as String? ?? "")
          .toList(growable: false);
      expect(texts, contains(message));
      binding.reportData!["chat_send_step"] = "done";
      print("E2E chat_send done");
    } catch (error, stack) {
      print("E2E chat_send failed: $error");
      binding.reportData!["chat_send_error"] = error.toString();
      binding.reportData!["chat_send_stack"] = stack.toString();
      binding.reportData!["chat_send_current_user"] =
          FirebaseAuth.instance.currentUser?.uid ?? "null";
      if (robot != null) {
        binding.reportData!["chat_send_visible_texts"] = robot.visibleTexts();
        binding.reportData!["chat_send_visible_keys"] = robot.visibleKeys();
      }
      rethrow;
    }
  });
}
