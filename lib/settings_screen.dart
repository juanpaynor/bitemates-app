
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color brandOrange = const Color(0xFFFF6B35);
    final Color brandBlack = const Color(0xFF2B2B2B);

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: brandBlack,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF8F6EF),
      body: ListView(
        children: [
          _buildSectionHeader('Account'),
          _buildSettingsItem(
            context,
            icon: Icons.person_outline,
            title: 'Edit Profile',
            onTap: () => context.push('/edit-profile'),
          ),
          _buildSettingsItem(
            context,
            icon: Icons.logout,
            title: 'Sign Out',
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              context.go('/login');
            },
          ),
          _buildSectionHeader('Support'),
          _buildSettingsItem(
            context,
            icon: Icons.support_agent,
            title: 'Contact Support',
            onTap: () {
              // Placeholder for contacting support
            },
          ),
          _buildSectionHeader('General'),
          _buildSettingsItem(
            context,
            icon: Icons.settings_outlined,
            title: 'General Settings',
            onTap: () {
              // Placeholder for general settings
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF2B2B2B)),
      ),
    );
  }

  Widget _buildSettingsItem(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFFF6B35)),
      title: Text(title, style: GoogleFonts.poppins()),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}
