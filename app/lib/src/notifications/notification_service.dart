import "dart:async";
import "dart:convert";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:crypto/crypto.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "../config/e2e_config.dart";
import "../home/chat_thread_screen.dart";

class NotificationService {
  NotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static GlobalKey<NavigatorState>? _navigatorKey;
  static StreamSubscription<User?>? _authSubscription;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  static String? _registeredUid;
  static String? _registeredTokenId;
  static bool _initialized = false;

  static Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    _navigatorKey = navigatorKey;
    if (_initialized || kIsWeb || E2EConfig.disableFirebaseSideEffects) {
      return;
    }
    _initialized = true;

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      _handleAuthState,
    );
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        return;
      }
      unawaited(_saveToken(uid: uid, token: token));
    });
    _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _openChatFromMessage,
    );

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openChatFromMessage(initialMessage);
      });
    }
  }

  static Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();
    _authSubscription = null;
    _tokenRefreshSubscription = null;
    _messageOpenedSubscription = null;
    _initialized = false;
  }

  static Future<void> _handleAuthState(User? user) async {
    final previousUid = _registeredUid;
    final previousTokenId = _registeredTokenId;
    _registeredUid = null;
    _registeredTokenId = null;

    if (previousUid != null && previousTokenId != null) {
      try {
        await _firestore
            .collection("users")
            .doc(previousUid)
            .collection("notificationTokens")
            .doc(previousTokenId)
            .set({
              "enabled": false,
              "updatedAt": FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      } catch (error) {
        debugPrint("Could not disable notification token: $error");
      }
    }

    if (user == null) {
      return;
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) {
      return;
    }
    await _saveToken(uid: user.uid, token: token);
  }

  static Future<void> _saveToken({
    required String uid,
    required String token,
  }) async {
    final tokenId = _tokenDocumentId(token);
    await _firestore
        .collection("users")
        .doc(uid)
        .collection("notificationTokens")
        .doc(tokenId)
        .set({
          "token": token,
          "platform": defaultTargetPlatform.name,
          "enabled": true,
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    _registeredUid = uid;
    _registeredTokenId = tokenId;
  }

  static String _tokenDocumentId(String token) {
    return sha256.convert(utf8.encode(token)).toString();
  }

  static void _openChatFromMessage(RemoteMessage message) {
    final conversationId = message.data["conversationId"]?.trim();
    if (conversationId == null || conversationId.isEmpty) {
      return;
    }
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      return;
    }
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ChatThreadScreen(conversationId: conversationId),
      ),
    );
  }
}
