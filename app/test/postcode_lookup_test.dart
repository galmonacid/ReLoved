import "package:app/src/utils/postcode_lookup.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:latlong2/latlong.dart";

void main() {
  test("lookupUkPostcode returns null on timeout", () async {
    final client = MockClient((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return http.Response("{}", 200);
    });

    final result = await lookupUkPostcode(
      "MK8 1AH",
      client: client,
      timeout: const Duration(milliseconds: 10),
    );

    expect(result, isNull);
  });

  test("reverseUkPostcode returns null on timeout", () async {
    final client = MockClient((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return http.Response("{}", 200);
    });

    final result = await reverseUkPostcode(
      const LatLng(52.0406, -0.7594),
      client: client,
      timeout: const Duration(milliseconds: 10),
    );

    expect(result, isNull);
  });
}
