import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

enum AuthState { unknown, authenticated, unauthenticated }
enum OnboardingStatus { unknown, needsAdditionalInfo, needsQuiz, complete }

class AuthNotifier with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<User?>? _authSubscription;

  AuthState _authState = AuthState.unknown;
  OnboardingStatus _onboardingStatus = OnboardingStatus.unknown;
  User? _user;

  AuthState get authState => _authState;
  OnboardingStatus get onboardingStatus => _onboardingStatus;
  User? get user => _user;

  AuthNotifier() {
    _authSubscription = _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    if (user == null) {
      _user = null;
      _authState = AuthState.unauthenticated;
      _onboardingStatus = OnboardingStatus.unknown;
    } else {
      _user = user;
      _authState = AuthState.authenticated;
      await _checkOnboardingStatus(user.uid);
    }
    notifyListeners();
  }

  Future<void> _checkOnboardingStatus(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        final additionalInfoCompleted = data['additional_info_completed'] ?? false;
        final quizCompleted = data['quiz_completed'] ?? false;

        if (!additionalInfoCompleted) {
          _onboardingStatus = OnboardingStatus.needsAdditionalInfo;
        } else if (!quizCompleted) {
          _onboardingStatus = OnboardingStatus.needsQuiz;
        } else {
          _onboardingStatus = OnboardingStatus.complete;
        }
      } else {
        // If the doc doesn't exist, they need to start from the beginning
        _onboardingStatus = OnboardingStatus.needsAdditionalInfo;
      }
    } catch (e) {
      // Default to needs additional info on error
      _onboardingStatus = OnboardingStatus.needsAdditionalInfo;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
