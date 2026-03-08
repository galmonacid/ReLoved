import "package:cloud_firestore/cloud_firestore.dart";
import "package:cloud_functions/cloud_functions.dart";
import "../models/chat_message.dart";
import "../models/conversation.dart";
import "../models/item.dart";

class ChatService {
  ChatService._();

  static const String _chatFunctionsRegion = String.fromEnvironment(
    "CHAT_FUNCTIONS_REGION",
    defaultValue: "europe-west2",
  );
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: _chatFunctionsRegion,
  );

  static const Duration _emptyDuration = Duration.zero;
  static const Duration _prefetchLookupWaitTimeout = Duration(
    milliseconds: 450,
  );

  static final Map<String, ConversationResolution>
  _conversationResolutionCache = <String, ConversationResolution>{};
  static final Map<String, Future<ConversationResolution>>
  _conversationResolutionInFlight = <String, Future<ConversationResolution>>{};
  static final Map<String, String> _prefetchedConversationIds =
      <String, String>{};
  static final Map<String, Future<String?>> _prefetchLookupInFlight =
      <String, Future<String?>>{};

  static int _durationMs(Duration duration) => duration.inMilliseconds;

  static String _conversationKey({
    required String itemId,
    required String interestedUserId,
  }) {
    return "$itemId::$interestedUserId";
  }

  static ConversationResolution _cachedResolution({
    required String conversationId,
    bool serverLookupAttempted = false,
    int serverLookupMs = 0,
  }) {
    return ConversationResolution(
      conversationId: conversationId,
      source: ConversationResolutionSource.cache,
      totalMs: 0,
      cacheLookupMs: 0,
      serverLookupMs: serverLookupMs,
      callableMs: 0,
      cacheLookupAttempted: false,
      serverLookupAttempted: serverLookupAttempted,
      callableAttempted: false,
    );
  }

  static Future<String?> _existingConversationId({
    required String itemId,
    required String interestedUserId,
    required Source source,
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collection("conversations")
        .where("itemId", isEqualTo: itemId)
        .where("interestedUserId", isEqualTo: interestedUserId)
        .limit(1)
        .get(GetOptions(source: source));
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return snapshot.docs.first.id;
  }

  static Future<ConversationResolution> resolveConversationForItem({
    required String itemId,
    required String interestedUserId,
  }) async {
    final key = _conversationKey(
      itemId: itemId,
      interestedUserId: interestedUserId,
    );
    final cachedResolution = _conversationResolutionCache[key];
    if (cachedResolution != null) {
      return cachedResolution;
    }

    final prefetchedConversationId = _prefetchedConversationIds[key];
    if (prefetchedConversationId != null) {
      final resolution = _cachedResolution(
        conversationId: prefetchedConversationId,
      );
      _conversationResolutionCache[key] = resolution;
      return resolution;
    }

    final inFlightResolution = _conversationResolutionInFlight[key];
    if (inFlightResolution != null) {
      return inFlightResolution;
    }

    final request = _resolveConversationForItemUncached(
      key: key,
      itemId: itemId,
      interestedUserId: interestedUserId,
    );
    _conversationResolutionInFlight[key] = request;
    try {
      final resolution = await request;
      _conversationResolutionCache[key] = resolution;
      _prefetchedConversationIds[key] = resolution.conversationId;
      return resolution;
    } finally {
      if (identical(_conversationResolutionInFlight[key], request)) {
        _conversationResolutionInFlight.remove(key);
      }
    }
  }

  static Future<ConversationResolution> _resolveConversationForItemUncached({
    required String key,
    required String itemId,
    required String interestedUserId,
  }) async {
    final totalWatch = Stopwatch()..start();
    var cacheLookupDuration = _emptyDuration;
    var serverLookupDuration = _emptyDuration;
    var callableDuration = _emptyDuration;
    var cacheLookupAttempted = false;
    var serverLookupAttempted = false;
    var callableAttempted = false;

    final inFlightServerLookup = _prefetchLookupInFlight[key];
    if (inFlightServerLookup != null) {
      serverLookupAttempted = true;
      final serverLookupWatch = Stopwatch()..start();
      try {
        final prefetchedConversationId = await inFlightServerLookup.timeout(
          _prefetchLookupWaitTimeout,
        );
        serverLookupDuration = serverLookupWatch.elapsed;
        if (prefetchedConversationId != null) {
          _prefetchedConversationIds[key] = prefetchedConversationId;
          return ConversationResolution(
            conversationId: prefetchedConversationId,
            source: ConversationResolutionSource.cache,
            totalMs: _durationMs(totalWatch.elapsed),
            cacheLookupMs: 0,
            serverLookupMs: _durationMs(serverLookupDuration),
            callableMs: 0,
            cacheLookupAttempted: false,
            serverLookupAttempted: serverLookupAttempted,
            callableAttempted: false,
          );
        }
      } catch (_) {
        serverLookupDuration = serverLookupWatch.elapsed;
      }
    }

    try {
      cacheLookupAttempted = true;
      final cacheWatch = Stopwatch()..start();
      final cachedConversationId = await _existingConversationId(
        itemId: itemId,
        interestedUserId: interestedUserId,
        source: Source.cache,
      );
      cacheLookupDuration = cacheWatch.elapsed;
      if (cachedConversationId != null) {
        return ConversationResolution(
          conversationId: cachedConversationId,
          source: ConversationResolutionSource.cache,
          totalMs: _durationMs(totalWatch.elapsed),
          cacheLookupMs: _durationMs(cacheLookupDuration),
          serverLookupMs: _durationMs(serverLookupDuration),
          callableMs: 0,
          cacheLookupAttempted: cacheLookupAttempted,
          serverLookupAttempted: serverLookupAttempted,
          callableAttempted: callableAttempted,
        );
      }
    } catch (_) {
      cacheLookupDuration = _emptyDuration;
    }

    callableAttempted = true;
    final callableWatch = Stopwatch()..start();
    final conversationId = await upsertItemConversation(itemId);
    callableDuration = callableWatch.elapsed;

    return ConversationResolution(
      conversationId: conversationId,
      source: ConversationResolutionSource.callable,
      totalMs: _durationMs(totalWatch.elapsed),
      cacheLookupMs: _durationMs(cacheLookupDuration),
      serverLookupMs: _durationMs(serverLookupDuration),
      callableMs: _durationMs(callableDuration),
      cacheLookupAttempted: cacheLookupAttempted,
      serverLookupAttempted: serverLookupAttempted,
      callableAttempted: callableAttempted,
    );
  }

  static Future<void> prefetchConversationForItem({
    required String itemId,
    required String interestedUserId,
  }) async {
    final key = _conversationKey(
      itemId: itemId,
      interestedUserId: interestedUserId,
    );
    if (_conversationResolutionCache.containsKey(key) ||
        _prefetchedConversationIds.containsKey(key)) {
      return;
    }
    final existingLookup = _prefetchLookupInFlight[key];
    if (existingLookup != null) {
      await existingLookup;
      return;
    }
    final lookup = (() async {
      try {
        return await _existingConversationId(
          itemId: itemId,
          interestedUserId: interestedUserId,
          source: Source.server,
        );
      } catch (_) {
        return null;
      }
    })();
    _prefetchLookupInFlight[key] = lookup;
    try {
      final conversationId = await lookup;
      if (conversationId == null) {
        return;
      }
      _prefetchedConversationIds[key] = conversationId;
      _conversationResolutionCache[key] = _cachedResolution(
        conversationId: conversationId,
      );
    } finally {
      if (identical(_prefetchLookupInFlight[key], lookup)) {
        _prefetchLookupInFlight.remove(key);
      }
    }
  }

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

enum ConversationResolutionSource { cache, callable }

class ConversationResolution {
  const ConversationResolution({
    required this.conversationId,
    required this.source,
    required this.totalMs,
    required this.cacheLookupMs,
    required this.serverLookupMs,
    required this.callableMs,
    required this.cacheLookupAttempted,
    required this.serverLookupAttempted,
    required this.callableAttempted,
  });

  final String conversationId;
  final ConversationResolutionSource source;
  final int totalMs;
  final int cacheLookupMs;
  final int serverLookupMs;
  final int callableMs;
  final bool cacheLookupAttempted;
  final bool serverLookupAttempted;
  final bool callableAttempted;

  String get sourceWire {
    switch (source) {
      case ConversationResolutionSource.cache:
        return "cache";
      case ConversationResolutionSource.callable:
        return "callable";
    }
  }
}
