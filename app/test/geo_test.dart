import "package:flutter_test/flutter_test.dart";
import "package:latlong2/latlong.dart";
import "package:app/src/utils/geo.dart";

const _geohashChars = "0123456789bcdefghjkmnpqrstuvwxyz";

void main() {
  test("distanceKm returns 0 for identical points", () {
    const point = LatLng(10.0, -20.0);
    expect(distanceKm(point, point), 0);
  });

  test("distanceKm between (0,0) and (0,1) is about 111 km", () {
    const a = LatLng(0.0, 0.0);
    const b = LatLng(0.0, 1.0);
    final km = distanceKm(a, b);
    expect(km, closeTo(111.32, 0.5));
  });

  test("encodeGeohash returns requested precision length", () {
    final hash = encodeGeohash(40.4168, -3.7038, precision: 7);
    expect(hash.length, 7);
  });

  test("encodeGeohash uses only base32 characters", () {
    final hash = encodeGeohash(40.4168, -3.7038, precision: 9);
    for (final ch in hash.split("")) {
      expect(_geohashChars.contains(ch), isTrue);
    }
  });

  test("encodeGeohash changes when location changes", () {
    final hashA = encodeGeohash(40.4168, -3.7038, precision: 9);
    final hashB = encodeGeohash(41.3874, 2.1686, precision: 9);
    expect(hashA, isNot(hashB));
  });
}
