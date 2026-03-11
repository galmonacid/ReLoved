import "package:flutter_test/flutter_test.dart";
import "package:latlong2/latlong.dart";
import "package:app/src/utils/geo.dart";

void main() {
  test("geohash precision scales with radius", () {
    expect(geohashPrecisionForRadiusKm(1), 6);
    expect(geohashPrecisionForRadiusKm(4.8), 5);
    expect(geohashPrecisionForRadiusKm(16), 4);
  });

  test("search prefixes include the center geohash prefix", () {
    const center = LatLng(51.5074, -0.1278);
    final prefixes = geohashPrefixesForRadius(center, 5);
    final centerPrefix = encodeGeohash(
      center.latitude,
      center.longitude,
      precision: geohashPrecisionForRadiusKm(5),
    );

    expect(prefixes, isNotEmpty);
    expect(prefixes, contains(centerPrefix));
  });
}
