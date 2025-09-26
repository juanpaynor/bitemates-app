import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'dart:developer' as developer;

class MatchingScreen extends StatefulWidget {
  const MatchingScreen({super.key});

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<DocumentSnapshot>? _userSubscription;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _startMatchingProcess();
  }

  Future<void> _startMatchingProcess() async {
    final user = _auth.currentUser;
    if (user == null) {
      developer.log('User not authenticated!', name: 'com.bitemates.matching');
      if (mounted) context.go('/login');
      return;
    }

    // *** THE FIX: Mark the user as waiting in Firestore FIRST ***
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'isWaitingForGroup': true,
        'groupAssigned': false,
        'groupId': null, // Clear any previous group associations
        'waitingSince': FieldValue.serverTimestamp(), // Set the waiting time
      });
    } catch (e) {
      developer.log('Error setting user to waiting state: $e', name: 'com.bitemates.error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start matching. Please try again.')),
        );
        context.go('/home');
      }
      return;
    }
    
    // Listen for changes to the user's document (specifically the groupId)
    _userSubscription = _firestore.collection('users').doc(user.uid).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>?;
        // Check if groupAssigned is true and groupId is present
        if (data != null && data['groupAssigned'] == true && data['groupId'] != null) {
          final groupId = data['groupId'] as String;
          developer.log('GroupId found: $groupId. Navigating to group screen.', name: 'com.bitemates.matching');
          _stopListening();
          if (mounted) context.go('/my-group/$groupId');
        }
      }
    });

    // Start polling the createGroups function
    _callCreateGroups(); // Call it once immediately
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _callCreateGroups();
    });
  }

  Future<void> _callCreateGroups() async {
    // Check if the user has already been assigned a group
    final userDoc = await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
    if (userDoc.exists && userDoc.data()?['groupAssigned'] == true) {
      _stopListening(); // Stop polling if a group is already found
      return;
    }

    try {
      final callable = _functions.httpsCallable('createGroups');
      final result = await callable.call();
      final status = result.data?['status'];
      developer.log('createGroups function returned status: $status', name: 'com.bitemates.matching');

    } on FirebaseFunctionsException catch (e) {
      developer.log('Firebase Functions Exception: ${e.code} - ${e.message}', name: 'com.bitemates.error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error finding a match: ${e.message}')),
        );
        context.go('/home');
      }
       _stopListening();
    } catch (e) {
      developer.log('Generic Error calling createGroups: $e', name: 'com.bitemates.error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An unexpected error occurred while matching.')),
        );
        context.go('/home');
      }
       _stopListening();
    }
  }

  void _stopListening() {
    _userSubscription?.cancel();
    _pollingTimer?.cancel();
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
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
              width: 300,
              height: 300,
            ),
            const SizedBox(height: 20),
            const Text(
              'Finding your BiteMates...',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4E3D35),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Hang tight, we are finding the best\npeople for you to dine with!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(onPressed: () {context.go('/home');}, child: const Icon(Icons.arrow_back)),
    );
  }
}
