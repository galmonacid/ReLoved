import "package:app/src/home/item_detail_screen.dart";
import "package:app/src/home/search_screen.dart";
import "package:app/src/testing/test_keys.dart";
import "package:flutter/widgets.dart";
import "package:flutter_test/flutter_test.dart";
import "package:integration_test/integration_test.dart";

import "support/e2e_control_client.dart";
import "support/firebase_test_bootstrap.dart";
import "support/test_app_harness.dart";
import "support/test_robot.dart";

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("auth plus search opens item detail and shows chat CTA", (
    tester,
  ) async {
    binding.reportData = <String, dynamic>{"auth_search_step": "reset_fixture"};
    const control = E2EControlClient();
    TestRobot? robot;
    try {
      await control.reset();
      final fixture = await control.seedSearchBase();

      binding.reportData!["auth_search_step"] = "bootstrap_app";
      await ensureFirebaseTestInitialized();
      robot = TestRobot(tester);

      binding.reportData!["auth_search_step"] = "sign_in";
      await robot.signInProgrammatically(
        email: fixture.interested.email,
        password: fixture.interested.password,
        waitForSignedInShell: false,
      );

      binding.reportData!["auth_search_step"] = "mount_search";
      await pumpTestApp(tester, const SearchScreen());
      await robot.waitFor(find.text("Find around"));
      final searchField = find.byType(EditableText).first;
      await robot.waitFor(searchField);

      binding.reportData!["auth_search_step"] = "enter_search";
      await tester.enterText(searchField, fixture.searchTerm);
      await tester.pump(const Duration(milliseconds: 500));

      binding.reportData!["auth_search_step"] = "wait_search_result";
      await robot.waitFor(
        find.byKey(ValueKey(TestKeys.searchItemCard(fixture.item.id))),
      );

      binding.reportData!["auth_search_step"] = "clear_search_app";
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));

      binding.reportData!["auth_search_step"] = "mount_item_detail";
      await pumpTestApp(tester, ItemDetailScreen(itemId: fixture.item.id));

      binding.reportData!["auth_search_step"] = "wait_open_chat";
      await robot.waitFor(
        find.byKey(const ValueKey(TestKeys.itemOpenChatButton)),
      );
      binding.reportData!["auth_search_step"] = "done";
    } catch (error, stack) {
      binding.reportData!["auth_search_error"] = error.toString();
      binding.reportData!["auth_search_stack"] = stack.toString();
      if (robot != null) {
        binding.reportData!["auth_search_visible_texts"] = robot.visibleTexts();
        binding.reportData!["auth_search_visible_keys"] = robot.visibleKeys();
      }
      rethrow;
    }
  });
}
