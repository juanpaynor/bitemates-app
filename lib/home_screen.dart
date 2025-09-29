import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/auth_notifier.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/app_drawer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  final Color brandOrange = const Color(0xFFFF6B35);
  final Color brandBlack = const Color(0xFF2B2B2B);
  final Color brandBackground = const Color(0xFFF8F6EF);

  @override
  Widget build(BuildContext context) {
    final authNotifier = Provider.of<AuthNotifier>(context);

    final String? nickname = authNotifier.nickname;
    final String? photoUrl = authNotifier.photoUrl;

    return Scaffold(
      backgroundColor: brandBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Dashboard',
          style: GoogleFonts.poppins(
            color: brandBlack,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        iconTheme: IconThemeData(color: brandBlack), // Ensures the drawer icon is visible
      ),
      drawer: const AppDrawer(), // Add the AppDrawer here
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileCard(nickname, photoUrl),
            const SizedBox(height: 40),
            _buildSmartGroupCard(context), // Replaced with smart card
            const SizedBox(height: 20),
            // Development Reset Button
            _buildDevResetButton(context),
            const SizedBox(height: 40),
            _buildHistorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(String? nickname, String? photoUrl) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: brandOrange.withOpacity(0.2),
            backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                ? NetworkImage(photoUrl)
                : null,
            child: photoUrl == null || photoUrl.isEmpty
                ? const Icon(Icons.person, size: 40, color: Color(0xFFFF6B35),)
                : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: GoogleFonts.poppins(
                    color: brandBlack.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
                Text(
                  nickname ?? 'Bitemate',
                  style: GoogleFonts.poppins(
                    color: brandBlack,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartGroupCard(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink(); // Should not happen if user is logged in

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final String? groupId = userData?['groupId'];
        final bool hasGroup = groupId != null && groupId.isNotEmpty;

        return InkWell(
          onTap: () {
            if (hasGroup) {
              context.go('/my-group/$groupId');
            } else {
              context.go('/matching');
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [brandOrange, brandOrange.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: brandOrange.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(hasGroup ? Icons.chat_bubble_outline : Icons.group_add, color: Colors.white, size: 40),
                const SizedBox(height: 15),
                Text(
                  hasGroup ? 'Go to Group Chat' : 'Find Your Bitemates',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  hasGroup ? 'Continue the conversation with your foodie friends.' : 'Start the matching process and meet your new foodie friends.',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Matches',
          style: GoogleFonts.poppins(
            color: brandBlack,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.history,
                  color: Colors.grey.shade400,
                  size: 50,
                ),
                const SizedBox(height: 15),
                Text(
                  'No match history yet',
                  style: GoogleFonts.poppins(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDevResetButton(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: brandOrange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bug_report, color: brandOrange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Development Tools',
                style: GoogleFonts.poppins(
                  color: brandOrange,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _resetUsersForTesting(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Reset All Users',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.go('/matching'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Start Matching',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _resetUsersForTesting(BuildContext context) async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('resetUsersForTesting');
      
      // Show loading
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resetting users for testing...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      final result = await callable.call();
      final data = result.data;
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reset complete! ${data['usersReset']} users reset, ${data['groupsDeleted']} groups deleted.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting users: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
