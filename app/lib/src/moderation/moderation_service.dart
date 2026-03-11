import "package:cloud_functions/cloud_functions.dart";

enum ModerationReason { spam, inappropriate, unsafe, fraud, other }

String moderationReasonToWire(ModerationReason reason) {
  switch (reason) {
    case ModerationReason.spam:
      return "spam";
    case ModerationReason.inappropriate:
      return "inappropriate";
    case ModerationReason.unsafe:
      return "unsafe";
    case ModerationReason.fraud:
      return "fraud";
    case ModerationReason.other:
      return "other";
  }
}

String moderationReasonLabel(ModerationReason reason) {
  switch (reason) {
    case ModerationReason.spam:
      return "Spam";
    case ModerationReason.inappropriate:
      return "Inappropriate";
    case ModerationReason.unsafe:
      return "Unsafe";
    case ModerationReason.fraud:
      return "Fraud";
    case ModerationReason.other:
      return "Other";
  }
}

class ModerationService {
  ModerationService._();

  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: "europe-west2",
  );

  static Future<void> reportListing({
    required String itemId,
    required String reason,
    String details = "",
  }) async {
    final callable = _functions.httpsCallable("reportListing");
    await callable.call(<String, dynamic>{
      "itemId": itemId,
      "reason": reason,
      "details": details,
    });
  }

  static Future<void> reportUser({
    required String reportedUserId,
    required String reason,
    String details = "",
  }) async {
    final callable = _functions.httpsCallable("reportUser");
    await callable.call(<String, dynamic>{
      "reportedUserId": reportedUserId,
      "reason": reason,
      "details": details,
    });
  }
}
