import "dart:convert";

import "package:app/src/config/e2e_config.dart";
import "package:http/http.dart" as http;

class E2EUser {
  const E2EUser({
    required this.uid,
    required this.email,
    required this.password,
    required this.displayName,
  });

  final String uid;
  final String email;
  final String password;
  final String displayName;

  factory E2EUser.fromMap(Map<String, dynamic> map) {
    return E2EUser(
      uid: map["uid"] as String,
      email: map["email"] as String,
      password: map["password"] as String,
      displayName: map["displayName"] as String,
    );
  }
}

class E2EItem {
  const E2EItem({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.contactPreference,
    required this.approxAreaText,
  });

  final String id;
  final String title;
  final String description;
  final String status;
  final String contactPreference;
  final String approxAreaText;

  factory E2EItem.fromMap(Map<String, dynamic> map) {
    return E2EItem(
      id: map["id"] as String,
      title: map["title"] as String,
      description: map["description"] as String,
      status: map["status"] as String,
      contactPreference: map["contactPreference"] as String,
      approxAreaText: map["approxAreaText"] as String,
    );
  }
}

class E2EConversation {
  const E2EConversation({required this.id, required this.initialMessageText});

  final String id;
  final String initialMessageText;

  factory E2EConversation.fromMap(Map<String, dynamic> map) {
    return E2EConversation(
      id: map["id"] as String,
      initialMessageText: map["initialMessageText"] as String,
    );
  }
}

class ChatFixture {
  const ChatFixture({
    required this.owner,
    required this.interested,
    required this.item,
    required this.conversation,
  });

  final E2EUser owner;
  final E2EUser interested;
  final E2EItem item;
  final E2EConversation conversation;

  factory ChatFixture.fromMap(Map<String, dynamic> map) {
    return ChatFixture(
      owner: E2EUser.fromMap(Map<String, dynamic>.from(map["owner"] as Map)),
      interested: E2EUser.fromMap(
        Map<String, dynamic>.from(map["interested"] as Map),
      ),
      item: E2EItem.fromMap(Map<String, dynamic>.from(map["item"] as Map)),
      conversation: E2EConversation.fromMap(
        Map<String, dynamic>.from(map["conversation"] as Map),
      ),
    );
  }
}

class SearchFixture {
  const SearchFixture({
    required this.owner,
    required this.interested,
    required this.item,
    required this.searchTerm,
  });

  final E2EUser owner;
  final E2EUser interested;
  final E2EItem item;
  final String searchTerm;

  factory SearchFixture.fromMap(Map<String, dynamic> map) {
    return SearchFixture(
      owner: E2EUser.fromMap(Map<String, dynamic>.from(map["owner"] as Map)),
      interested: E2EUser.fromMap(
        Map<String, dynamic>.from(map["interested"] as Map),
      ),
      item: E2EItem.fromMap(Map<String, dynamic>.from(map["item"] as Map)),
      searchTerm: map["searchTerm"] as String,
    );
  }
}

class E2EControlClient {
  const E2EControlClient();

  Uri _uri(String path) {
    final base = E2EConfig.controlBaseUrl.trim();
    if (base.isEmpty) {
      throw StateError("E2E_CONTROL_BASE_URL is not configured.");
    }
    return Uri.parse("$base$path");
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    Map<String, dynamic> body = const {},
  }) async {
    final response = await http.post(
      _uri(path),
      headers: const {"content-type": "application/json"},
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        "E2E control request failed (${response.statusCode}): ${response.body}",
      );
    }

    return Map<String, dynamic>.from(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> reset() async {
    await _post("/reset");
  }

  Future<ChatFixture> seedChatBase() async {
    final payload = await _post("/seed/chat_base");
    return ChatFixture.fromMap(
      Map<String, dynamic>.from(payload["fixture"] as Map),
    );
  }

  Future<SearchFixture> seedSearchBase() async {
    final payload = await _post("/seed/search_base");
    return SearchFixture.fromMap(
      Map<String, dynamic>.from(payload["fixture"] as Map),
    );
  }

  Future<void> sendChatMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    await _post(
      "/chat/send",
      body: {
        "conversationId": conversationId,
        "senderId": senderId,
        "text": text,
      },
    );
  }
}
