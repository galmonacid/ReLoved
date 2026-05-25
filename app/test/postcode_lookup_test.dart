import "package:app/src/utils/postcode_lookup.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:latlong2/latlong.dart";

void main() {
  test("ukPostcodeOutwardCode derives the public outward code", () {
    expect(ukPostcodeOutwardCode("SW1A 1AA"), "SW1A");
    expect(ukPostcodeOutwardCode("M1 1AE"), "M1");
    expect(ukPostcodeOutwardCode(" sw1a%201aa "), "SW1A");
    expect(ukPostcodeOutwardCode("not a postcode"), isNull);
  });

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
