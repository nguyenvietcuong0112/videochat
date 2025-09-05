
import 'package:cloud_firestore/cloud_firestore.dart';

class Call {
  final String channelId;
  final String? callerId;
  final String? callerName;
  final String? receiverId;
  final String? receiverName;
  final String agoraToken;
  final String status; // "created", "ongoing", "ended"
  final List<String> participants;
  final Timestamp createdAt;

  Call({
    required this.channelId,
    this.callerId,
    this.callerName,
    this.receiverId,
    this.receiverName,
    required this.agoraToken,
    required this.status,
    required this.participants,
    required this.createdAt,
  });

  factory Call.fromMap(Map<String, dynamic> map) {
    return Call(
      channelId: map['channelId'] as String,
      callerId: map['callerId'] as String?,
      callerName: map['callerName'] as String?,
      receiverId: map['receiverId'] as String?,
      receiverName: map['receiverName'] as String?,
      agoraToken: map['agoraToken'] as String,
      status: map['status'] as String,
      participants: List<String>.from(map['participants'] as List),
      createdAt: map['createdAt'] as Timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'channelId': channelId,
      'callerId': callerId,
      'callerName': callerName,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'agoraToken': agoraToken,
      'status': status,
      'participants': participants,
      'createdAt': createdAt,
    };
  }

  Call copyWith({
    String? channelId,
    String? callerId,
    String? callerName,
    String? receiverId,
    String? receiverName,
    String? agoraToken,
    String? status,
    List<String>? participants,
    Timestamp? createdAt,
  }) {
    return Call(
      channelId: channelId ?? this.channelId,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      agoraToken: agoraToken ?? this.agoraToken,
      status: status ?? this.status,
      participants: participants ?? this.participants,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
