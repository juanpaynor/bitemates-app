import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum AuthState {
  unknown,
  authenticated,
  unauthenticated,
}

enum OnboardingStatus {
  unknown,
  needsAdditionalInfo,
  needsQuiz,
  complete,
}

class AuthNotifier with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<User?>? _authStateSubscription;

  AuthState _authState = AuthState.unknown;
  OnboardingStatus _onboardingStatus = OnboardingStatus.unknown;
  User? _user;
  String? _nickname;
  String? _photoUrl;

  AuthState get authState => _authState;
  OnboardingStatus get onboardingStatus => _onboardingStatus;
  User? get user => _user;
  String? get nickname => _nickname;
  String? get photoUrl => _photoUrl;

  AuthNotifier() {
    _authStateSubscription = _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    if (user == null) {
      _user = null;
      _nickname = null;
      _photoUrl = null;
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
        _nickname = data['nickname'] as String?;
        _photoUrl = data['photoUrl'] as String?;
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
        _onboardingStatus = OnboardingStatus.needsAdditionalInfo;
      }
    } catch (e) {
      _onboardingStatus = OnboardingStatus.needsAdditionalInfo;
    }
  }
  
  Future<void> refreshOnboardingStatus() async {
    if (_user != null) {
      await _checkOnboardingStatus(_user!.uid);
      notifyListeners();
    }
  }

  Future<void> completeQuiz() async {
    if (_user != null) {
      try {
        await _firestore.collection('users').doc(_user!.uid).update({
          'quiz_completed': true,
        });
        // After updating, refresh the state to ensure the router redirects correctly.
        await refreshOnboardingStatus();
      } catch (e) {
        // You might want to add some error handling here.
        print("Error completing quiz: $e");
      }
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
}
