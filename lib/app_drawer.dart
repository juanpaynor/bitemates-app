import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:myapp/auth_notifier.dart';

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
}
