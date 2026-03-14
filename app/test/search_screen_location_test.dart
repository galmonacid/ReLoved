import "dart:async";

import "package:app/src/home/search_screen.dart";
import "package:app/src/models/item.dart";
import "package:app/src/testing/test_keys.dart";
import "package:app/src/utils/location.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:latlong2/latlong.dart";

void main() {
  testWidgets("shows finding location while bootstrap is in flight", (
    tester,
  ) async {
    final completer = Completer<LocationBootstrapResult>();

    await tester.pumpWidget(
      MaterialApp(
        home: SearchScreen(
          locationBootstrapLoader: () => completer.future,
          searchItemsLoader: _emptySearchItems,
          enableBootstrapAnalytics: false,
        ),
      ),
    );

    expect(find.text("Finding location..."), findsOneWidget);
    expect(
      find.byKey(const ValueKey(TestKeys.searchLocationChip)),
      findsOneWidget,
    );
  });

  testWidgets("resolved location updates label and runs initial search", (
    tester,
  ) async {
    LatLng? fetchedCenter;

    await tester.pumpWidget(
      MaterialApp(
        home: SearchScreen(
          locationBootstrapLoader: () async =>
              const LocationBootstrapResult.resolved(LatLng(51.5, -0.12)),
          reversePostcodeLookup: (_) async => "SE1 2AA",
          searchItemsLoader:
              ({
                required LatLng center,
                required double radiusKm,
                required int resultCap,
              }) async {
                fetchedCenter = center;
                return const <Item>[];
              },
          enableBootstrapAnalytics: false,
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text("SE1 2AA"), findsOneWidget);
    expect(fetchedCenter, const LatLng(51.5, -0.12));
  });

  testWidgets(
    "reverse postcode failure keeps real coordinates and fallback label",
    (tester) async {
      LatLng? fetchedCenter;

      await tester.pumpWidget(
        MaterialApp(
          home: SearchScreen(
            locationBootstrapLoader: () async =>
                const LocationBootstrapResult.resolved(LatLng(55.95, -3.19)),
            reversePostcodeLookup: (_) async => null,
            searchItemsLoader:
                ({
                  required LatLng center,
                  required double radiusKm,
                  required int resultCap,
                }) async {
                  fetchedCenter = center;
                  return const <Item>[];
                },
            enableBootstrapAnalytics: false,
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text("Current area"), findsOneWidget);
      expect(fetchedCenter, const LatLng(55.95, -3.19));
    },
  );

  testWidgets(
    "reverse postcode delay does not block initial search results",
    (tester) async {
      LatLng? fetchedCenter;
      final postcodeCompleter = Completer<String?>();

      await tester.pumpWidget(
        MaterialApp(
          home: SearchScreen(
            locationBootstrapLoader: () async =>
                const LocationBootstrapResult.resolved(LatLng(51.5, -0.12)),
            reversePostcodeLookup: (_) => postcodeCompleter.future,
            searchItemsLoader:
                ({
                  required LatLng center,
                  required double radiusKm,
                  required int resultCap,
                }) async {
                  fetchedCenter = center;
                  return const <Item>[];
                },
            enableBootstrapAnalytics: false,
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text("Current area"), findsOneWidget);
      expect(find.text("Finding location..."), findsNothing);
      expect(fetchedCenter, const LatLng(51.5, -0.12));
    },
  );

  testWidgets(
    "failure path shows retry or settings affordance and skips default search",
    (tester) async {
      var searchCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: SearchScreen(
            locationBootstrapLoader: () async =>
                const LocationBootstrapResult.unavailable(
                  LocationBootstrapFailureReason.permissionDeniedForever,
                ),
            searchItemsLoader:
                ({
                  required LatLng center,
                  required double radiusKm,
                  required int resultCap,
                }) async {
                  searchCalls += 1;
                  return const <Item>[];
                },
            enableBootstrapAnalytics: false,
          ),
        ),
      );

      await tester.pump();

      expect(find.text("Enable location"), findsWidgets);
      expect(
        find.byKey(const ValueKey(TestKeys.searchLocationAction)),
        findsOneWidget,
      );
      expect(searchCalls, 0);
    },
  );

  testWidgets("search timeout stops the spinner and shows an error", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SearchScreen(
          locationBootstrapLoader: () async =>
              const LocationBootstrapResult.resolved(LatLng(51.5, -0.12)),
          reversePostcodeLookup: (_) async => null,
          searchItemsLoader:
              ({
                required LatLng center,
                required double radiusKm,
                required int resultCap,
              }) => Completer<List<Item>>().future,
          enableBootstrapAnalytics: false,
          searchLoadTimeout: const Duration(milliseconds: 10),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text("Could not load items."), findsOneWidget);
  });
}

Future<List<Item>> _emptySearchItems({
  required LatLng center,
  required double radiusKm,
  required int resultCap,
}) async {
  return const <Item>[];
}
