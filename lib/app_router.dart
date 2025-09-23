import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/auth_notifier.dart';
import 'package:myapp/home_screen.dart';
import 'package:myapp/bitemates_login_screen.dart';
import 'package:myapp/bitemates_signup_screen.dart';
import 'package:myapp/additional_info_screen.dart';
import 'package:myapp/edit_profile_screen.dart';
import 'package:myapp/matching_screen.dart';
import 'package:myapp/my_group_screen.dart';
import 'package:myapp/quiz_intro_screen.dart';
import 'package:myapp/quiz_question_screen.dart';
import 'package:myapp/quiz_results_screen.dart';
import 'package:myapp/splash_screen.dart';

class AppRouter {
  final AuthNotifier authNotifier;
  GoRouter? _router;

  AppRouter(this.authNotifier);

  GoRouter get router {
    _router ??= GoRouter(
      initialLocation: '/splash',
      refreshListenable: authNotifier,
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
          path: '/signup',
          builder: (context, state) => const BitematesSignupScreen(),
        ),
        GoRoute(
          path: '/additional-info',
          builder: (context, state) => const AdditionalInfoScreen(),
        ),
        GoRoute(
            path: '/quiz',
            builder: (context, state) => const QuizIntroScreen(),
            routes: [
              GoRoute(
                path: 'question',
                builder: (context, state) => const QuizQuestionScreen(),
              ),
              GoRoute(
                path: 'results',
                builder: (context, state) => const QuizResultsScreen(),
              ),
            ]),
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/edit-profile',
          builder: (context, state) => const EditProfileScreen(),
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
        final location = state.uri.toString();

        final authState = authNotifier.authState;
        final onboardingStatus = authNotifier.onboardingStatus;

        if (authState == AuthState.unknown) {
          return '/splash';
        }

        if (authState == AuthState.unauthenticated) {
          if (location == '/login' || location == '/signup') {
            return null;
          }
          return '/login';
        }

        if (authState == AuthState.authenticated) {
          if (onboardingStatus == OnboardingStatus.needsAdditionalInfo) {
            return '/additional-info';
          }

          if (onboardingStatus == OnboardingStatus.needsQuiz) {
            if (location.startsWith('/quiz')) {
              return null;
            }
            return '/quiz';
          }

          if (onboardingStatus == OnboardingStatus.complete) {
            final isOnboardingRoute = location == '/login' ||
                location == '/signup' ||
                location == '/splash' ||
                location == '/additional-info' ||
                location == '/quiz';

            if (isOnboardingRoute) {
              return '/home';
            }
          }
        }

        return null;
      },
    );
    return _router!;
  }
}
