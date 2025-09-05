
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:stranger_chat/shared/services/notification_service.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<User?>? _authStateSubscription;

  User? _user;
  User? get user => _user;

  final NotificationService _notificationService = NotificationService();

  AuthService() {
    _authStateSubscription = _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    _user = user;
    if (user != null) {
      // User is logged in, initialize notification service
      await _notificationService.initialize(user.uid);
    } 
    notifyListeners();
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _notificationService.dispose();
    super.dispose();
  }
}
