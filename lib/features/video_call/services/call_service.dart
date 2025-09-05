
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/call_model.dart';

class CallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final CollectionReference _callCollection = _firestore.collection('calls');
  late final CollectionReference _userCollection = _firestore.collection('users');

  Future<void> endCall(Call call) async {
    try {
      final duration = DateTime.now().difference(call.createdAt.toDate()).inSeconds;
      
      // Add to each participant's history
      for (String userId in call.participants) {
        await addCallToHistory(userId, call, duration);
      }

      await _callCollection.doc(call.channelId).delete();
    } catch (e) {
      // Handle error, e.g., log it
      print('Error ending call and saving history: $e');
    }
  }
  
  Future<void> addCallToHistory(String userId, Call call, int duration) async {
    final otherUserId = call.participants.firstWhere((id) => id != userId);
    final otherUserDoc = await _userCollection.doc(otherUserId).get();
    final otherUserData = otherUserDoc.data() as Map<String, dynamic>?;

    final historyData = {
      'otherUserId': otherUserId,
      'otherUserName': otherUserData?['displayName'] ?? 'Stranger',
      'otherUserAvatar': otherUserData?['photoURL'],
      'timestamp': FieldValue.serverTimestamp(),
      'durationInSeconds': duration,
      'channelId': call.channelId, // To avoid duplicates if needed
    };

    await _userCollection.doc(userId).collection('call_history').add(historyData);
  }
  
  Stream<DocumentSnapshot> listenToCall(String channelId) {
    return _callCollection.doc(channelId).snapshots();
  }
  
  Future<void> reportUser({required String reporterId, required String reportedUserId, required String callId}) async {
    await blockUser(currentUserId: reporterId, blockedUserId: reportedUserId);
    // You might want to add more sophisticated reporting logic here, 
    // like saving a report to a separate collection.
  }

  Future<void> blockUser({required String currentUserId, required String blockedUserId}) async {
    // Add blockedUserId to the current user's block list
    await _userCollection.doc(currentUserId).update({
      'blockedUsers': FieldValue.arrayUnion([blockedUserId])
    });
    // Also add the current user to the blocked user's block list so they can't match either
    await _userCollection.doc(blockedUserId).update({
      'blockedUsers': FieldValue.arrayUnion([currentUserId])
    });
  }
}
