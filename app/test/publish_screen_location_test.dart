import "dart:async";

import "package:app/src/home/publish_screen.dart";
import "package:app/src/testing/test_keys.dart";
import "package:app/src/utils/location.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:latlong2/latlong.dart";

void main() {
  testWidgets("does not mark location as selected while bootstrap is loading", (
    tester,
  ) async {
    final completer = Completer<LocationBootstrapResult>();

    await tester.pumpWidget(
      MaterialApp(
        home: PublishScreen(
          locationBootstrapLoader: () => completer.future,
          enableBootstrapAnalytics: false,
        ),
      ),
    );

    expect(find.text("Finding location..."), findsOneWidget);
    expect(find.text("Change location"), findsNothing);
    expect(
      find.byKey(const ValueKey(TestKeys.publishLocationStatus)),
      findsOneWidget,
    );
  });

  testWidgets("success path fills postcode and enables change location", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PublishScreen(
          locationBootstrapLoader: () async =>
              const LocationBootstrapResult.resolved(LatLng(53.48, -2.24)),
          reversePostcodeLookup: (_) async => "M1 1AE",
          enableBootstrapAnalytics: false,
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text("Change location"), findsOneWidget);
    expect(find.text("M1 1AE"), findsOneWidget);
  });

  testWidgets(
    "resolved location keeps publish usable while postcode lookup is pending",
    (tester) async {
      final postcodeCompleter = Completer<String?>();

      await tester.pumpWidget(
        MaterialApp(
          home: PublishScreen(
            locationBootstrapLoader: () async =>
                const LocationBootstrapResult.resolved(LatLng(53.48, -2.24)),
            reversePostcodeLookup: (_) => postcodeCompleter.future,
            enableBootstrapAnalytics: false,
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text("Change location"), findsOneWidget);
      expect(find.text("Finding location..."), findsNothing);
      expect(
        find.text("Using your device location while postcode loads."),
        findsOneWidget,
      );
    },
  );

  testWidgets("failure path leaves postcode empty and shows explicit copy", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PublishScreen(
          locationBootstrapLoader: () async =>
              const LocationBootstrapResult.unavailable(
                LocationBootstrapFailureReason.permissionDenied,
              ),
          enableBootstrapAnalytics: false,
        ),
      ),
    );

    await tester.pump();

    expect(find.text("Select location"), findsOneWidget);
    expect(find.text("Enable location"), findsNothing);
    expect(find.text("Use current location"), findsOneWidget);
    expect(
      find.byKey(const ValueKey(TestKeys.publishLocationAction)),
      findsOneWidget,
    );
  });
}
