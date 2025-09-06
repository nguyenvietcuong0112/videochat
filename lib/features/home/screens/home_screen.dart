
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../shared/services/auth_service.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../video_call/services/matchmaking_service.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic>? extra;
  const HomeScreen({super.key, this.extra});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final FirestoreService _firestoreService = FirestoreService();
  final MatchmakingService _matchmakingService = MatchmakingService();
  final NotificationService _notificationService = NotificationService();
  
  User? get _currentUser => FirebaseAuth.instance.currentUser;
  StreamSubscription? _callSubscription;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();

    if (widget.extra?['find_new_match'] == true) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _startRandomChat();
        }
      });
    }
  }

  void _initialize() async {
    if (_currentUser == null) return;
    
    // Handle notifications
    _notificationService.initialize(_currentUser!.uid);

    // Update user status and last seen timestamp
    _firestoreService.updateUserStatus(_currentUser!.uid, true);
    _firestoreService.updateUserLastSeen(_currentUser!.uid);

    // Listen for incoming or matched calls
    _callSubscription =
        _matchmakingService.getCallStreamForUser(_currentUser!.uid).listen((call) {
      if (mounted && call != null && call.status == 'created') {
         if (_isSearching) {
          setState(() {
            _isSearching = false;
          });
        }
        // Navigate to the call screen
        context.go('/video-call', extra: call);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_currentUser == null) return;
    
    if (state == AppLifecycleState.resumed) {
      _firestoreService.updateUserStatus(_currentUser!.uid, true);
      _firestoreService.updateUserLastSeen(_currentUser!.uid); 
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
       if (_isSearching) {
        _cancelRandomChat();
      }
      _firestoreService.updateUserStatus(_currentUser!.uid, false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callSubscription?.cancel();
    if (_isSearching && _currentUser != null) {
      _matchmakingService.cancelMatchmaking(_currentUser!.uid);
    }
    if (_currentUser != null) {
      _firestoreService.updateUserStatus(_currentUser!.uid, false);
    }
    super.dispose();
  }

  void _startRandomChat() {
    if (_currentUser == null) return;
    setState(() {
      _isSearching = true;
    });
    // Use the updated matchmaking service method
    _matchmakingService.findOrStartMatch(
      _currentUser!.uid,
      _currentUser!.displayName ?? 'Anonymous User',
    );
  }

  void _cancelRandomChat() {
    if (_currentUser == null || !_isSearching) return;
    setState(() {
      _isSearching = false;
    });
    // Use the updated matchmaking service method
    _matchmakingService.cancelMatchmaking(_currentUser!.uid);
  }
  
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Random Connect',
          style: GoogleFonts.oswald(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () => context.go('/history'),
            tooltip: 'Call History',
            color: Colors.white,
          ),
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: () => themeProvider.toggleTheme(),
            tooltip: 'Toggle Theme',
            color: Colors.white,
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: () async {
              if (_isSearching) {
                _cancelRandomChat();
              }
              await authService.signOut();
            },
            tooltip: 'Sign Out',
            color: Colors.white,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [Colors.deepPurple.shade900, Colors.black]
                : [Colors.deepPurple.shade400, Colors.purple.shade300],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _isSearching ? _buildSearchingUI() : _buildIdleUI(),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchingUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: 40),
        Text(
          'Finding a stranger...',
          style: GoogleFonts.oswald(
            fontSize: 28,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Please wait a moment.',
          style: GoogleFonts.roboto(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
          ),
        ),
        const SizedBox(height: 60),
        ElevatedButton.icon(
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Cancel'),
          onPressed: _cancelRandomChat,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent.withAlpha((255 * 0.8).round()),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIdleUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.connect_without_contact, size: 120, color: Colors.white70),
        const SizedBox(height: 20),
        Text(
          'Ready to Connect?',
          style: GoogleFonts.oswald(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              const Shadow(
                blurRadius: 10.0,
                color: Colors.black38,
                offset: Offset(2.0, 2.0),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 15),
        Text(
          'Tap the button below to start a random video chat.',
          textAlign: TextAlign.center,
          style: GoogleFonts.roboto(fontSize: 18, color: Colors.white.withAlpha((255 * 0.8).round())),
        ),
        const SizedBox(height: 60),
        _buildGlowButton(),
      ],
    );
  }

  Widget _buildGlowButton() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withAlpha((255 * 0.6).round()),
            blurRadius: 25,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.white.withAlpha((255 * 0.2).round()),
            blurRadius: 30,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          )
        ],
        borderRadius: BorderRadius.circular(50),
      ),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.video_call_rounded, size: 28),
        label: Text(
          'Start Random Chat',
          style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        onPressed: _startRandomChat,
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: theme.colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          elevation: 10, // Inner shadow
        ),
      ),
    );
  }
}
