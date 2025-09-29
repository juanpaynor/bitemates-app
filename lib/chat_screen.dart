import 'dart:async';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatScreen extends StatefulWidget {
  final String groupId;
  const ChatScreen({super.key, required this.groupId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  StreamChatClient? _client;
  Channel? _channel;
  late final Future<void> _connectFuture;
  late final Future<String> _groupMembersFuture;

  @override
  void initState() {
    super.initState();
    // Initialize client without API key - will get it from backend
    _connectFuture = _initializeChat();
    _groupMembersFuture = _getGroupMembers();
  }

  Future<void> _initializeChat() async {
    try {
      final firebaseUser = fb_auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        throw Exception('User is not authenticated with Firebase.');
      }
      final userId = firebaseUser.uid;

      debugPrint('🔵 Starting chat initialization for user: $userId, group: ${widget.groupId}');

      // Get Stream Chat token and API key from backend
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('getGroupChatToken');
      
      debugPrint('🔵 Calling getGroupChatToken function...');
      
      final results = await callable.call(<String, dynamic>{
        'groupId': widget.groupId,
      });
      
      debugPrint('🟢 Function call successful: ${results.data}');
      
      final token = results.data['token'];
      final apiKey = results.data['apiKey'];
      
      if (token == null || apiKey == null) {
        throw Exception('Failed to get Stream Chat credentials from backend.');
      }

      debugPrint('🔵 Got credentials - API Key: $apiKey, Token length: ${token.length}');

      // Initialize client with API key from backend  
      _client = StreamChatClient(
        apiKey, 
        logLevel: Level.INFO,
      );

      debugPrint('🔵 Connecting user to Stream Chat...');

      // Create user object with more details
      final user = User(
        id: userId,
        name: firebaseUser.displayName ?? firebaseUser.email ?? 'User',
        image: firebaseUser.photoURL,
      );

      await _client!.connectUser(user, token);
      debugPrint('🟢 User connected successfully');

      // Initialize channel
      _channel = _client!.channel(
        'messaging', 
        id: widget.groupId,
        extraData: {
          'name': 'BiteMates Chat',
          'image': 'https://bit.ly/2TIt8NR',
        },
      );

      debugPrint('🔵 Watching channel...');
      await _channel!.watch();
      debugPrint('🟢 Channel watch successful');

    } catch (e, st) {
      debugPrint('🔴 Error connecting user to group chat: $e');
      debugPrint('🔴 Stack trace: $st');
      rethrow;
    }
  }
  
    Future<String> _getGroupMembers() async {
    try {
      final groupDoc = await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).get();
      final memberIds = List<String>.from(groupDoc.data()?['members'] ?? []);

      if (memberIds.isEmpty) {
        return "Group Members";
      }

      final memberNicknames = <String>[];
      for (String memberId in memberIds) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(memberId).get();
        final nickname = userDoc.data()?['nickname'] as String? ?? 'Unknown';
        memberNicknames.add(nickname);
      }

      return memberNicknames.join(', ');
    } catch (e) {
      debugPrint('Error getting group members: $e');
      return "Group Chat";
    }
  }


  @override
  void dispose() {
    _client?.disconnectUser();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<String>(
          future: _groupMembersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text('Loading...');
            }
            if (snapshot.hasError) {
              return const Text('Group Chat');
            }
            return Text(snapshot.data ?? 'Group Chat', overflow: TextOverflow.ellipsis);
          },
        ),
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder(
        future: _connectFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                  ),
                  SizedBox(height: 20),
                  Text('Connecting to chat...'),
                  SizedBox(height: 10),
                  Text(
                    'Setting up your group chat securely',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Chat Connection Error',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Unable to connect to the chat.\n\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Successfully connected - show chat
          return StreamChat(
            client: _client!,
            child: StreamChannel(
              channel: _channel!,
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
