import "package:app/src/models/item.dart";
import "package:app/src/utils/share_utils.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("buildShareUrl creates an item deep link", () {
    final url = buildShareUrl("item-123");

    expect(
      url.toString(),
      "https://reloved-greenhilledge.web.app/items/item-123",
    );
  });

  test("buildShareUrl encodes item ids as one path segment", () {
    final url = buildShareUrl("item 123/with slash");

    expect(
      url.toString(),
      "https://reloved-greenhilledge.web.app/items/item%20123%2Fwith%20slash",
    );
  });

  test("buildShareText uses the same message for every share entrypoint", () {
    final item = Item(
      id: "item-123",
      ownerId: "owner",
      title: "Kids scooter",
      description: "Good condition",
      photoUrl: "",
      photoPath: "",
      createdAt: DateTime(2026),
      status: "available",
      contactPreference: ContactPreference.both,
      location: ItemLocation(
        lat: 51.5,
        lng: -0.12,
        geohash: "gcpvj",
        approxAreaText: "SW1A",
      ),
    );

    expect(
      buildShareText(item),
      "Check out this item on ReLoved: Kids scooter\n"
      "https://reloved-greenhilledge.web.app/items/item-123",
    );
  });
}
