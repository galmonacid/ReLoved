enum SupportPlanType { oneOffDonation, monthlySubscription }

String supportPlanTypeToWire(SupportPlanType type) {
  switch (type) {
    case SupportPlanType.oneOffDonation:
      return "one_off";
    case SupportPlanType.monthlySubscription:
      return "monthly";
  }
}

enum PaywallContext { publish, contact, aboutSupport }

String paywallContextToWire(PaywallContext context) {
  switch (context) {
    case PaywallContext.publish:
      return "publish";
    case PaywallContext.contact:
      return "contact";
    case PaywallContext.aboutSupport:
      return "about_support";
  }
}

enum SupportTier { free, supporterMonthly }

SupportTier supportTierFromWire(String? value) {
  switch (value) {
    case "supporter_monthly":
      return SupportTier.supporterMonthly;
    default:
      return SupportTier.free;
  }
}

enum SupportStatus { inactive, active, pastDue, canceled }

SupportStatus supportStatusFromWire(String? value) {
  switch (value) {
    case "active":
      return SupportStatus.active;
    case "past_due":
      return SupportStatus.pastDue;
    case "canceled":
      return SupportStatus.canceled;
    default:
      return SupportStatus.inactive;
  }
}

class MonetizationFeatures {
  const MonetizationFeatures({
    required this.monetizationEnabled,
    required this.supportUiEnabled,
    required this.checkoutEnabled,
    required this.enforcePublishLimit,
    required this.enforceContactLimit,
  });

  const MonetizationFeatures.legacyEnabled()
    : monetizationEnabled = true,
      supportUiEnabled = true,
      checkoutEnabled = true,
      enforcePublishLimit = true,
      enforceContactLimit = true;

  final bool monetizationEnabled;
  final bool supportUiEnabled;
  final bool checkoutEnabled;
  final bool enforcePublishLimit;
  final bool enforceContactLimit;

  factory MonetizationFeatures.fromMap(
    Map<String, dynamic>? data, {
    MonetizationFeatures fallback = const MonetizationFeatures.legacyEnabled(),
  }) {
    bool asBool(Object? value, {required bool fallbackValue}) {
      if (value is bool) {
        return value;
      }
      return fallbackValue;
    }

    final source = data ?? const <String, dynamic>{};
    return MonetizationFeatures(
      monetizationEnabled: asBool(
        source["monetizationEnabled"],
        fallbackValue: fallback.monetizationEnabled,
      ),
      supportUiEnabled: asBool(
        source["supportUiEnabled"],
        fallbackValue: fallback.supportUiEnabled,
      ),
      checkoutEnabled: asBool(
        source["checkoutEnabled"],
        fallbackValue: fallback.checkoutEnabled,
      ),
      enforcePublishLimit: asBool(
        source["enforcePublishLimit"],
        fallbackValue: fallback.enforcePublishLimit,
      ),
      enforceContactLimit: asBool(
        source["enforceContactLimit"],
        fallbackValue: fallback.enforceContactLimit,
      ),
    );
  }

  Map<String, Object> analyticsParams({required String source}) {
    int asInt(bool value) => value ? 1 : 0;
    return {
      "source": source,
      "monetization_enabled": asInt(monetizationEnabled),
      "support_ui_enabled": asInt(supportUiEnabled),
      "checkout_enabled": asInt(checkoutEnabled),
      "enforce_publish_limit": asInt(enforcePublishLimit),
      "enforce_contact_limit": asInt(enforceContactLimit),
    };
  }
}

class MonetizationEffectiveLimits {
  const MonetizationEffectiveLimits({
    required this.publishLimit,
    required this.contactLimit,
    required this.timeZone,
    required this.weekStartIsoDay,
  });

  final int publishLimit;
  final int contactLimit;
  final String timeZone;
  final int weekStartIsoDay;

