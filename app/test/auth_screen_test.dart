import "package:app/src/auth/auth_screen.dart";
import "package:app/src/testing/test_keys.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  testWidgets("renders Apple and Google social buttons with provider icons", (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthScreen(showAppleOverride: true, showGoogleOverride: true),
      ),
    );

    expect(
      find.byKey(const ValueKey(TestKeys.authAppleButton)),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey(TestKeys.authGoogleButton)),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.apple), findsOneWidget);
    expect(find.byKey(const ValueKey(TestKeys.authGoogleIcon)), findsOneWidget);
    expect(find.text("Continue with Apple"), findsOneWidget);
    expect(find.text("Continue with Google"), findsOneWidget);
  });

  testWidgets("hides Apple button when Apple is not in scope for the screen", (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthScreen(showAppleOverride: false, showGoogleOverride: true),
      ),
    );

    expect(find.byKey(const ValueKey(TestKeys.authAppleButton)), findsNothing);
    expect(
      find.byKey(const ValueKey(TestKeys.authGoogleButton)),
      findsOneWidget,
    );
  });
}
