
import 'dart:async';
import 'package:agora_rtm/agora_rtm.dart';
import 'package:flutter/foundation.dart';

// A simple wrapper for the Agora RTM SDK
class AgoraRtmService {
  final String appId;
  AgoraRtmClient? _client;
  AgoraRtmChannel? _channel;

  // Stream controllers to broadcast RTM events
  final StreamController<String> _messageController = StreamController<String>.broadcast();
  final StreamController<AgoraRtmConnectionState> _connectionStateController = StreamController<AgoraRtmConnectionState>.broadcast();

  // Public streams for widgets to listen to
  Stream<String> get onMessageReceived => _messageController.stream;
  Stream<AgoraRtmConnectionState> get onConnectionStateChanged => _connectionStateController.stream;

  AgoraRtmService({required this.appId});

  // Initialize the RTM client and set up event listeners
  Future<void> initialize() async {
    _client = await AgoraRtmClient.createInstance(appId);

    _client?.onMessageReceived = (AgoraRtmMessage message, String peerId) {
      _messageController.add(message.text);
    };

    _client?.onConnectionStateChanged2 = (AgoraRtmConnectionState state, AgoraRtmConnectionChangeReason reason) {
      _connectionStateController.add(state);
      if (state == AgoraRtmConnectionState.aborted) {
        // Handle logic for aborted connection if necessary
      }
    };

    // Listen for messages within the channel
    _channel?.onMessageReceived = (AgoraRtmMessage message, AgoraRtmMember member) {
      _messageController.add(message.text);
    };
  }

  // Login to the RTM system
  Future<void> login(String token, String userId) async {
    try {
      await _client?.login(token, userId);
    } catch (e) {
      debugPrint('RTM Login Error: $e');
    }
  }

  // Join a specific RTM channel
  Future<void> joinChannel(String channelId) async {
    try {
      _channel = await _client?.createChannel(channelId);
      await _channel?.join();
    } catch (e) {
      debugPrint('RTM Join Channel Error: $e');
    }
  }
  
  Future<String> getToken(String channelName) async {
    // In a production app, you would fetch this token from your own server.
    // This temporary token is for demonstration purposes only and will expire.
    return '007eJxTYPCvupnj/Lzi/v/T/dUNd4sP732zWvL8f9+Zt4t6j1c8b/JVYDBLskhLNDFPMjFINLFIM0sxNDMxNDI0M0w1SDZJtjQ2WzLcn9Ke2hDIyPDp/s/MyACBID4LQ3FJaX4eAwMA7/IeVw==';
  }

  // Send a message to the joined RTM channel
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    try {
      final AgoraRtmMessage message = AgoraRtmMessage.fromText(text);
      await _channel?.sendMessage(message);
      // Also add the sent message to the local stream to display it immediately
      _messageController.add(message.text);
    } catch (e) {
      debugPrint('RTM Send Message Error: $e');
    }
  }

  // Leave the RTM channel
  Future<void> leaveChannel() async {
    try {
      await _channel?.leave();
    } catch (e) {
      debugPrint('RTM Leave Channel Error: $e');
    }
  }

  // Logout from the RTM system
  Future<void> logout() async {
    try {
      await _client?.logout();
    } catch (e) {
      debugPrint('RTM Logout Error: $e');
    }
  }

  // Dispose of all resources
  Future<void> dispose() async {
    await leaveChannel();
    await logout();
    await _client?.release();
    _messageController.close();
    _connectionStateController.close();
  }
}

