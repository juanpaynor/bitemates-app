import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MyGroupScreen extends StatelessWidget {
  final String groupId;

  const MyGroupScreen({super.key, required this.groupId});

  final Color brandOrange = const Color(0xFFFF6B35);
  final Color brandBlack = const Color(0xFF2B2B2B);
  final Color brandBackground = const Color(0xFFF8F6EF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: brandBackground,
      appBar: AppBar(
        title: Text(
          'Group Details',
          style: GoogleFonts.poppins(
            color: brandBlack,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: brandBlack),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.group,
                size: 100,
                color: brandOrange.withOpacity(0.8),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome to Your Group!',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: brandBlack,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Group ID: $groupId',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: brandBlack.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'This screen is a placeholder. Functionality for group chat and activities will be added here in the future.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
