
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream controller to notify about incoming call data
  final StreamController<Map<String, dynamic>> _callDataController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get callDataStream => _callDataController.stream;

  Future<void> initialize(String currentUserId) async {
    // Request permission for notifications
    await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // Get the FCM token and save it to Firestore
    await _getTokenAndSave(currentUserId);

    // Listen for token refresh and save the new token
    _firebaseMessaging.onTokenRefresh.listen((token) {
      _saveTokenToDatabase(token, currentUserId);
    });

    // Handle messages when the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("Foreground message received: ${message.notification?.title}");
      // In this app, foreground notifications are not critical for calls, 
      // as the user is already online. We can handle them here if needed for other features.
    });

    // Handle when a user taps a notification and the app opens from a terminated state
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleMessage(message);
      }
    });

    // Handle when a user taps a notification and the app opens from a background state
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  void _handleMessage(RemoteMessage message) {
    debugPrint('Message opened from background/terminated: ${message.data}');
    // This is where you would handle navigation if the notification was a call.
    // For re-engagement, we just open the app, so no specific action is needed here,
    // but the structure is ready for future features.
    if (message.data.containsKey('channelId') && message.data.containsKey('agoraToken')) {
        _callDataController.add(message.data);
    }
  }

  Future<void> _getTokenAndSave(String userId) async {
    try {
      final String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _saveTokenToDatabase(token, userId);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  Future<void> _saveTokenToDatabase(String token, String userId) async {
    if (userId.isEmpty) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'lastTokenUpdateTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving FCM token to Firestore: $e');
    }
  }

  void dispose() {
      _callDataController.close();
  }
}
