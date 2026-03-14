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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("auth plus search opens item detail and shows chat CTA", (
    tester,
  ) async {
    const control = E2EControlClient();
    await control.reset();
    final fixture = await control.seedSearchBase();

    await ensureFirebaseTestInitialized();
    final robot = TestRobot(tester);

    await robot.signInProgrammatically(
      email: fixture.interested.email,
      password: fixture.interested.password,
      waitForSignedInShell: false,
    );
    await pumpTestApp(tester, const SearchScreen());
    await robot.waitFor(find.text("Find around"));
    final searchField = find.byType(EditableText).first;
    await robot.waitFor(searchField);
    await tester.enterText(searchField, fixture.searchTerm);
    await tester.pump(const Duration(milliseconds: 500));

    await robot.pressByKey(TestKeys.searchItemCard(fixture.item.id));

    await robot.waitFor(find.text("Open chat").hitTestable());
  });
}
