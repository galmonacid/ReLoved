// ignore_for_file: avoid_print

import "package:app/src/home/item_detail_screen.dart";
import "package:app/src/testing/test_keys.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:integration_test/integration_test.dart";

import "support/e2e_control_client.dart";
import "support/firebase_test_bootstrap.dart";
import "support/test_app_harness.dart";
import "support/test_robot.dart";

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("open chat tap-to-ready stays under budget", (tester) async {
    const budgetMs = int.fromEnvironment(
      "E2E_CHAT_OPEN_BUDGET_MS",
      defaultValue: 2500,
    );
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

    await pumpTestApp(tester, ItemDetailScreen(itemId: fixture.item.id));
    await robot.waitFor(
      find.byKey(const ValueKey(TestKeys.itemOpenChatButton)).hitTestable(),
    );

    final stopwatch = Stopwatch()..start();
    await robot.pressByKey(TestKeys.itemOpenChatButton);
    await robot.waitFor(
      find.byKey(const ValueKey(TestKeys.chatMessageField)).hitTestable(),
      timeout: const Duration(seconds: 20),
    );
    stopwatch.stop();

    final elapsedMs = stopwatch.elapsedMilliseconds;
    print("CHAT_OPEN_PERF_E2E elapsed_ms=$elapsedMs budget_ms=$budgetMs");
    final reportData = binding.reportData ??= <String, dynamic>{};
    reportData["chat_open_perf_elapsed_ms"] = elapsedMs;
    reportData["chat_open_perf_budget_ms"] = budgetMs;
    reportData["chat_open_perf_item_id"] = fixture.item.id;

    expect(
      elapsedMs,
      lessThanOrEqualTo(budgetMs),
      reason:
          "Open chat exceeded budget: ${elapsedMs}ms > ${budgetMs}ms. "
          "Check logs for CHAT_OPEN_PERF phase breakdown.",
    );
  });
}
