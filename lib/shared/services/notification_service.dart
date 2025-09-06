
import 'dart:async';
import 'dart:developer' as developer;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _tokenSubscription;

  Future<void> initialize(String userId) async {
    // Request permission for iOS and web
    await _firebaseMessaging.requestPermission();

    // Get the FCM token
    final String? fcmToken = await _firebaseMessaging.getToken();

    if (fcmToken != null) {
      // Save the token to the user's document in Firestore
      await _saveTokenToDatabase(userId, fcmToken);

      // Listen for token refreshes and save the new token
      _tokenSubscription = _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _saveTokenToDatabase(userId, newToken);
      });
    }
  }

  Future<void> _saveTokenToDatabase(String userId, String token) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
      });
    } catch (e, s) {
      // Handle potential errors, e.g., if the user document doesn't exist yet.
      developer.log(
        'Error saving FCM token',
        name: 'myapp.notification_service',
        error: e,
        stackTrace: s,
      );
    }
  }

  void dispose() {
    _tokenSubscription?.cancel();
  }
}
