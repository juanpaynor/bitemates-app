
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class MyGroupScreen extends StatefulWidget {
  const MyGroupScreen({super.key});

  @override
  _MyGroupScreenState createState() => _MyGroupScreenState();
}

class _MyGroupScreenState extends State<MyGroupScreen> {
  Stream<DocumentSnapshot>? _groupStream;
  String? _groupId;

  @override
  void initState() {
    super.initState();
    _fetchUserGroup();
  }

  void _fetchUserGroup() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('groups')
          .where('user_ids', arrayContains: user.uid)
          .limit(1)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final groupDoc = snapshot.docs.first;
          setState(() {
            _groupId = groupDoc.id;
            _groupStream = groupDoc.reference.snapshots();
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Group', style: GoogleFonts.poppins()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _groupStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text("You are not in a group yet."));
          }

          final groupData = snapshot.data!.data() as Map<String, dynamic>;
          final userIds = List<String>.from(groupData['user_ids'] ?? []);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Group Members',
                  style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: userIds.length,
                  itemBuilder: (context, index) {
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(userIds[index]).get(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData) {
                          return const ListTile(title: Text('Loading...'));
                        }
                        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(userData['photoUrl'] ?? 'https://via.placeholder.com/150'),
                          ),
                          title: Text(userData['nickname'] ?? 'No Nickname'),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: () {
                    if (_groupId != null) {
                      context.go('/chat/$_groupId');
                    }
                  },
                  child: const Text('Go to Chat'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
