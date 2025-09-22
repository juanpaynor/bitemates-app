import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_functions/cloud_functions.dart';

class MatchingScreen extends StatefulWidget {
  const MatchingScreen({super.key});

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> with TickerProviderStateMixin {
  late final AnimationController _animationController;
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  String _statusText = 'Finding your bitemates...';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this);
    _initiateMatching();
    _listenForGroupChanges();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _userSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initiateMatching() async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('createGroups');
      callable.call(); // Fire and forget
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusText = "An error occurred while finding your group. Please try again later.";
        });
      }
    }
  }

  void _listenForGroupChanges() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((userDoc) {
      if (userDoc.exists && mounted) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final groupId = userData['groupId'] as String?;
        final matchingStatus = userData['matching_status'] as String?;

        if (groupId != null && groupId.isNotEmpty) {
          _userSubscription?.cancel();
          context.go('/my-group/$groupId');
        } else if (matchingStatus == 'no_mates_available') {
            setState(() {
              _statusText = "Sorry, there aren't enough bitemates in your area to form a group yet. We are expanding and will notify you soon!";
            });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6EF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/searching_for_profile.json',
              controller: _animationController,
              onLoaded: (composition) {
                _animationController
                  ..duration = composition.duration
                  ..forward()
                  ..repeat();
              },
              width: 300,
              height: 300,
            ),
            const SizedBox(height: 30),
            Text(
              'Finding Your Bitemates',
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF4E3D35),
              ),
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Text(
                _statusText,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.black54,
                  height: 1.5,
                ),
               ),
            ),
          ],
        ),
      ),
    );
  }
}
