
import 'dart:async';
import 'dart:ui';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../shared/services/firestore_service.dart';
import '../models/call_model.dart';
import '../models/chat_message_model.dart';
import '../services/call_service.dart';

class VideoCallScreen extends StatefulWidget {
  final Call call;

  const VideoCallScreen({super.key, required this.call});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final CallService _callService = CallService();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final RtcEngine _engine;

  StreamSubscription? _callStreamSubscription;

  String? _remoteUserName;
  String? _remoteUserAvatar;
  String? _localUserName;
  String? _localUserAvatar;

  bool _isJoined = false;
  int? _remoteUid;
  bool _localUserMuted = false;
  bool _localUserVideoDisabled = false;
  bool _callEnded = false;

  // Chat state
  bool _isChatVisible = false;
  final List<ChatMessage> _messages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String get _currentUserId => _auth.currentUser!.uid;
  String get _otherUserId => widget.call.participants.firstWhere((id) => id != _currentUserId);

  @override
  void initState() {
    super.initState();
    _initAgora();
    _listenToCallChanges();
    _fetchUsersInfo();
  }

  Future<void> _fetchUsersInfo() async {
    final localUserDoc = await _firestoreService.getUser(_currentUserId);
    final remoteUserDoc = await _firestoreService.getUser(_otherUserId);

    if (mounted) {
      setState(() {
        _localUserName = localUserDoc.data()?['displayName'];
        _localUserAvatar = localUserDoc.data()?['photoURL'];
        _remoteUserName = remoteUserDoc.data()?['displayName'];
        _remoteUserAvatar = remoteUserDoc.data()?['photoURL'];
      });
    }
  }

