import "package:cloud_firestore/cloud_firestore.dart";

class Conversation {
  Conversation({
    required this.id,
    required this.itemId,
    required this.itemTitle,
    required this.itemPhotoUrl,
    required this.itemApproxArea,
    required this.ownerId,
    required this.interestedUserId,
    required this.participants,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMessageAt,
    required this.lastMessageSenderId,
    required this.lastMessagePreview,
    required this.ownerUnreadCount,
    required this.interestedUnreadCount,
    required this.closedBy,
    required this.closedAt,
    required this.reopenedAt,
    required this.blockedByUserId,
    required this.blockedAt,
  });

  final String id;
  final String itemId;
  final String itemTitle;
  final String itemPhotoUrl;
  final String itemApproxArea;
  final String ownerId;
  final String interestedUserId;
  final List<String> participants;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final String? lastMessagePreview;
  final int ownerUnreadCount;
  final int interestedUnreadCount;
  final String? closedBy;
  final DateTime? closedAt;
  final DateTime? reopenedAt;
  final String? blockedByUserId;
  final DateTime? blockedAt;

  bool isParticipant(String uid) => participants.contains(uid);

  bool get isOpen => status == "open";

  bool get isReadOnly => status != "open";

  bool isOwner(String uid) => ownerId == uid;

  String otherParticipantId(String uid) =>
      uid == ownerId ? interestedUserId : ownerId;

  int unreadForUser(String uid) {
    if (uid == ownerId) {
      return ownerUnreadCount;
    }
    if (uid == interestedUserId) {
      return interestedUnreadCount;
    }
    return 0;
  }

  factory Conversation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    DateTime? toDate(dynamic value) =>
        value is Timestamp ? value.toDate() : null;

    final rawParticipants = data["participants"];
    final participants = rawParticipants is List
        ? rawParticipants.whereType<String>().toList(growable: false)
        : const <String>[];

    return Conversation(
      id: doc.id,
      itemId: (data["itemId"] as String?) ?? "",
      itemTitle: (data["itemTitle"] as String?) ?? "",
      itemPhotoUrl: (data["itemPhotoUrl"] as String?) ?? "",
      itemApproxArea: (data["itemApproxArea"] as String?) ?? "",
      ownerId: (data["ownerId"] as String?) ?? "",
      interestedUserId: (data["interestedUserId"] as String?) ?? "",
      participants: participants,
      status: (data["status"] as String?) ?? "open",
      createdAt: toDate(data["createdAt"]),
      updatedAt: toDate(data["updatedAt"]),
      lastMessageAt: toDate(data["lastMessageAt"]),
      lastMessageSenderId: data["lastMessageSenderId"] as String?,
      lastMessagePreview: data["lastMessagePreview"] as String?,
      ownerUnreadCount: (data["ownerUnreadCount"] as num?)?.toInt() ?? 0,
      interestedUnreadCount:
          (data["interestedUnreadCount"] as num?)?.toInt() ?? 0,
      closedBy: data["closedBy"] as String?,
      closedAt: toDate(data["closedAt"]),
      reopenedAt: toDate(data["reopenedAt"]),
      blockedByUserId: data["blockedByUserId"] as String?,
      blockedAt: toDate(data["blockedAt"]),
    );
  }
}
