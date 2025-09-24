import 'dart:async';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_functions/cloud_functions.dart';

class ChatScreen extends StatefulWidget {
  final String groupId;
  const ChatScreen({super.key, required this.groupId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final StreamChatClient _client;
  late final Channel _channel;
  late final Future<void> _connectFuture;

  // Your public Stream API Key
  final String _apiKey = '4gk8q5z64nx5';

  @override
  void initState() {
    super.initState();
    _client = StreamChatClient(
      _apiKey, // Use your actual API key here
      logLevel: Level.INFO,
    );

    // The channel is now defined using the groupId passed to the widget
    _channel = _client.channel('messaging', id: widget.groupId);

    // Start the secure connection process for the specific group
    _connectFuture = _connectToGroupChat();
  }

  Future<void> _connectToGroupChat() async {
    try {
      // 1. Get the current Firebase User
      final firebaseUser = fb_auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        throw Exception('User is not authenticated with Firebase.');
      }
      final userId = firebaseUser.uid;

      // 2. Call the new Cloud Function to get a token for the group chat
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('getGroupChatToken');
      final results = await callable.call(<String, dynamic>{
        'groupId': widget.groupId,
      });
      final token = results.data['token'];

      if (token == null) {
          throw Exception('The Stream token received from the backend was null.');
      }

      // 3. Connect the user to Stream using the secure token
      await _client.connectUser(
        User(id: userId), // The user ID must match the one used to generate the token
        token,
      );

      // 4. Watch the channel to start receiving messages
      await _channel.watch();

    } catch (e, st) {
      debugPrint('Error connecting user to group chat: $e');
      debugPrint(st.toString());
      // Re-throw the error to be caught by the FutureBuilder
      rethrow;
    }
  }

  @override
  void dispose() {
    _client.disconnectUser();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Chat'),
        backgroundColor: const Color(0xFFFF6B35),
      ),
      body: FutureBuilder(
        future: _connectFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'An error occurred connecting to the chat. Please try again later.\n\nDetails: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // If connection is successful, show the chat UI
          return StreamChat(
            client: _client,
            child: StreamChannel(
              channel: _channel,
              child: Column(
                children: const <Widget>[
                  Expanded(
                    child: StreamMessageListView(),
                  ),
                  StreamMessageInput(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
