import "package:flutter_test/flutter_test.dart";
import "package:app/src/models/item.dart";

void main() {
  test("ItemLocation toMap/fromMap roundtrip", () {
    final location = ItemLocation(
      lat: 40.4168,
      lng: -3.7038,
      geohash: "ezjmgtc",
      approxAreaText: "Centro",
    );

    final map = location.toMap();
    final restored = ItemLocation.fromMap(map);

    expect(restored.lat, location.lat);
    expect(restored.lng, location.lng);
    expect(restored.geohash, location.geohash);
    expect(restored.approxAreaText, location.approxAreaText);
  });

  test("ItemLocation fromMap falls back to defaults", () {
    final restored = ItemLocation.fromMap({});

    expect(restored.lat, 0);
    expect(restored.lng, 0);
    expect(restored.geohash, "");
    expect(restored.approxAreaText, "");
  });
}
