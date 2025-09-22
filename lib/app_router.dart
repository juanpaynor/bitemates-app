import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/auth_notifier.dart';
import 'package:myapp/home_screen.dart';
import 'package:myapp/bitemates_login_screen.dart';
import 'package:myapp/additional_info_screen.dart';
import 'package:myapp/matching_screen.dart';
import 'package:myapp/my_group_screen.dart';
import 'package:myapp/quiz_intro_screen.dart';
import 'package:myapp/splash_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  refreshListenable: Provider.of<AuthNotifier>(
    // This is a bit of a trick to get the context.
    // We are not actually building a widget here.
    navigatorKey.currentContext!,
    listen: true,
  ),
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
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
      path: '/home',
      builder: (context, state) => const HomeScreen(),
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
  redirect: (BuildContext context, GoRouterState state) {
    final authNotifier = Provider.of<AuthNotifier>(context, listen: false);
    final location = state.uri.toString();

    final authState = authNotifier.authState;
    final onboardingStatus = authNotifier.onboardingStatus;

    if (authState == AuthState.unknown) {
      // While we are figuring out if the user is logged in,
      // show the splash screen.
      return '/splash';
    }

    if (authState == AuthState.unauthenticated) {
      // If the user is not logged in, they can only be on the login screen.
      // Any other attempt will be redirected to /login.
      return location == '/login' ? null : '/login';
    }

    // --- Authenticated User Logic ---
    if (authState == AuthState.authenticated) {
      // If the user is authenticated, check their onboarding status.
      if (onboardingStatus == OnboardingStatus.needsAdditionalInfo) {
        // If they need to fill out additional info, force them to that screen.
        return location == '/additional-info' ? null : '/additional-info';
      }

      if (onboardingStatus == OnboardingStatus.needsQuiz) {
        // If they need to take the quiz, force them to that screen.
        return location == '/quiz' ? null : '/quiz';
      }

      if (onboardingStatus == OnboardingStatus.complete) {
        // If they are fully onboarded and try to visit login, additional-info, or quiz,
        // send them to the home screen.
        if (location == '/login' || location == '/additional-info' || location == '/quiz' || location == '/splash' || location == '/') {
          return '/home';
        }
      }
    }

    // No redirect needed.
    return null;
  },
);

// A global key is needed for the refreshListenable to access the context.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