  factory MonetizationEffectiveLimits.fromMap(
    Map<String, dynamic>? data, {
    required int fallbackPublishLimit,
    required int fallbackContactLimit,
    String fallbackTimeZone = "Europe/London",
    int fallbackWeekStartIsoDay = 1,
  }) {
    int asInt(Object? value, {required int fallbackValue}) {
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      return fallbackValue;
    }

    final source = data ?? const <String, dynamic>{};
    return MonetizationEffectiveLimits(
      publishLimit: asInt(
        source["publishLimit"],
        fallbackValue: fallbackPublishLimit,
      ),
      contactLimit: asInt(
        source["contactLimit"],
        fallbackValue: fallbackContactLimit,
      ),
      timeZone: (source["timeZone"] as String?)?.trim().isNotEmpty == true
          ? (source["timeZone"] as String).trim()
          : fallbackTimeZone,
      weekStartIsoDay: asInt(
        source["weekStartIsoDay"],
        fallbackValue: fallbackWeekStartIsoDay,
      ),
    );
  }
}

class MonetizationStatus {
  const MonetizationStatus({
    required this.supportTier,
    required this.supportStatus,
    required this.activeItems,
    required this.weeklyUniqueContacts,
    required this.publishLimit,
    required this.contactLimit,
    required this.canPublish,
    required this.canContact,
    required this.publishOverBy,
    required this.contactOverBy,
    required this.supportPeriodEndEpochMs,
    required this.features,
    required this.effectiveLimits,
  });

  final SupportTier supportTier;
  final SupportStatus supportStatus;
  final int activeItems;
  final int weeklyUniqueContacts;
  final int publishLimit;
  final int contactLimit;
  final bool canPublish;
  final bool canContact;
  final int publishOverBy;
  final int contactOverBy;
  final int? supportPeriodEndEpochMs;
  final MonetizationFeatures features;
  final MonetizationEffectiveLimits effectiveLimits;

  bool get isMonthlySupporter => supportTier == SupportTier.supporterMonthly;
  bool get supportUiEnabled => features.supportUiEnabled;
  bool get checkoutEnabled => features.checkoutEnabled;

  factory MonetizationStatus.fromMap(Map<String, dynamic> data) {
    int asInt(Object? value, {int fallback = 0}) {
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      return fallback;
    }

    bool asBool(Object? value, {required bool fallback}) {
      if (value is bool) {
        return value;
      }
      return fallback;
    }

    final publishLimit = asInt(data["publishLimit"], fallback: 3);
    final contactLimit = asInt(data["contactLimit"], fallback: 10);
    final activeItems = asInt(data["activeItems"]);
    final weeklyUniqueContacts = asInt(data["weeklyUniqueContacts"]);
    final features = MonetizationFeatures.fromMap(
      data["features"] is Map
          ? Map<String, dynamic>.from(data["features"] as Map)
          : null,
    );
    final effectiveLimits = MonetizationEffectiveLimits.fromMap(
      data["effectiveLimits"] is Map
          ? Map<String, dynamic>.from(data["effectiveLimits"] as Map)
          : null,
      fallbackPublishLimit: publishLimit,
      fallbackContactLimit: contactLimit,
    );

    return MonetizationStatus(
      supportTier: supportTierFromWire(data["supportTier"] as String?),
      supportStatus: supportStatusFromWire(data["supportStatus"] as String?),
      activeItems: activeItems,
      weeklyUniqueContacts: weeklyUniqueContacts,
      publishLimit: publishLimit,
      contactLimit: contactLimit,
      canPublish: asBool(
        data["canPublish"],
        fallback:
            !features.enforcePublishLimit ||
            activeItems < effectiveLimits.publishLimit,
      ),
      canContact: asBool(
        data["canContact"],
        fallback:
            !features.enforceContactLimit ||
            weeklyUniqueContacts < effectiveLimits.contactLimit,
      ),
      publishOverBy: asInt(
        data["publishOverBy"],
        fallback:
            features.enforcePublishLimit &&
                activeItems >= effectiveLimits.publishLimit
            ? activeItems - effectiveLimits.publishLimit + 1
            : 0,
      ),
      contactOverBy: asInt(
        data["contactOverBy"],
        fallback:
            features.enforceContactLimit &&
                weeklyUniqueContacts >= effectiveLimits.contactLimit
            ? weeklyUniqueContacts - effectiveLimits.contactLimit + 1
            : 0,
      ),
      supportPeriodEndEpochMs: data["supportPeriodEndEpochMs"] is int
          ? data["supportPeriodEndEpochMs"] as int
          : null,
      features: features,
      effectiveLimits: effectiveLimits,
    );
  }
}
