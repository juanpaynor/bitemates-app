import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fba;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:myapp/firebase_options.dart';
import 'package:myapp/app_router.dart';
import 'dart:developer' as developer;

import 'package:myapp/bitemates_login_screen.dart';
import 'package:myapp/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final client = StreamChatClient('4gk8q5z64nx5');

  runApp(MyApp(client: client));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.client});
  final StreamChatClient client;

  @override
  Widget build(BuildContext context) {
    // The MaterialApp.router MUST be the root widget.
    return MaterialApp.router(
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      // The builder ensures StreamChat is a child of MaterialApp,
      // giving it the required Localizations context.
      builder: (context, child) {
        return StreamChat(
          client: client,
          child: child!,
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Future<void> _connectStreamUser(fba.User user) async {
    final client = StreamChat.of(context).client;
    if (client.state.currentUser != null && client.state.currentUser?.id == user.uid) {
      developer.log('User ${user.uid} is already connected to Stream.', name: 'com.bitemates.stream');
      return;
    }

    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('getStreamUserToken');
      final result = await callable.call();
      final token = result.data['token'];

      await client.connectUser(
        User(id: user.uid),
        token,
      );
      developer.log('User successfully connected to Stream.', name: 'com.bitemates.stream');
    } catch (e) {
      developer.log('Error connecting to Stream: $e', name: 'com.bitemates.stream.error');
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not connect to chat. Please try again later.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<fba.User?>(
      stream: fba.FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snapshot.data;
        if (user != null) {
          _connectStreamUser(user);
          return const HomeScreen();
        } else {
          // It's important to disconnect the user from Stream when they log out.
          StreamChat.of(context).client.disconnectUser();
          return const BitematesLoginScreen();
        }
      },
    );
  }
}