  Future<void> _initAgora() async {
    await [Permission.camera, Permission.microphone].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(appId: '12f3721389824634afc36132b35d33a7'));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          if (_callEnded) return;
          setState(() => _isJoined = true);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          if (_callEnded) return;
          setState(() => _remoteUid = remoteUid);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          if (_callEnded) return;
          setState(() => _remoteUid = null);
          _handleCallEnded();
        },
        onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
            if (reason == ConnectionChangedReasonType.connectionChangedLeaveChannel) {
                 _handleCallEnded();
            }
        },
      ),
    );
    
    await _engine.enableVideo();
    await _engine.startPreview();

    ChannelMediaOptions options = const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    );

    await _engine.joinChannel(
      token: widget.call.agoraToken,
      channelId: widget.call.channelId,
      uid: 0, // Local user uses UID 0
      options: options,
    );
  }

  void _listenToCallChanges() {
    _callStreamSubscription = _callService.listenToCall(widget.call.channelId).listen((snapshot) {
      if (mounted && !_callEnded) {
        if (!snapshot.exists || (snapshot.data() as Map<String, dynamic>)['status'] == 'ended') {
          _handleCallEnded();
        }
      }
    });
  }

  void _handleCallEnded() {
    if (mounted && !_callEnded) {
      setState(() {
        _callEnded = true;
        _isChatVisible = false;
      });
    }
  }

  Future<void> _disposeAgora() async {
      await _engine.leaveChannel();
      await _engine.release();
  }

  Future<void> _leaveAndGoHome() async {
    await _disposeAgora();
    if (mounted) context.go('/');
  }

  Future<void> _findNewMatch() async {
    await _disposeAgora();
    if (mounted) context.go('/', extra: {'find_new_match': true});
  }

  @override
  void dispose() {
    if (!_callEnded) {
        _disposeAgora();
    }
    _callStreamSubscription?.cancel();
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final messageText = _chatController.text.trim();
    if (messageText.isNotEmpty) {
        _chatController.clear();
        _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(child: _remoteVideo()),
              if (!_callEnded)
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 120,
                      height: 180,
                      child: _localPreview(),
                    ),
                  ),
                ),
              if (!_callEnded) _toolbar(),
              if (_isChatVisible) _chatOverlay(),
              if (_callEnded) _callEndedOverlay(),
            ],
          ),
        ),
      ),
    );
  }


  Widget _chatOverlay() {
    return Positioned(
      bottom: 100, 
      left: 10,
      right: 10,
      top: 10,
      child: GestureDetector(
        onTap: () {},
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha((255 * 0.4).round()),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withAlpha((255 * 0.2).round()))
              ),
              child: Column(
                children: [
                  _buildChatHeader(),
                  Expanded(child: _buildMessageList()),
                  _buildChatInput(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('In-call Chat', style: GoogleFonts.oswald(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => setState(() => _isChatVisible = false),
          )
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isLocalUser = message.uid == _currentUserId;

        return Align(
          alignment: isLocalUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isLocalUser ? Theme.of(context).colorScheme.primary.withAlpha((255 * 0.8).round()) : Colors.grey.shade800.withAlpha((255 * 0.8).round()),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(message.text, style: GoogleFonts.roboto(color: Colors.white)),
          ),
        );
      },
    );
  }

  Widget _buildChatInput() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              style: GoogleFonts.roboto(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: GoogleFonts.roboto(color: Colors.white54),
                filled: true,
                fillColor: Colors.black.withAlpha((255 * 0.5).round()),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.all(12)
            ),
            onPressed: _sendMessage,
          )
        ],
      ),
    );
  }


  Widget _callEndedOverlay() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.black.withAlpha((255 * 0.6).round()),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Call Ended', 
                  style: GoogleFonts.oswald(
                    fontSize: 38,
                    color: Colors.white,
                    fontWeight: FontWeight.bold
                  )
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text('Find a New Match', style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: _findNewMatch,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: _leaveAndGoHome, 
                  child: Text('Back to Home', style: GoogleFonts.roboto(color: Colors.white70, fontSize: 15))
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _localPreview() {
     return _buildUserVideo(
        isLocal: true,
        isJoined: _isJoined,
        view: AgoraVideoView(
          controller: VideoViewController(rtcEngine: _engine, canvas: const VideoCanvas(uid: 0)),
        ),
        userName: _localUserName,
        avatarUrl: _localUserAvatar,
        videoDisabled: _localUserVideoDisabled,
      );
  }

  Widget _remoteVideo() {
    if (_remoteUid != null) {
       return _buildUserVideo(
        isLocal: false,
        isJoined: true,
        view: AgoraVideoView(
            controller: VideoViewController.remote(
                rtcEngine: _engine, 
                canvas: VideoCanvas(uid: _remoteUid!),
                connection: RtcConnection(channelId: widget.call.channelId),
            ),
        ),
        userName: _remoteUserName,
        avatarUrl: _remoteUserAvatar,
        videoDisabled: false, 
      );
    } else {
      return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                 _buildAvatar(avatarUrl: _remoteUserAvatar, size: 120),
                 const SizedBox(height: 24),
                 Text(
                    'Waiting for ${_remoteUserName ?? 'stranger'} to connect...',
                    style: GoogleFonts.roboto(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
            ],
        ),
      );
    }
  }

  Widget _buildUserVideo({
    required bool isLocal,
    required bool isJoined,
    required Widget view,
    required String? userName,
    required String? avatarUrl,
    required bool videoDisabled,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(isLocal ? 16 : 0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isJoined && !videoDisabled) view,
          if (!isJoined || videoDisabled)
            Container(
              color: Colors.grey.shade900,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildAvatar(avatarUrl: avatarUrl, size: isLocal ? 40 : 80),
                    const SizedBox(height: 8),
                    Text(userName ?? '...', style: GoogleFonts.roboto(color: Colors.white, fontSize: isLocal ? 14: 18)),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha((255 * 0.5).round()),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isLocal ? (userName ?? 'You') : (userName ?? 'Stranger'), 
                      style: GoogleFonts.roboto(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAvatar({String? avatarUrl, required double size}) {
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
          return CircleAvatar(radius: size / 2, backgroundImage: NetworkImage(avatarUrl), backgroundColor: Colors.grey.shade800);
      }
      return CircleAvatar(radius: size / 2, backgroundColor: Colors.grey.shade600, child: Icon(Icons.person, size: size * 0.7, color: Colors.white70));
  }

  Widget _toolbar() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 30, left: 20, right: 20),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha((255 * 0.3).round()),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: Colors.white.withAlpha((255 * 0.2).round())),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildToolbarButton(_onToggleMute, _localUserMuted ? Icons.mic_off : Icons.mic, _localUserMuted),
                   _buildToolbarButton(() => setState(() => _isChatVisible = !_isChatVisible), Icons.chat_bubble_outline_rounded, _isChatVisible),
                  _buildEndCallButton(),
                  _buildToolbarButton(_onToggleVideo, _localUserVideoDisabled ? Icons.videocam_off : Icons.videocam, _localUserVideoDisabled),
                  _buildMoreOptionsButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreOptionsButton() {
    return IconButton(
        icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
        onPressed: () => showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (context) => _buildBottomSheet()),
    );
  }

  Widget _buildBottomSheet() {
    return ClipRRect(
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
                color: Colors.grey.shade900.withAlpha((255 * 0.7).round()),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        ListTile(
                            leading: const Icon(Icons.report_problem_outlined, color: Colors.white),
                            title: Text('Report User', style: GoogleFonts.roboto(color: Colors.white)),
                            onTap: () { Navigator.of(context).pop(); _reportUser(); },
                        ),
                        ListTile(
                            leading: const Icon(Icons.block, color: Colors.white),
                            title: Text('Block User', style: GoogleFonts.roboto(color: Colors.white)),
                            onTap: () { Navigator.of(context).pop(); _blockUser(); },
                        ),
                        const Divider(color: Colors.white24, height: 1),
                        ListTile(
                            leading: const Icon(Icons.cancel_outlined, color: Colors.white),
                            title: Text('Cancel', style: GoogleFonts.roboto(color: Colors.white)),
                            onTap: () => Navigator.of(context).pop(),
                        ),
                    ],
                ),
            ),
        ),
    );
}


  Future<void> _reportUser() async {
    final confirm = await _showConfirmationDialog('Report User', 'Are you sure you want to report this user? This will also block them and end the call.');
    if (confirm) {
        await _callService.reportUser(reporterId: _currentUserId, reportedUserId: _otherUserId, callId: widget.call.channelId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User has been reported. The call will now end.')));
        await _confirmEndCall(forceEnd: true);
    }
  }

  Future<void> _blockUser() async {
     final confirm = await _showConfirmationDialog('Block User', 'Are you sure you want to block this user? You won\'t be matched with them again. The call will end.');
    if (confirm) {
        await _callService.blockUser(currentUserId: _currentUserId, blockedUserId: _otherUserId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User has been blocked. The call will now end.')));
        await _confirmEndCall(forceEnd: true);
    }
  }

  Widget _buildToolbarButton(VoidCallback onPressed, IconData icon, bool isActive) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 28),
      style: IconButton.styleFrom(
        backgroundColor: isActive ? Theme.of(context).colorScheme.primary : Colors.black.withAlpha((255 * 0.3).round()),
        padding: const EdgeInsets.all(15),
      ),
    );
  }

  Widget _buildEndCallButton() {
    return IconButton(
      onPressed: () => _confirmEndCall(),
      icon: const Icon(Icons.call_end, color: Colors.white, size: 35),
      style: IconButton.styleFrom(
        backgroundColor: Colors.redAccent,
        padding: const EdgeInsets.all(18),
        shape: const CircleBorder(),
      ),
    );
  }

  void _onToggleMute() {
    setState(() {
      _localUserMuted = !_localUserMuted;
    });
    _engine.muteLocalAudioStream(_localUserMuted);
  }

  void _onToggleVideo() {
    setState(() {
      _localUserVideoDisabled = !_localUserVideoDisabled;
    });
    _engine.muteLocalVideoStream(_localUserVideoDisabled);
  }
  
  Future<bool> _showConfirmationDialog(String title, String content) async {
     final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[850],
          title: Text(title, style: GoogleFonts.oswald(color: Colors.white)),
          content: Text(content, style: GoogleFonts.roboto(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Cancel', style: GoogleFonts.roboto(color: Colors.white))),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Confirm', style: GoogleFonts.roboto(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold))),
          ],
        ),
      );
      return confirm ?? false;
  }

  Future<void> _confirmEndCall({bool forceEnd = false}) async {
      if (forceEnd) {
          await _callService.endCall(widget.call);
          _handleCallEnded();
          return;
      }

      final confirm = await _showConfirmationDialog('End Call?', 'Are you sure you want to end this conversation?');
      if (confirm) {
         await _callService.endCall(widget.call);
         _handleCallEnded();
      }
  }
}
