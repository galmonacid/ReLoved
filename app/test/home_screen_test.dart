import "dart:async";

import "package:app/src/home/home_screen.dart";
import "package:app/src/testing/test_keys.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  testWidgets("signed-out shell does not show inbox unread badge", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          sessionOverride: const HomeScreenSessionOverride(isSignedIn: false),
          guestPagesOverride: const [Placeholder(), Placeholder()],
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey(TestKeys.navInboxUnreadBadge)),
      findsNothing,
    );
    expect(find.byKey(const ValueKey(TestKeys.guestSignInTab)), findsOneWidget);
  });

  testWidgets("signed-in shell hides the badge at zero and shows updates", (
    tester,
  ) async {
    final unreadController = StreamController<int>();
    addTearDown(unreadController.close);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          sessionOverride: const HomeScreenSessionOverride(
            isSignedIn: true,
            uid: "user-1",
          ),
          signedInPagesOverride: const [
            Placeholder(),
            Placeholder(),
            Placeholder(),
            Placeholder(),
          ],
          unreadBadgeCountStreamOverride: unreadController.stream,
        ),
      ),
    );

    unreadController.add(0);
    await tester.pump();
    expect(
      find.byKey(const ValueKey(TestKeys.navInboxUnreadBadge)),
      findsNothing,
    );

    unreadController.add(7);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(
      find.byKey(const ValueKey(TestKeys.navInboxUnreadBadge)),
      findsOneWidget,
    );
    expect(find.text("7"), findsOneWidget);

    unreadController.add(120);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text("99+"), findsOneWidget);
  });
}
