import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'lecturer_home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const SplashScreen({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    final user = _auth.currentUser;

    if (user == null) {
      _goToLogin();
      return;
    }

    try {
      final profile = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final role = profile.data()?['role']?.toString().toLowerCase();

      if (!mounted) return;

      if (role == 'lecturer') {
        _goToLecturerHome();
      } else {
        _goToStudentHome();
      }
    } catch (_) {
      // If the profile cannot be read, do not crash the app.
      // Treat the account as a student until the profile is available.
      if (mounted) _goToStudentHome();
    }
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          themeMode: widget.themeMode,
          onThemeChanged: widget.onThemeChanged,
        ),
      ),
    );
  }

  void _goToStudentHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          themeMode: widget.themeMode,
          onThemeChanged: widget.onThemeChanged,
        ),
      ),
    );
  }

  void _goToLecturerHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LecturerHomeScreen(
          themeMode: widget.themeMode,
          onThemeChanged: widget.onThemeChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF210B3A),
              Color(0xFF4B1378),
              Color(0xFF8516C7),
            ],
          ),
        ),
        child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Ergobug',
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Organize • Remember • Achieve',
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white,
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
