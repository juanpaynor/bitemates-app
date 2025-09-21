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
  StreamSubscription? _groupSubscription;
  bool _isMatching = false;
  String _statusText = 'Finding your bitemates...';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this);
    _startMatchingProcess();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _groupSubscription?.cancel();
    super.dispose();
  }

  void _startMatchingProcess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }

    setState(() {
      _isMatching = true;
      _statusText = 'Checking for existing groups...';
    });

    // 1. Check if user is already in a group
    final existingGroup = await _findUserGroup(user.uid);
    if (existingGroup != null) {
      _navigateToGroup(existingGroup.id);
      return;
    }

    // 2. If not, start listening for new groups and trigger the function
    _listenForGroup(user.uid);

    try {
      setState(() {
        _statusText = 'No groups found. Let\'s make one for you!\nThis might take a moment...';
      });
      
      await FirebaseFunctions.instance.httpsCallable('createGroups').call();

      // Add a timeout for the listener in case something goes wrong.
      Future.delayed(const Duration(seconds: 45), () {
        if (mounted && _isMatching) {
          setState(() {
            _statusText = "The kitchen seems busy! It's taking longer than usual to find a match. Please hang tight or try again in a bit.";
          });
        }
      });

    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() {
          _isMatching = false;
          _statusText = "Something went wrong on our end!\nError: ${e.message}";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isMatching = false;
          _statusText = "An unexpected error occurred. Please try again.";
        });
      }
    }
  }

  Future<DocumentSnapshot?> _findUserGroup(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('groups')
        .where('user_ids', arrayContains: userId)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first;
    }
    return null;
  }

  void _listenForGroup(String userId) {
    _groupSubscription = FirebaseFirestore.instance
        .collection('groups')
        .where('user_ids', arrayContains: userId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final groupDoc = snapshot.docs.first;
        _navigateToGroup(groupDoc.id);
      }
    });
  }

  void _navigateToGroup(String groupId) {
    if (mounted) {
      _groupSubscription?.cancel(); // Stop listening
      setState(() {
        _isMatching = false;
      });
      context.go('/my-group');
    }
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
              'assets/animations/Food.json',
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
              _isMatching ? 'Matching in Progress' : 'Match Found!',
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
