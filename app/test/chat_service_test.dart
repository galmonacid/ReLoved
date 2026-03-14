import "package:app/src/chat/chat_service.dart";
import "package:app/src/models/conversation.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("ChatService unread inbox badge count", () {
    test("sums unread counts for the owner", () {
      final conversations = [
        _conversation(ownerUnreadCount: 2, interestedUnreadCount: 5),
        _conversation(id: "c2", ownerUnreadCount: 4, interestedUnreadCount: 1),
      ];

      final count = ChatService.unreadInboxBadgeCountForConversations(
        conversations,
        "owner-1",
      );

      expect(count, 6);
    });

    test("sums unread counts for the interested user", () {
      final conversations = [
        _conversation(ownerUnreadCount: 2, interestedUnreadCount: 5),
        _conversation(id: "c2", ownerUnreadCount: 4, interestedUnreadCount: 1),
      ];

      final count = ChatService.unreadInboxBadgeCountForConversations(
        conversations,
        "interested-1",
      );

      expect(count, 6);
    });
  });
}

Conversation _conversation({
  String id = "c1",
  int ownerUnreadCount = 0,
  int interestedUnreadCount = 0,
}) {
  return Conversation(
    id: id,
    itemId: "item-1",
    itemTitle: "Lamp",
    itemPhotoUrl: "",
    itemApproxArea: "SW1A",
    ownerId: "owner-1",
    interestedUserId: "interested-1",
    participants: const ["owner-1", "interested-1"],
    status: "open",
    createdAt: null,
    updatedAt: null,
    lastMessageAt: null,
    lastMessageSenderId: null,
    lastMessagePreview: null,
    ownerUnreadCount: ownerUnreadCount,
    interestedUnreadCount: interestedUnreadCount,
    closedBy: null,
    closedAt: null,
    reopenedAt: null,
    blockedByUserId: null,
    blockedAt: null,
  );
}
