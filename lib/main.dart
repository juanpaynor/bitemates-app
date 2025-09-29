import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_app_check/firebase_app_check.dart'; // Disabled temporarily
import 'package:myapp/auth_notifier.dart';
import 'package:myapp/firebase_options.dart';
import 'package:myapp/app_router.dart';
import 'package:myapp/quiz_state.dart';
import 'package:myapp/theme_provider.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Temporarily disable App Check to fix ReCAPTCHA errors
  // TODO: Configure proper reCAPTCHA keys for production
  // await FirebaseAppCheck.instance.activate(
  //   webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
  //   androidProvider: AndroidProvider.debug,
  // );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthNotifier()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => QuizState()),
      ],
      child: Builder(
        builder: (context) {
          final authNotifier = Provider.of<AuthNotifier>(context);
          final appRouter = AppRouter(authNotifier);
          final themeProvider = Provider.of<ThemeProvider>(context);

          return MaterialApp.router(
            title: 'BiteMates',
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            routerConfig: appRouter.router,
          );
        },
      ),
    );
  }
}
