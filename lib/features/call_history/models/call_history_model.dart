
import 'package:cloud_firestore/cloud_firestore.dart';

class CallHistory {
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final Timestamp timestamp;
  final int durationInSeconds;

  CallHistory({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    required this.timestamp,
    required this.durationInSeconds,
  });

  factory CallHistory.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CallHistory(
      id: doc.id,
      otherUserId: data['otherUserId'] ?? '',
      otherUserName: data['otherUserName'] ?? 'Unknown',
      otherUserAvatar: data['otherUserAvatar'],
      timestamp: data['timestamp'] ?? Timestamp.now(),
      durationInSeconds: data['durationInSeconds'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'otherUserId': otherUserId,
      'otherUserName': otherUserName,
      'otherUserAvatar': otherUserAvatar,
      'timestamp': timestamp,
      'durationInSeconds': durationInSeconds,
    };
  }
}
