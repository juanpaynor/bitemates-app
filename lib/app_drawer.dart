
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final Color brandOrange = const Color(0xFFFF6B35);
    final Color brandBlack = const Color(0xFF2B2B2B);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: brandOrange,
            ),
            child: Text(
              'Settings',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.edit, color: brandBlack),
            title: Text(
              'Edit Profile',
              style: GoogleFonts.poppins(),
            ),
            onTap: () {
              context.pop(); // Close the drawer
              context.go('/edit-profile');
            },
          ),
          ListTile(
            leading: Icon(Icons.logout, color: brandBlack),
            title: Text(
              'Sign Out',
              style: GoogleFonts.poppins(),
            ),
            onTap: () => _signOut(context),
          ),
        ],
      ),
    );
  }
}
