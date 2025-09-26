
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> updateUserPersonality(Map<String, dynamic> personality) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'personality': personality,
        'quiz_completed': true,
      });
    }
  }

  Future<void> updateUserQuizAnswers(List<int> answers) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'quizAnswers': answers,
        'quiz_completed': true,
      });
    }
  }

  Future<String> uploadProfilePicture(Uint8List imageBytes, String imageName, String userId) async {
    try {
      final Reference storageRef = _storage.ref().child('profile_pictures/$userId/$imageName');
      final UploadTask uploadTask = storageRef.putData(imageBytes);
      final TaskSnapshot downloadUrl = await uploadTask;
      final String url = await downloadUrl.ref.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint('Error uploading profile picture: $e');
      rethrow;
    }
  }

  Future<void> deleteProfilePicture(String userId) async {
    try {
      // Find the reference to delete
      final ListResult result = await _storage.ref().child('profile_pictures/$userId/').listAll();
      for (final Reference ref in result.items) {
        await ref.delete();
      }

      // Remove the profile picture URL from Firestore
      await _firestore.collection('users').doc(userId).update({
        'profile_picture_url': FieldValue.delete(),
      });
    } catch (e) {
      if (e is FirebaseException && e.code == 'object-not-found') {
        // If file doesn't exist in storage, still ensure it's removed from firestore
        await _firestore.collection('users').doc(userId).update({
          'profile_picture_url': FieldValue.delete(),
        });
      } else {
        debugPrint('Error deleting profile picture: $e');
        rethrow;
      }
    }
  }

  Future<void> updateUserProfile(
      String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update(data);
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      rethrow;
    }
  }
}
