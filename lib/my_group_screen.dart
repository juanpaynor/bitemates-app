import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'dart:developer' as developer;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fba;

class MyGroupScreen extends StatefulWidget {
  final String groupId;
  const MyGroupScreen({super.key, required this.groupId});

  @override
  _MyGroupScreenState createState() => _MyGroupScreenState();
}

class _MyGroupScreenState extends State<MyGroupScreen> {
  List<Map<String, dynamic>> _groupMembers = [];
  bool _isLoading = true;
  String? _channelId;
  String? _groupStatus;
  bool _isStayAndDineInProgress = false;
  final _currentUser = fba.FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _fetchGroupAndMembersData();
  }

  Future<void> _fetchGroupAndMembersData() async {
    try {
      final groupDoc = await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).get();

      if (!groupDoc.exists) {
        developer.log('Group document with ID ${widget.groupId} not found.', name: 'com.bitemates.firestore');
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      
      final groupData = groupDoc.data() as Map<String, dynamic>;
      final userIds = List<String>.from(groupData['user_ids'] ?? []);
      _channelId = groupData['channel_id'];
      _groupStatus = groupData['status'];

      if (userIds.isNotEmpty) {
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: userIds)
            .get();
        _groupMembers = usersSnapshot.docs.map((doc) => {'uid': doc.id, ...doc.data()}).toList();
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      developer.log('Error fetching group data: $e', name: 'com.bitemates.error');
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _stayAndDine() async {
    if (_isStayAndDineInProgress) return;
    setState(() => _isStayAndDineInProgress = true);

    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('stayAndDine');
      final result = await callable.call({'groupId': widget.groupId});

      final status = result.data['status'];
      if (status == 'dinner_planned') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A dinner has been planned!'), backgroundColor: Colors.green),
        );
        _fetchGroupAndMembersData();
      } else if (status == 'waiting_for_more') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have opted to stay. Waiting for more members.'), backgroundColor: Colors.blue),
        );
      }
    } catch (e) {
      developer.log('Error with stayAndDine: $e', name: 'com.bitemates.error');
    } finally {
      if(mounted) setState(() => _isStayAndDineInProgress = false);
    }
  }
  
  Future<void> _addConnection(String otherUserId) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('addConnection');
      await callable.call({'otherUserId': otherUserId});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection added!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      developer.log('Error adding connection: $e', name: 'com.bitemates.error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFF7F2F0),
      appBar: AppBar(
        title: Text('My Bitemates Group', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFFDE6A4D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Column(
        children: [
          _buildMembersHeader(),
          Expanded(
            child: _channelId == null ? _buildNoChatUI() : _buildStreamChat(),
          ),
          if (_groupStatus != 'dinner_planned') _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildMembersHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      decoration: const BoxDecoration(
        color: Color(0xFFDE6A4D),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _groupMembers.length,
          itemBuilder: (context, index) {
            final member = _groupMembers[index];
            final isCurrentUser = member['uid'] == _currentUser?.uid;
            final streamUser = User(
              id: member['uid'], 
              extraData: {
                'image': member['profile_picture_url'], 
                'name': member['name']
              });

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  StreamUserAvatar(
                    user: streamUser, 
                    constraints: const BoxConstraints.tightFor(width: 70, height: 70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    member['name'] ?? 'Unknown User',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
                  ),
                   if (_groupStatus == 'dinner_planned' && !isCurrentUser)
                    SizedBox(
                      height: 24,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.person_add, color: Colors.white70, size: 20),
                        onPressed: () => _addConnection(member['uid']),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStreamChat() {
    final client = StreamChat.of(context).client;
    return StreamChatTheme(
      data: StreamChatThemeData(
        messageInputTheme: StreamMessageInputThemeData(
          inputDecoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(30)),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            hintText: 'Type your message...',
            hintStyle: GoogleFonts.poppins(),
          ),
        ),
      ),
      child: StreamChannel(
        channel: client.channel('messaging', id: _channelId),
        child: Column(
          children: [
            Expanded(
              child: StreamMessageListView(
                messageBuilder: (context, details, messages, defaultMessageWidget) {
                  final message = details.message;
                  final isMyMessage = message.user?.id == client.state.currentUser?.id;

                  final borderRadius = BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: isMyMessage ? const Radius.circular(20) : Radius.zero,
                    bottomRight: isMyMessage ? Radius.zero : const Radius.circular(20),
                  );

                  return Container(
                    decoration: BoxDecoration(
                      color: isMyMessage ? const Color(0xFFDE6A4D) : Colors.white,
                      borderRadius: borderRadius,
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: defaultMessageWidget.copyWith(
                      messageTheme: StreamMessageThemeData(
                        messageTextStyle: GoogleFonts.poppins(
                          color: isMyMessage ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const StreamMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildNoChatUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          "Chat channel for this group is not available.",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }
  
  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            spreadRadius: 0,
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed: () => context.go('/home'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.black87,
              backgroundColor: Colors.grey[200],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              elevation: 0,
            ),
            child: Text('Skip Chat', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: (_groupMembers.length < 2 || _isStayAndDineInProgress) ? null : _stayAndDine,
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFFDE6A4D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              elevation: 2,
            ),
            child: _isStayAndDineInProgress
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text('Stay', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
