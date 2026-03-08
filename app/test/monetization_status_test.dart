import "package:app/src/models/monetization.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("parses extended monetization payload with runtime features", () {
    final status = MonetizationStatus.fromMap({
      "supportTier": "free",
      "supportStatus": "inactive",
      "activeItems": 4,
      "weeklyUniqueContacts": 11,
      "publishLimit": 3,
      "contactLimit": 10,
      "canPublish": false,
      "canContact": false,
      "publishOverBy": 2,
      "contactOverBy": 2,
      "features": {
        "monetizationEnabled": true,
        "supportUiEnabled": true,
        "checkoutEnabled": false,
        "enforcePublishLimit": true,
        "enforceContactLimit": true,
      },
      "effectiveLimits": {
        "publishLimit": 3,
        "contactLimit": 10,
        "timeZone": "Europe/London",
        "weekStartIsoDay": 1,
      },
    });

    expect(status.features.monetizationEnabled, isTrue);
    expect(status.features.checkoutEnabled, isFalse);
    expect(status.supportUiEnabled, isTrue);
    expect(status.effectiveLimits.timeZone, "Europe/London");
    expect(status.effectiveLimits.weekStartIsoDay, 1);
  });

  test(
    "falls back to legacy-compatible defaults when new fields are absent",
    () {
      final status = MonetizationStatus.fromMap({
        "supportTier": "free",
        "supportStatus": "inactive",
        "activeItems": 2,
        "weeklyUniqueContacts": 5,
        "publishLimit": 3,
        "contactLimit": 10,
      });

      expect(status.features.monetizationEnabled, isTrue);
      expect(status.features.supportUiEnabled, isTrue);
      expect(status.features.checkoutEnabled, isTrue);
      expect(status.features.enforcePublishLimit, isTrue);
      expect(status.features.enforceContactLimit, isTrue);
      expect(status.canPublish, isTrue);
      expect(status.canContact, isTrue);
      expect(status.effectiveLimits.publishLimit, 3);
      expect(status.effectiveLimits.contactLimit, 10);
    },
  );

  test(
    "enforcement disabled forces canPublish/canContact fallback to true",
    () {
      final status = MonetizationStatus.fromMap({
        "supportTier": "free",
        "supportStatus": "inactive",
        "activeItems": 50,
        "weeklyUniqueContacts": 70,
        "publishLimit": 3,
        "contactLimit": 10,
        "features": {
          "monetizationEnabled": true,
          "supportUiEnabled": true,
          "checkoutEnabled": true,
          "enforcePublishLimit": false,
          "enforceContactLimit": false,
        },
      });

      expect(status.canPublish, isTrue);
      expect(status.canContact, isTrue);
      expect(status.publishOverBy, 0);
      expect(status.contactOverBy, 0);
    },
  );
}
