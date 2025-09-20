
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';

import 'additional_info_screen.dart';
import 'bitemates_login_screen.dart';
import 'home_screen.dart';
import 'matching_screen.dart';
import 'quiz_intro_screen.dart';
import 'quiz_question_screen.dart';
import 'quiz_results_screen.dart';
import 'quiz_state.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await precacheLottieAnimation();
  runApp(
    ChangeNotifierProvider(
      create: (context) => QuizState(),
      child: const MyApp(),
    ),
  );
}

Future<void> precacheLottieAnimation() async {
  final assetData = await rootBundle.load('assets/animations/searching_for_profile.json');
  await LottieComposition.fromByteData(assetData);
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AuthWrapper(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const BitematesLoginScreen(),
    ),
    GoRoute(
      path: '/additional-info',
      builder: (context, state) => const AdditionalInfoScreen(),
    ),
    GoRoute(
      path: '/quiz',
      builder: (context, state) => const QuizIntroScreen(),
    ),
    GoRoute(
      path: '/quiz/question',
      builder: (context, state) => const QuizQuestionScreen(),
    ),
    GoRoute(
      path: '/quiz/results',
      builder: (context, state) => const QuizResultsScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/matching',
      builder: (context, state) => const MatchingScreen(),
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      title: 'Bitemates App',
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authSnapshot.hasData) {
          // User is logged in, check Firestore for quiz completion
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(authSnapshot.data!.uid).get(),
            builder: (context, userDocSnapshot) {
              if (userDocSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (userDocSnapshot.hasData && userDocSnapshot.data!.exists) {
                final userData = userDocSnapshot.data!.data() as Map<String, dynamic>;
                final additionalInfoCompleted = userData['additional_info_completed'] ?? false;
                final quizCompleted = userData['quiz_completed'] ?? false;
                
                if (!additionalInfoCompleted) {
                  return const AdditionalInfoScreen();
                } else if (!quizCompleted) {
                  return const QuizIntroScreen();
                } else {
                  return const HomeScreen();
                }
              }
              // If user document doesn't exist, treat as if additional info is not completed.
              return const AdditionalInfoScreen();
            },
          );
        } else {
          // User is not logged in
          return const BitematesLoginScreen();
        }
      },
    );
  }
}
