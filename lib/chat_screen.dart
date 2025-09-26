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
  late final StreamChatClient _client;
  late final Channel _channel;
  late final Future<void> _connectFuture;
  late final Future<String> _groupMembersFuture;

  // Your public Stream API Key
  final String _apiKey = '4gk8q5z64nx5';

  @override
  void initState() {
    super.initState();
    _client = StreamChatClient(
      _apiKey, // Use your actual API key here
      logLevel: Level.INFO,
    );

    _channel = _client.channel('messaging', id: widget.groupId);

    _connectFuture = _connectToGroupChat();
    _groupMembersFuture = _getGroupMembers();
  }

  Future<void> _connectToGroupChat() async {
    try {
      final firebaseUser = fb_auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        throw Exception('User is not authenticated with Firebase.');
      }
      final userId = firebaseUser.uid;

      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('getGroupChatToken');
      final results = await callable.call(<String, dynamic>{
        'groupId': widget.groupId,
      });
      final token = results.data['token'];

      if (token == null) {
          throw Exception('The Stream token received from the backend was null.');
      }

      await _client.connectUser(
        User(id: userId),
        token,
      );

      await _channel.watch();

    } catch (e, st) {
      debugPrint('Error connecting user to group chat: $e');
      debugPrint(st.toString());
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
    _client.disconnectUser();
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
