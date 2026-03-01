import "package:cloud_firestore/cloud_firestore.dart";

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.isRedacted,
    required this.redactedAt,
    required this.redactionReason,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime? createdAt;
  final bool isRedacted;
  final DateTime? redactedAt;
  final String? redactionReason;

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdAt = data["createdAt"];
    final redactedAt = data["redactedAt"];

    return ChatMessage(
      id: doc.id,
      senderId: (data["senderId"] as String?) ?? "",
      text: (data["text"] as String?) ?? "",
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      isRedacted: data["isRedacted"] as bool? ?? false,
      redactedAt: redactedAt is Timestamp ? redactedAt.toDate() : null,
      redactionReason: data["redactionReason"] as String?,
    );
  }
}
