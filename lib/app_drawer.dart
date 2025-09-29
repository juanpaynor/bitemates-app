import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:myapp/auth_notifier.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final Color brandOrange = const Color(0xFFFF6B35);
    final Color slightlyLighterOrange = const Color(0xFFFF8A5C);

    return Drawer(
      child: Container(
        color: const Color(0xFF1A1A1A),
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: brandOrange,
              ),
              child: Text(
                'BiteMates',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildListTile(
              icon: Icons.person_outline,
              text: 'Your Profile',
              onTap: () {
                // Close the drawer first
                Navigator.of(context).pop();
                // Navigate to the profile screen
                context.go('/edit-profile');
              },
              color: slightlyLighterOrange,
            ),
            _buildListTile(
              icon: Icons.report_problem_outlined,
              text: 'Report a Problem',
              onTap: () {
                // Close the drawer
                Navigator.of(context).pop();
                // Show a snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thank you for your report!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              color: slightlyLighterOrange,
            ),
            const Divider(color: Colors.grey),
            // Development tools section
            _buildListTile(
              icon: Icons.refresh,
              text: 'Reset Users (Dev)',
              onTap: () async {
                Navigator.of(context).pop();
                await _resetUsersForTesting(context);
              },
              color: Colors.orangeAccent,
            ),
            _buildListTile(
              icon: Icons.group_add,
              text: 'Start Matching (Dev)',
              onTap: () {
                Navigator.of(context).pop();
                context.go('/matching');
              },
              color: Colors.greenAccent,
            ),
            const Divider(color: Colors.grey),
            _buildListTile(
              icon: Icons.logout,
              text: 'Sign Out',
              onTap: () {
                Provider.of<AuthNotifier>(context, listen: false).signOut();
              },
              color: Colors.redAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    required Color color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        text,
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
      ),
      onTap: onTap,
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
