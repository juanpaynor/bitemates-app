import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/bitemates_signup_screen.dart';
import 'package:provider/provider.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' hide User;

import 'services/chat_service.dart';

class BitematesLoginScreen extends StatefulWidget {
  const BitematesLoginScreen({super.key});

  @override
  State<BitematesLoginScreen> createState() => _BitematesLoginScreenState();
}

class _BitematesLoginScreenState extends State<BitematesLoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  final Color brandOrange = const Color(0xFFFF6B35);
  final Color brandBlack = const Color(0xFF2B2B2B);
  final Color brandBackground = const Color(0xFFF8F6EF);

  Future<void> _handleLoginSuccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return; // Re-check mounted status after await

      String nickname = 'No Nickname';
      String photoUrl = '';

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final nicknameData = data['nickname'];
        if (nicknameData is String) {
          nickname = nicknameData;
        }
        final photoUrlData = data['photoUrl'];
        if (photoUrlData is String) {
          photoUrl = photoUrlData;
        }
      }

      // --- Connect to Stream Chat in the background ---
      final chatClient = Provider.of<StreamChatClient>(context, listen: false);
      final chatService = ChatService(chatClient);
      // No 'await' here. Let it run without blocking the UI.
      chatService.connectUser(user, nickname, photoUrl).catchError((e) {
        developer.log("Background Stream connection failed: $e");
      });
      // --- End background connection ---

      // Navigate immediately based on user data
      if (!mounted) return;
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final additionalInfoCompleted =
            userData['additional_info_completed'] ?? false;
        final quizCompleted = userData['quiz_completed'] ?? false;

        if (!additionalInfoCompleted) {
          context.go('/additional-info');
        } else if (!quizCompleted) {
          context.go('/quiz');
        } else {
          context.go('/home');
        }
      } else {
        context.go('/additional-info');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during login process: $e')),
      );
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      context.go('/login');
    }
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!mounted) return;
      await _handleLoginSuccess();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Login failed')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: brandBackground,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: FadeTransition(
              opacity: _animation,
              child: Column(
                children: [
                  Image.asset('assets/images/logo.png', height: 220),
                  const SizedBox(height: 20),
                  const SizedBox(height: 40),
                  _buildInputField(
                    controller: _emailController,
                    hintText: 'Email Address',
                    icon: Icons.email_outlined,
                  ),
                  const SizedBox(height: 20),
                  _buildInputField(
                    controller: _passwordController,
                    hintText: 'Password',
                    icon: Icons.lock_outline,
                    obscureText: true,
                  ),
                  const SizedBox(height: 30),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : _buildLoginButton(),
                  const SizedBox(height: 15),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'Forgot Password?',
                      style: GoogleFonts.poppins(
                        color: brandOrange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: GoogleFonts.poppins(
                          color: brandBlack.withAlpha(179),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const BitematesSignupScreen()),
                          );
                        },
                        child: Text(
                          'Sign Up',
                          style: GoogleFonts.poppins(
                            color: brandOrange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: GoogleFonts.poppins(color: brandBlack),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.poppins(color: brandBlack.withAlpha(128)),
        prefixIcon: Icon(icon, color: brandOrange),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: brandBlack.withAlpha(26)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: brandOrange, width: 2),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: brandOrange,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 6,
        ),
        child: Text(
          'Login',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
