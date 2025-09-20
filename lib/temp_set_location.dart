
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;
  final userId = "YdIqpfutffSk2rvBFASwgOeBa6X2";
  final latitude = 14.463730349296675;
  final longitude = 121.02464410027257;

  await firestore.collection('user_locations').doc(userId).set({
    'latitude': latitude,
    'longitude': longitude,
    'timestamp': FieldValue.serverTimestamp(),
  });

  print("Location for user $userId has been updated.");
}
