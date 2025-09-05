
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/call_history_model.dart';

class CallHistoryScreen extends StatelessWidget {
  const CallHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to see your call history.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Call History', style: GoogleFonts.oswald(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 1,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('call_history')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off_rounded, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 20),
                  Text(
                    'No Calls Yet',
                    style: GoogleFonts.oswald(fontSize: 24, color: Colors.grey.shade600),
                  ),
                  Text(
                    'Your recent calls will appear here.',
                    style: GoogleFonts.roboto(fontSize: 16, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          final callDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: callDocs.length,
            itemBuilder: (context, index) {
              final history = CallHistory.fromFirestore(callDocs[index]);
              return _buildHistoryTile(context, history);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryTile(BuildContext context, CallHistory history) {
    final theme = Theme.of(context);
    final formattedDate = DateFormat.yMMMd().add_jm().format(history.timestamp.toDate());
    final duration = Duration(seconds: history.durationInSeconds);
    final durationString = 
        '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

    return ListTile(
      leading: CircleAvatar(
        radius: 28,
        backgroundImage: history.otherUserAvatar != null && history.otherUserAvatar!.isNotEmpty
            ? NetworkImage(history.otherUserAvatar!)
            : null,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: history.otherUserAvatar == null || history.otherUserAvatar!.isEmpty
            ? Text(
                history.otherUserName.isNotEmpty ? history.otherUserName[0].toUpperCase() : '?',
                style: GoogleFonts.oswald(fontSize: 22, color: theme.colorScheme.onPrimaryContainer),
              )
            : null,
      ),
      title: Text(
        history.otherUserName,
        style: GoogleFonts.roboto(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      subtitle: Text(
        formattedDate,
        style: GoogleFonts.roboto(color: Colors.grey.shade600, fontSize: 14),
      ),
      trailing: Text(
        durationString,
        style: GoogleFonts.roboto(fontSize: 15, color: theme.colorScheme.primary, fontWeight: FontWeight.w500),
      ),
    );
  }
}
