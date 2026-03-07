// ignore_for_file: avoid_print

import "package:app/src/home/inbox_screen.dart";
import "package:app/src/models/conversation.dart";
import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter_test/flutter_test.dart";
import "package:integration_test/integration_test.dart";

import "support/e2e_control_client.dart";
import "support/firebase_test_bootstrap.dart";
import "support/test_app_harness.dart";
import "support/test_robot.dart";

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("inbox shows seeded preview and unread badge", (tester) async {
    binding.reportData = <String, dynamic>{"chat_inbox_step": "reset_fixture"};
    TestRobot? robot;
    try {
      const control = E2EControlClient();
      print("E2E chat_inbox reset fixture");
      await control.reset();
      final fixture = await control.seedChatBase();

      binding.reportData!["chat_inbox_step"] = "init_app";
      print("E2E chat_inbox init app");
      await ensureFirebaseTestInitialized();
      robot = TestRobot(tester);

      binding.reportData!["chat_inbox_step"] = "sign_in";
      print("E2E chat_inbox sign in");
      await robot.signInProgrammatically(
        email: fixture.owner.email,
        password: fixture.owner.password,
        waitForSignedInShell: false,
      );

      binding.reportData!["chat_inbox_step"] = "verify_seeded_doc";
      final seededConversationSnap = await FirebaseFirestore.instance
          .collection("conversations")
          .doc(fixture.conversation.id)
          .get()
          .timeout(const Duration(seconds: 10));
      if (!seededConversationSnap.exists) {
        throw TestFailure(
          "Seeded conversation '${fixture.conversation.id}' does not exist for "
          "owner '${fixture.owner.uid}'.",
        );
      }

      binding.reportData!["chat_inbox_step"] = "verify_query";
      final conversationsQuerySnap = await FirebaseFirestore.instance
          .collection("conversations")
          .where("participants", arrayContains: fixture.owner.uid)
          .limit(100)
          .get()
          .timeout(const Duration(seconds: 10));
      final queryIds = conversationsQuerySnap.docs
          .map((doc) => doc.id)
          .toList(growable: false);
      binding.reportData!["chat_inbox_query_ids"] = queryIds;
      if (!queryIds.contains(fixture.conversation.id)) {
        throw TestFailure(
          "Owner inbox query did not return seeded conversation "
          "'${fixture.conversation.id}'. Query ids: $queryIds",
        );
      }

      binding.reportData!["chat_inbox_step"] = "verify_parser";
      try {
        conversationsQuerySnap.docs
            .map(Conversation.fromDoc)
            .toList(growable: false);
      } catch (error) {
        throw TestFailure(
          "Conversation parser failed for owner inbox query: $error",
        );
      }

      binding.reportData!["chat_inbox_step"] = "mount_inbox_screen";
      print("E2E chat_inbox mount inbox");
      await pumpTestApp(tester, const InboxScreen());
      binding.reportData!["chat_inbox_step"] = "wait_inbox_screen";
      await robot.waitFor(find.text("Inbox"));
      binding.reportData!["chat_inbox_step"] = "wait_preview";
      await robot.waitFor(find.text(fixture.conversation.initialMessageText));
      binding.reportData!["chat_inbox_step"] = "wait_unread_badge";
      await robot.waitFor(find.text("1"));
      binding.reportData!["chat_inbox_step"] = "done";
      print("E2E chat_inbox done");
    } catch (error, stack) {
      print("E2E chat_inbox failed: $error");
      binding.reportData!["chat_inbox_error"] = error.toString();
      binding.reportData!["chat_inbox_stack"] = stack.toString();
      if (robot != null) {
        binding.reportData!["chat_inbox_visible_texts"] = robot.visibleTexts();
        binding.reportData!["chat_inbox_visible_keys"] = robot.visibleKeys();
      }
      rethrow;
    }
  });
}
