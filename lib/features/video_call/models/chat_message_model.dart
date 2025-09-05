
class ChatMessage {
  final String uid; // User ID of the sender
  final String text;
  final DateTime timestamp;

  ChatMessage({required this.uid, required this.text, required this.timestamp});
}
