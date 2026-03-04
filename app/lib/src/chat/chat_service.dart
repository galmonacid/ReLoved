import "package:cloud_firestore/cloud_firestore.dart";
import "package:cloud_functions/cloud_functions.dart";
import "../models/chat_message.dart";
import "../models/conversation.dart";
import "../models/item.dart";

class ChatService {
  ChatService._();

  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: "us-central1",
  );

  static Stream<List<Conversation>> streamUserConversations(String uid) {
    return FirebaseFirestore.instance
        .collection("conversations")
        .where("participants", arrayContains: uid)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          final conversations = snapshot.docs
              .map(Conversation.fromDoc)
              .where((conversation) => conversation.isParticipant(uid))
              .toList(growable: true);

          int rankingTimestamp(Conversation conversation) {
            return conversation.lastMessageAt?.millisecondsSinceEpoch ??
                conversation.updatedAt?.millisecondsSinceEpoch ??
                conversation.createdAt?.millisecondsSinceEpoch ??
                0;
          }

          conversations.sort(
            (a, b) => rankingTimestamp(b).compareTo(rankingTimestamp(a)),
          );
          return conversations;
        });
  }

  static Stream<Conversation?> streamConversation(String conversationId) {
    return FirebaseFirestore.instance
        .collection("conversations")
        .doc(conversationId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
            return null;
          }
          return Conversation.fromDoc(snapshot);
        });
  }

  static Stream<List<ChatMessage>> streamMessages(String conversationId) {
    return FirebaseFirestore.instance
        .collection("conversations")
        .doc(conversationId)
        .collection("messages")
        .orderBy("createdAt")
        .limit(500)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(ChatMessage.fromDoc).toList(growable: false),
        );
  }

  static Future<String> upsertItemConversation(String itemId) async {
    final callable = _functions.httpsCallable("upsertItemConversation");
    final result = await callable.call(<String, dynamic>{"itemId": itemId});
    final data = result.data;
    if (data is! Map) {
      throw const FormatException("Unexpected upsertItemConversation response");
    }
    final conversationId = data["conversationId"];
    if (conversationId is! String || conversationId.isEmpty) {
      throw const FormatException("Missing conversationId in response");
    }
    return conversationId;
  }

  static Future<void> sendMessage({
    required String conversationId,
    required String text,
  }) async {
    final callable = _functions.httpsCallable("sendChatMessage");
    await callable.call(<String, dynamic>{
      "conversationId": conversationId,
      "text": text,
    });
  }

  static Future<void> markConversationRead(String conversationId) async {
    final callable = _functions.httpsCallable("markConversationRead");
    await callable.call(<String, dynamic>{"conversationId": conversationId});
  }

  static Future<void> closeConversationByDonor(String conversationId) async {
    final callable = _functions.httpsCallable("closeConversationByDonor");
    await callable.call(<String, dynamic>{"conversationId": conversationId});
  }

  static Future<void> reopenConversationByDonor(String conversationId) async {
    final callable = _functions.httpsCallable("reopenConversationByDonor");
    await callable.call(<String, dynamic>{"conversationId": conversationId});
  }

  static Future<void> blockConversationParticipant({
    required String conversationId,
    required String blockedUserId,
  }) async {
    final callable = _functions.httpsCallable("blockConversationParticipant");
    await callable.call(<String, dynamic>{
      "conversationId": conversationId,
      "blockedUserId": blockedUserId,
    });
  }

  static Future<void> reportConversation({
    required String conversationId,
    required String reason,
    String details = "",
  }) async {
    final callable = _functions.httpsCallable("reportConversation");
    await callable.call(<String, dynamic>{
      "conversationId": conversationId,
      "reason": reason,
      "details": details,
    });
  }

  static Future<void> setItemContactPreference({
    required String itemId,
    required ContactPreference contactPreference,
  }) async {
    final callable = _functions.httpsCallable("setItemContactPreference");
    await callable.call(<String, dynamic>{
      "itemId": itemId,
      "contactPreference": contactPreferenceToString(contactPreference),
    });
  }
}
