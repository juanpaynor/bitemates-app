import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:myapp/firebase_options.dart';
import 'package:myapp/app_router.dart';
import 'package:myapp/auth_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final client = StreamChatClient('4gk8q5z64nx5');

  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthNotifier(),
      child: MyApp(client: client),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.client});
  final StreamChatClient client;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return StreamChat(
          client: client,
          child: child!,
        );
      },
      // The navigatorKey is crucial for the router's refreshListenable to work.
      key: navigatorKey,
    );
  }
}
