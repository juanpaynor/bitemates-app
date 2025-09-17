import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BitematesLoginScreen extends StatefulWidget {
  const BitematesLoginScreen({super.key});

  @override
  State<BitematesLoginScreen> createState() => _BitematesLoginScreenState();
}

class _BitematesLoginScreenState extends State<BitematesLoginScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<AlignmentGeometry> _topAlignmentAnimation;
  late Animation<AlignmentGeometry> _bottomAlignmentAnimation;

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
    // Define the color scheme
    const Color primaryOrange = Color(0xFFFF6B35);
    const Color darkGrey = Color(0xFF2E2E2E);
    const Color whiteBackground = Colors.white;

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
                    constraints: const BoxConstraints(maxWidth: 400), // Max width for the login card
                    child: Container(
                      padding: const EdgeInsets.all(30.0),
                      decoration: BoxDecoration(
                        color: whiteBackground.withOpacity(0.1), // Slight transparency for glassmorphism
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Bitemates Login',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: whiteBackground,
                            ),
                          ),
                          const SizedBox(height: 30),
                          _buildInputField(
                            hintText: 'Email',
                            icon: Icons.email_outlined,
                            textColor: whiteBackground,
                            hintColor: whiteBackground.withOpacity(0.7),
                            borderColor: whiteBackground.withOpacity(0.5),
                            fillColor: darkGrey.withOpacity(0.5),
                          ),
                          const SizedBox(height: 20),
                          _buildInputField(
                            hintText: 'Password',
                            icon: Icons.lock_outline,
                            obscureText: true,
                            textColor: whiteBackground,
                            hintColor: whiteBackground.withOpacity(0.7),
                            borderColor: whiteBackground.withOpacity(0.5),
                            fillColor: darkGrey.withOpacity(0.5),
                          ),
                          const SizedBox(height: 30),
                          _buildLoginButton(primaryOrange, whiteBackground),
                          const SizedBox(height: 15),
                          _buildTextLinkButton('Forgot Password?', () {}, whiteBackground),
                          const SizedBox(height: 25),
                          Text(
                            'Don't have an account?',
                            style: GoogleFonts.poppins(
                              color: whiteBackground.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildSignUpButton(darkGrey, whiteBackground),
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
        prefixIcon: Icon(icon, color: textColor.withOpacity(0.8)),
        filled: true,
        fillColor: fillColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white, width: 2.0),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      ),
    );
  }

  Widget _buildLoginButton(Color backgroundColor, Color textColor) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {},
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
          foregroundColor: textColor, // Text color
        ),
        child: const Text('Login'),
      ),
    );
  }

  Widget _buildSignUpButton(Color backgroundColor, Color textColor) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: textColor.withOpacity(0.7), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          foregroundColor: textColor, // Text color
        ),
        child: const Text('Sign Up'),
      ),
    );
  }

  Widget _buildTextLinkButton(String text, VoidCallback onPressed, Color textColor) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: textColor.withOpacity(0.8), // Text color
        textStyle: GoogleFonts.poppins(
          fontSize: 14,
          decoration: TextDecoration.underline,
        ),
      ),
      child: Text(text),
    );
  }
}
