
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/features/video_call/models/call_model.dart';
import 'package:myapp/features/video_call/services/agora_service.dart';
import 'package:uuid/uuid.dart';

class MatchmakingService {
  final AgoraService _agoraService = AgoraService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  late final CollectionReference _waitingPoolCollection = _firestore.collection('waiting_pool');
  late final CollectionReference _callsCollection = _firestore.collection('calls');
  late final CollectionReference _usersCollection = _firestore.collection('users');

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

  Future<void> findOrStartMatch(String userId, String displayName) async {
    // Get the current user's block list first.
    final userDoc = await _usersCollection.doc(userId).get();
    final userData = userDoc.data() as Map<String, dynamic>?;
    final List<dynamic> blockedUsers = userData?['blockedUsers'] ?? [];

    await _firestore.runTransaction((transaction) async {
      // Find potential opponents, fetch a few to have fallbacks.
      final QuerySnapshot waitingPool = await _waitingPoolCollection
          .where('uid', isNotEqualTo: userId)
          .limit(10)
          .get();

      DocumentSnapshot? opponentDoc;

      // Iterate to find the first non-blocked user.
      for (final doc in waitingPool.docs) {
        if (!blockedUsers.contains(doc['uid'])) {
          opponentDoc = doc;
          break;
        }
      }

      if (opponentDoc != null) {
        // --- Opponent found ---
        final opponentId = opponentDoc['uid'];

        transaction.delete(opponentDoc.reference);
        transaction.delete(_waitingPoolCollection.doc(userId));

        final channelId = const Uuid().v4();
        final token = await _agoraService.getToken(channelId, 0);

        final newCall = Call(
          channelId: channelId,
          agoraToken: token,
          participants: [userId, opponentId],
          status: 'created',
          createdAt: Timestamp.now(),
        );

        transaction.set(_callsCollection.doc(channelId), newCall.toMap());
      } else {
        // --- No valid opponent found, add user to the waiting pool ---
        transaction.set(_waitingPoolCollection.doc(userId), {
          'uid': userId,
          'displayName': displayName,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> cancelMatchmaking(String userId) async {
    await _waitingPoolCollection.doc(userId).delete();
  }
}
