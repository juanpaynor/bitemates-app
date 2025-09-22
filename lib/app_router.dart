import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Corrected import paths
import 'package:myapp/home_screen.dart';
import 'package:myapp/bitemates_login_screen.dart';
import 'package:myapp/matching_screen.dart';
import 'package:myapp/my_group_screen.dart';
import 'package:myapp/quiz_intro_screen.dart';
import 'package:myapp/splash_screen.dart';
import 'package:myapp/main.dart'; // For AuthWrapper

// Centralized GoRouter configuration
final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const AuthWrapper(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const BitematesLoginScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/quiz',
      builder: (context, state) => const QuizIntroScreen(),
    ),
    GoRoute(
      path: '/matching',
      builder: (context, state) => const MatchingScreen(),
    ),
    GoRoute(
      path: '/my-group/:groupId',
      builder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        return MyGroupScreen(groupId: groupId);
      },
    ),
  ],
  redirect: (context, state) {
    final bool loggedIn = FirebaseAuth.instance.currentUser != null;
    final String location = state.uri.toString();

    if (location == '/splash') {
      return null;
    }

    if (!loggedIn && location != '/login') {
      return '/login';
    }

    if (loggedIn && location == '/login') {
      return '/home';
    }

    return null;
  },
);
