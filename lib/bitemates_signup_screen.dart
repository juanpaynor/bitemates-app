import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BitematesSignupScreen extends StatefulWidget {
  const BitematesSignupScreen({super.key});

  @override
  State<BitematesSignupScreen> createState() => _BitematesSignupScreenState();
}

class _BitematesSignupScreenState extends State<BitematesSignupScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<AlignmentGeometry> _topAlignmentAnimation;
  late Animation<AlignmentGeometry> _bottomAlignmentAnimation;

  // Define the color scheme as class-level constants
  static const Color primaryOrange = Color(0xFFFF6B35);
  static const Color darkGrey = Color(0xFF2E2E2E);
  static const Color softWhite = Color(0xFFF0F0F0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _topAlignmentAnimation = TweenSequence<AlignmentGeometry>([
      TweenSequenceItem(tween: Tween<AlignmentGeometry>(begin: Alignment.topLeft, end: Alignment.topRight), weight: 1),
      TweenSequenceItem(tween: Tween<AlignmentGeometry>(begin: Alignment.topRight, end: Alignment.bottomRight), weight: 1),
      TweenSequenceItem(tween: Tween<AlignmentGeometry>(begin: Alignment.bottomRight, end: Alignment.bottomLeft), weight: 1),
      TweenSequenceItem(tween: Tween<AlignmentGeometry>(begin: Alignment.bottomLeft, end: Alignment.topLeft), weight: 1),
    ]).animate(_controller);

    _bottomAlignmentAnimation = TweenSequence<AlignmentGeometry>([
      TweenSequenceItem(tween: Tween<AlignmentGeometry>(begin: Alignment.bottomRight, end: Alignment.bottomLeft), weight: 1),
      TweenSequenceItem(tween: Tween<AlignmentGeometry>(begin: Alignment.bottomLeft, end: Alignment.topLeft), weight: 1),
      TweenSequenceItem(tween: Tween<AlignmentGeometry>(begin: Alignment.topLeft, end: Alignment.topRight), weight: 1),
      TweenSequenceItem(tween: Tween<AlignmentGeometry>(begin: Alignment.topRight, end: Alignment.bottomRight), weight: 1),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: _topAlignmentAnimation.value,
                end: _bottomAlignmentAnimation.value,
                colors: const [
                  primaryOrange,
                  Color.fromARGB(255, 255, 128, 77),
                  Color.fromARGB(255, 255, 171, 140),
                ],
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400), // Max width for the sign-up card
                    child: Container(
                      padding: const EdgeInsets.all(30.0),
                      decoration: BoxDecoration(
                        color: softWhite.withAlpha(220), // More white, slight transparency for glassmorphism
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(26),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset('assets/images/logo.png', height: 80),
                          const SizedBox(height: 30),
                          Text(
                            'Create an Account',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: darkGrey, // Use dark grey for text on white background
                            ),
                          ),
                          const SizedBox(height: 30),
                          _buildInputField(
                            hintText: 'Email',
                            icon: Icons.email_outlined,
                            textColor: darkGrey,
                            hintColor: darkGrey.withAlpha(179),
                            borderColor: darkGrey.withAlpha(128),
                            fillColor: Colors.white.withAlpha(128),
                          ),
                          const SizedBox(height: 20),
                          _buildInputField(
                            hintText: 'Password',
                            icon: Icons.lock_outline,
                            obscureText: true,
                            textColor: darkGrey,
                            hintColor: darkGrey.withAlpha(179),
                            borderColor: darkGrey.withAlpha(128),
                            fillColor: Colors.white.withAlpha(128),
                          ),
                          const SizedBox(height: 20),
                          _buildInputField(
                            hintText: 'Confirm Password',
                            icon: Icons.lock_reset,
                            obscureText: true,
                            textColor: darkGrey,
                            hintColor: darkGrey.withAlpha(179),
                            borderColor: darkGrey.withAlpha(128),
                            fillColor: Colors.white.withAlpha(128),
                          ),
                          const SizedBox(height: 30),
                          _buildPrimaryButton(primaryOrange, Colors.white, 'Sign Up', () {}),
                          const SizedBox(height: 15),
                          _buildTextLinkButton('Already have an account? Log In', () { Navigator.pop(context); }, darkGrey),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputField({
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    required Color textColor,
    required Color hintColor,
    required Color borderColor,
    required Color fillColor,
  }) {
    return TextField(
      obscureText: obscureText,
      style: GoogleFonts.poppins(color: textColor),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.poppins(color: hintColor),
        prefixIcon: Icon(icon, color: textColor.withAlpha(204)),
        filled: true,
        fillColor: fillColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryOrange, width: 2.0),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      ),
    );
  }

  Widget _buildPrimaryButton(Color backgroundColor, Color textColor, String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 5,
          textStyle: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          foregroundColor: textColor,
        ),
        child: Text(text),
      ),
    );
  }

  Widget _buildTextLinkButton(String text, VoidCallback onPressed, Color textColor) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: textColor.withAlpha(204),
        textStyle: GoogleFonts.poppins(
          fontSize: 14,
          decoration: TextDecoration.underline,
        ),
      ),
      child: Text(text),
    );
  }
}
