
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myapp/user_service.dart';
import 'package:lottie/lottie.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // Form & Controllers
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _bioController = TextEditingController();
  final _ageController = TextEditingController();

  // State
  bool _isLoading = true;
  String? _profileImageUrl;
  Uint8List? _imageBytes;
  String? _imageName;
  String? _selectedLocation;

  // Services & Data
  final UserService _userService = UserService();
  final ImagePicker _picker = ImagePicker();
  final Map<String, String> _locations = const {
    'Muntinlupa/Alabang': 'southies',
    'Las Pinas': 'southies',
    'Paranaque': 'southies',
    'Pasay': 'middle',
    'Makati': 'middle',
    'Manila': 'middle',
    'Taguig': 'middle',
    'Mandaluyong': 'middle',
    'Pasig': 'middle',
    'San Juan': 'middle',
    'Quezon City': 'northies',
    'Marikina': 'northies',
    'South Caloocan': 'northies',
    'Navotas': 'northies',
    'Malabon': 'northies',
    'Valenzuela': 'northies',
    'North Caloocan': 'northies',
  };

  // Branding
  final Color brandOrange = const Color(0xFFFF6B35);
  final Color brandBlack = const Color(0xFF2B2B2B);
  final Color brandBackground = const Color(0xFFF8F6EF);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists && mounted) {
          final data = userDoc.data()!;
          setState(() {
            _nicknameController.text = data['nickname'] ?? '';
            _bioController.text = data['bio'] ?? '';
            _ageController.text = data['age']?.toString() ?? '';
            _profileImageUrl = data['profile_picture_url'];
            _selectedLocation = data['location'];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String? newImageUrl = _profileImageUrl;
        if (_imageBytes != null && _imageName != null) {
          newImageUrl = await _userService.uploadProfilePicture(_imageBytes!, _imageName!, user.uid);
        }

        final Map<String, dynamic> dataToUpdate = {
          'nickname': _nicknameController.text.trim(),
          'bio': _bioController.text.trim(),
          'age': int.tryParse(_ageController.text.trim()),
          'location': _selectedLocation,
          'sector': _locations[_selectedLocation!],
          if (newImageUrl != null) 'profile_picture_url': newImageUrl,
        };

        await _userService.updateUserProfile(user.uid, dataToUpdate);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
          );
          setState(() {
            _profileImageUrl = newImageUrl;
            _imageBytes = null;
            _imageName = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 800);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imageName = pickedFile.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: brandBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: Text('Edit Profile', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: brandBlack)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: brandBlack),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildProfileImagePicker(),
                    const SizedBox(height: 30),
                    _buildInputField(_nicknameController, 'Nickname', Icons.person_pin_outlined, validator: (v) => v!.isEmpty ? 'Enter a nickname' : null),
                    const SizedBox(height: 20),
                    _buildInputField(_ageController, 'Age', Icons.cake_outlined, keyboardType: TextInputType.number, validator: (v) {
                      if (v!.isEmpty) return 'Enter your age';
                      if ((int.tryParse(v) ?? 0) < 18) return 'You must be 18 or older';
                      return null;
                    }),
                    const SizedBox(height: 20),
                    _buildLocationDropdown(),
                    const SizedBox(height: 20),
                    _buildBioField(),
                    const SizedBox(height: 40),
                    _buildSubmitButton('Save Changes', _updateProfile, brandOrange),
                    const SizedBox(height: 15),
                    _buildSubmitButton('Retake Personality Quiz', () => context.go('/quiz'), brandBlack.withOpacity(0.8)),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildLocationDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedLocation,
      hint: const Text('Choose your city/area'),
      isExpanded: true,
      onChanged: (value) {
        setState(() {
          _selectedLocation = value;
        });
      },
      items: _locations.keys.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      decoration: InputDecoration(
        labelText: 'Location',
        labelStyle: GoogleFonts.poppins(color: brandBlack.withOpacity(0.7)),
        prefixIcon: Icon(Icons.location_on_outlined, color: brandOrange),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: brandOrange, width: 2)),
      ),
      validator: (value) => value == null || value.isEmpty ? 'Please select your location' : null,
    );
  }

  // ... other build methods like _buildProfileImagePicker, _buildInputField etc. remain the same


  Widget _buildProfileImagePicker() {
    ImageProvider? backgroundImage;
    if (_imageBytes != null) {
      backgroundImage = MemoryImage(_imageBytes!);
    } else if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      backgroundImage = NetworkImage(_profileImageUrl!);
    }

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: brandOrange, width: 4),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))]
            ),
            child: CircleAvatar(
              radius: 65,
              backgroundColor: Colors.grey[200],
              backgroundImage: backgroundImage,
              child: (backgroundImage == null)
                  ? Icon(Icons.person, size: 70, color: Colors.grey[500])
                  : null,
            ),
          ),
          Positioned(
            bottom: 0,
            right: -10,
            child: Row(
              children: [
                 _buildPickerIconButton(Icons.edit, () => _showImagePickerOptions()),
                 if (_profileImageUrl != null || _imageBytes != null) 
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: _buildPickerIconButton(Icons.delete, () {}, color: Colors.red.shade700),
                  ),
              ],
            )
          ),
        ],
      ),
    );
  }
  
  Widget _buildPickerIconButton(IconData icon, VoidCallback onPressed, {Color? color}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color ?? brandBlack,
          shape: BoxShape.circle,
          border: Border.all(color: brandBackground, width: 3)
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: brandBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(leading: Icon(Icons.photo_library, color: brandOrange), title: Text('From Gallery', style: GoogleFonts.poppins()), onTap: () { _pickImage(ImageSource.gallery); Navigator.of(context).pop(); }),
            const Divider(),
            ListTile(leading: Icon(Icons.photo_camera, color: brandOrange), title: Text('Take a Picture', style: GoogleFonts.poppins()), onTap: () { _pickImage(ImageSource.camera); Navigator.of(context).pop(); }),
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

  Widget _buildSubmitButton(String text, VoidCallback onPressed, Color color) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 5,
        shadowColor: color.withOpacity(0.4)
      ),
      child: Text(text, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
  
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset('assets/animations/Loading.json', width: 200, height: 200),
          const SizedBox(height: 20),
          Text('Please Wait...', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: brandBlack)),
        ],
      ),
    );
  }

}
