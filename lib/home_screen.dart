
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:myapp/app_drawer.dart';
import 'dart:developer' as developer;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  DocumentSnapshot? _userDoc;
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final Map<String, String> _locations = {
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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _initialize();
  }

  Future<void> _initialize() async {
    _user = _auth.currentUser;

    if (_user == null) {
      await Future.delayed(const Duration(milliseconds: 500));
      _user = _auth.currentUser;
      if (_user == null) {
        if (mounted) {
          developer.log('Error: HomeScreen accessed without a logged-in user.', name: 'com.bitemates.auth');
          setState(() => _isLoading = false);
        }
        return;
      }
    }

    await _loadUserData();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      _animationController.forward();
      _checkAndPromptForLocation();
    }
  }

  Future<void> _loadUserData() async {
    if (_user != null) {
      _userDoc = await _firestore.collection('users').doc(_user!.uid).get();
    }
  }

  Future<void> _checkAndPromptForLocation() async {
    if (_userDoc == null || !_userDoc!.exists) return;

    final data = _userDoc!.data() as Map<String, dynamic>?;
    if (data == null || data['sector'] == null || data['sector'] == '') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLocationPrompt();
      });
    }
  }

  void _showLocationPrompt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _LocationSelectionDialog(
          locations: _locations,
          onSave: (selectedLocation, selectedSector) async {
            if (_user != null) {
              await _firestore.collection('users').doc(_user!.uid).update({
                'location': selectedLocation,
                'sector': selectedSector,
              });
              await _loadUserData();
              setState(() {});
              Navigator.of(context).pop();
            }
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(253, 248, 243, 1),
      appBar: AppBar(
        title: Text(
          'Bitemates',
          style: GoogleFonts.pacifico(
            fontSize: 28,
            color: const Color(0xFFDE6A4D),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFFDE6A4D)),
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: 'Open settings',
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFDE6A4D)))
          : _user == null
              ? _buildErrorState()
              : _buildHomeScreenContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 20),
            const Text('Authentication Error', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            const Text('Could not verify user session. Please try logging in again.', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.go('/login'),
              child: const Text('Go to Login'),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildHomeScreenContent() {
    return SafeArea(
      child: AnimationLimiter(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 375),
              childAnimationBuilder: (widget) => SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(child: widget),
              ),
              children: [
                _buildFindGroupButton(),
                const SizedBox(height: 30),
                _buildCurrentGroupSection(),
                const SizedBox(height: 30),
                _buildBottomTabs(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFindGroupButton() {
    // ... same as before
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ElevatedButton.icon(
          onPressed: () {
            context.go('/matching');
          },
          icon: const Icon(Icons.search, size: 28),
          label: Text(
            'Find Your Group',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFFDE6A4D),
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 8,
            shadowColor: const Color(0xFFDE6A4D).withAlpha(102),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentGroupSection() {
    // ... same as before
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Group 🍕',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF4E3D35),
          ),
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(38),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAvatar('https://i.pravatar.cc/150?img=1', 'Alice'),
                  _buildAvatar('https://i.pravatar.cc/150?img=2', 'Bob'),
                  _buildAvatar('https://i.pravatar.cc/150?img=3', 'Charlie'),
                  _buildAvatar('https://i.pravatar.cc/150?img=4', 'Diana'),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.go('/my-group'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: const Color(0xFFDE6A4D),
                  backgroundColor: const Color(0xFFFDF8F3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: const BorderSide(color: Color(0xFFDE6A4D), width: 1.5),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Go to Chat',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(String imageUrl, String name) {
    // ... same as before
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.grey[200],
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            imageBuilder: (context, imageProvider) => CircleAvatar(
              radius: 30,
              backgroundImage: imageProvider,
            ),
            placeholder: (context, url) => const CircularProgressIndicator(),
            errorWidget: (context, url, error) => const Icon(Icons.person, size: 30),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          name,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomTabs() {
    // ... same as before
    return Column(
      children: [
        _buildTabCard(
          icon: Icons.celebration,
          title: 'Explore Events',
          subtitle: 'Community dinners, trivia nights & more',
          color: const Color(0xFF5ABCB9),
          onTap: () => context.go('/restaurants'),
        ),
        const SizedBox(height: 20),
        _buildTabCard(
          icon: Icons.people,
          title: 'Connections',
          subtitle: 'Your saved friends and contacts',
          color: const Color(0xFFF09E54),
        ),
      ],
    );
  }

  Widget _buildTabCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    // ... same as before
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: color.withAlpha(38),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: color.withAlpha(204),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}

class _LocationSelectionDialog extends StatefulWidget {
  final Map<String, String> locations;
  final Function(String, String) onSave;

  const _LocationSelectionDialog({required this.locations, required this.onSave});

  @override
  State<_LocationSelectionDialog> createState() => _LocationSelectionDialogState();
}

class _LocationSelectionDialogState extends State<_LocationSelectionDialog> {
  String? _selectedLocation;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Set Your Location', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This helps us find the best bitemates near you.', style: GoogleFonts.poppins()),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _selectedLocation,
            hint: const Text('Choose your city/area'),
            isExpanded: true,
            onChanged: (value) {
              setState(() {
                _selectedLocation = value;
              });
            },
            items: widget.locations.keys.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _selectedLocation == null ? null : () {
            final selectedSector = widget.locations[_selectedLocation!]!;
            widget.onSave(_selectedLocation!, selectedSector);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
