import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:lottie/lottie.dart';

class AdditionalInfoScreen extends StatefulWidget {
  const AdditionalInfoScreen({super.key});

  @override
  State<AdditionalInfoScreen> createState() => _AdditionalInfoScreenState();
}

class _AdditionalInfoScreenState extends State<AdditionalInfoScreen> with SingleTickerProviderStateMixin {
  // Form & Controllers
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _bioController = TextEditingController();
  final _ageController = TextEditingController();

  // State
  bool _isLoading = false;
  Uint8List? _profileImageData;
  String? _imageName;
  final ImagePicker _picker = ImagePicker();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Branding
  final Color brandOrange = const Color(0xFFFF6B35);
  final Color brandBlack = const Color(0xFF2B2B2B);
  final Color brandBackground = const Color(0xFFF8F6EF);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _nicknameController.dispose();
    _bioController.dispose();
    _ageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        final imageData = await pickedFile.readAsBytes();
        setState(() {
          _profileImageData = imageData;
          _imageName = pickedFile.name;
        });
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<String?> _uploadProfilePicture(String userId) async {
    if (_profileImageData == null || _imageName == null) return null;
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('$userId/$_imageName');
      
      await storageRef.putData(_profileImageData!);

      return await storageRef.getDownloadURL();
    } catch (e, s) {
      debugPrint('####### FIREBASE STORAGE UPLOAD ERROR #######');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $s');
      debugPrint('###########################################');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading picture: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _saveUserInfo() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    if (_profileImageData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a profile picture.'), backgroundColor: Colors.red),
      );
      return;
    }
    
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("No user signed in.");

      final profilePictureUrl = await _uploadProfilePicture(user.uid);
      if (profilePictureUrl == null) throw Exception("Profile picture failed to upload.");

      final userData = {
        'full_name': _fullNameController.text.trim(),
        'nickname': _nicknameController.text.trim(),
        'bio': _bioController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()) ?? 18,
        'email': user.email,
        'profile_picture_url': profilePictureUrl, // Standardized field name
        'created_at': FieldValue.serverTimestamp(),
        'quiz_completed': false,
        'additional_info_completed': true,
        'personality': {
          'extraversion': 0,
          'chill_factor': 0,
          'openness': 0,
          'interests': [],
          'conversation_style': '',
        },
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userData, SetOptions(merge: true));

      if (mounted) context.go('/quiz');

    } catch (e, s) {
      debugPrint('####### SAVE USER INFO ERROR #######');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $s');
      debugPrint('####################################');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: brandBackground,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _isLoading
            ? _buildLoadingState()
            : CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 150.0,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          color: brandOrange.withOpacity(0.1),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(30),
                            bottomRight: Radius.circular(30),
                          )
                        ),
                      ),
                      title: Text('Create Your Profile', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: brandBlack)),
                      centerTitle: true,
                      titlePadding: const EdgeInsets.only(bottom: 16),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _buildProfileImagePicker(),
                            const SizedBox(height: 30),
                            _buildInputField(_fullNameController, 'Full Name', Icons.person_outline, validator: (v) => v!.isEmpty ? 'Enter your full name' : null),
                            const SizedBox(height: 20),
                            _buildInputField(_nicknameController, 'Nickname', Icons.person_pin_outlined, validator: (v) => v!.isEmpty ? 'Enter a nickname' : null),
                            const SizedBox(height: 20),
                            _buildInputField(_ageController, 'Age', Icons.cake_outlined, keyboardType: TextInputType.number, validator: (v) {
                              if (v!.isEmpty) return 'Enter your age';
                              if ((int.tryParse(v) ?? 0) < 18) return 'You must be 18 or older';
                              return null;
                            }),
                            const SizedBox(height: 20),
                            _buildBioField(),
                            const SizedBox(height: 40),
                            _buildSubmitButton(),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  )
                ],
              ),
      ),
    );
  }

  Widget _buildProfileImagePicker() {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: brandOrange, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            ),
            child: CircleAvatar(
              radius: 65,
              backgroundColor: Colors.grey[200],
              backgroundImage: _profileImageData != null ? MemoryImage(_profileImageData!) : null,
              child: _profileImageData == null
                  ? Icon(Icons.person, size: 70, color: Colors.grey[500])
                  : null,
            ),
          ),
          Positioned(
            bottom: 0,
            right: -10,
            child: GestureDetector(
              onTap: () => _showImagePickerOptions(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: brandBlack,
                  shape: BoxShape.circle,
                  border: Border.all(color: brandBackground, width: 3)
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: brandBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: Icon(Icons.photo_library, color: brandOrange),
              title: Text('From Gallery', style: GoogleFonts.poppins()),
              onTap: () {
                _pickImage(ImageSource.gallery);
                Navigator.of(context).pop();
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.photo_camera, color: brandOrange),
              title: Text('Take a Picture', style: GoogleFonts.poppins()),
              onTap: () {
                _pickImage(ImageSource.camera);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: brandBlack.withOpacity(0.7)),
        prefixIcon: Icon(icon, color: brandOrange),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: brandOrange, width: 2)),
      ),
      validator: validator,
    );
  }

  Widget _buildBioField() {
    return TextFormField(
      controller: _bioController,
      maxLines: 4,
      maxLength: 150,
      style: GoogleFonts.poppins(),
      decoration: InputDecoration(
        labelText: 'Your Bio',
        hintText: 'Something fun and interesting...',
        alignLabelWithHint: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: brandOrange, width: 2)),
      ),
      validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter a bio' : null,
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _saveUserInfo,
      style: ElevatedButton.styleFrom(
        backgroundColor: brandOrange,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 5,
        shadowColor: brandOrange.withOpacity(0.4)
      ),
      child: Text('Save & Continue', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
  
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset('assets/animations/loading.json', width: 200, height: 200),
          const SizedBox(height: 20),
          Text('Saving Your Profile...', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: brandBlack)),
        ],
      ),
    );
  }
}
