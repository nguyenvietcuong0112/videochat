import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/call_model.dart';
import 'agora_service.dart';

class MatchmakingService {
  final AgoraService _agoraService = AgoraService();
  final CollectionReference _waitingPoolCollection = FirebaseFirestore.instance.collection('waiting_pool');
  final CollectionReference _callsCollection = FirebaseFirestore.instance.collection('calls');

  Stream<Call?> getCallStreamForUser(String userId) {
    return _callsCollection
        .where('participants', arrayContains: userId)
        .where('status', whereIn: ['created', 'ongoing'])
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return null;
      }
      final callData = snapshot.docs.first.data() as Map<String, dynamic>?;
      return callData != null ? Call.fromMap(callData) : null;
    });
  }

  Stream<DocumentSnapshot> getCallStream(String channelId) {
      return _callsCollection.doc(channelId).snapshots();
  }

  Future<void> joinWaitingPool(String userId, String userName) async {
    await _waitingPoolCollection.doc(userId).set({
      'userId': userId,
      'userName': userName,
      'timestamp': FieldValue.serverTimestamp(),
    });
    await _tryToMatch(userId, userName);
  }

  Future<void> leaveWaitingPool(String userId) async {
    await _waitingPoolCollection.doc(userId).delete();
  }

  Future<void> _tryToMatch(String currentUserId, String currentUserName) async {
    final snapshot = await _waitingPoolCollection
        .where('userId', isNotEqualTo: currentUserId)
        .orderBy('timestamp')
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final matchedUserDoc = snapshot.docs.first;
      final matchedUserId = matchedUserDoc.id;
      final matchedUserName = matchedUserDoc['userName'] as String;

      await _waitingPoolCollection.doc(currentUserId).delete();
      await _waitingPoolCollection.doc(matchedUserId).delete();

      await createCall(currentUserId, currentUserName, matchedUserId, matchedUserName);
    }
  }

  Future<Call> createCall(
      String callerId, String callerName, String receiverId, String receiverName) async {
    final channelId = const Uuid().v4();
    
    final agoraToken = await _agoraService.getToken(channelId);

    final call = Call(
      channelId: channelId,
      callerId: callerId,
      callerName: callerName,
      receiverId: receiverId,
      receiverName: receiverName,
      agoraToken: agoraToken,
      status: 'created',
      participants: [callerId, receiverId],
      createdAt: Timestamp.now(),
    );

    await _callsCollection.doc(channelId).set(call.toMap());
    return call;
  }

  Future<void> endCall(Call call) async {
    await _callsCollection.doc(call.channelId).update({'status': 'ended'});
  }
}
