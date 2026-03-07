import "package:app/src/home/chat_thread_screen.dart";
import "package:flutter/material.dart";
import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter_test/flutter_test.dart";
import "package:integration_test/integration_test.dart";

import "support/e2e_control_client.dart";
import "support/firebase_test_bootstrap.dart";
import "support/test_app_harness.dart";
import "support/test_robot.dart";

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("chat receive message updates thread without reload", (
    tester,
  ) async {
    const control = E2EControlClient();
    await control.reset();
    final fixture = await control.seedChatBase();

    await ensureFirebaseTestInitialized();
    final robot = TestRobot(tester);

    await robot.signInProgrammatically(
      email: fixture.interested.email,
      password: fixture.interested.password,
      waitForSignedInShell: false,
    );
    await pumpTestApp(
      tester,
      ChatThreadScreen(conversationId: fixture.conversation.id),
    );
    await robot.waitFor(find.byType(TextField));

    final incomingText = "Owner reply ${DateTime.now().millisecondsSinceEpoch}";
    await control.sendChatMessage(
      conversationId: fixture.conversation.id,
      senderId: fixture.owner.uid,
      text: incomingText,
    );

    await robot.waitFor(find.text(incomingText));

    final conversationSnap = await FirebaseFirestore.instance
        .collection("conversations")
        .doc(fixture.conversation.id)
        .get();
    expect(conversationSnap.get("lastMessagePreview"), incomingText);
    expect(conversationSnap.get("lastMessageSenderId"), fixture.owner.uid);
  });
}
