import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'lecturer_home_screen.dart';
import 'register_screen.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';

class LoginScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const LoginScreen({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isPasswordObscured = true;
  bool _loggingIn = false;

  Future<String> _getUserRole(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();

    if (!doc.exists) {
      // Older accounts may not have a profile document.
      // Defaulting to student is safer than sending the user to
      // a screen they do not have permission to use.
      return 'student';
    }

    final data = doc.data();
    return data?['role']?.toString().toLowerCase() == 'lecturer'
        ? 'lecturer'
        : 'student';
  }

  Future<void> loginUser() async {
    if (_loggingIn) return;

    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter your email and password.', true);
      return;
    }

    setState(() => _loggingIn = true);

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Unable to identify the logged-in user.');
      }

      final role = await _getUserRole(user.uid);

      if (!mounted) return;

      if (role == 'lecturer') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => LecturerHomeScreen(
              themeMode: widget.themeMode,
              onThemeChanged: widget.onThemeChanged,
            ),
          ),
          (_) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              themeMode: widget.themeMode,
              onThemeChanged: widget.onThemeChanged,
            ),
          ),
          (_) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed.';

      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email.';
          break;
        case 'wrong-password':
          message = 'Incorrect password.';
          break;
        case 'invalid-credential':
          message = 'Invalid email or password.';
          break;
        case 'invalid-email':
          message = 'Invalid email address.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
      }

      if (mounted) _showMessage(message, true);
    } on FirebaseException catch (e) {
      if (mounted) {
        _showMessage('Firebase error: ${e.message ?? e.code}', true);
      }
    } catch (e) {
      if (mounted) {
        _showMessage(
          e.toString().replaceFirst('Exception: ', ''),
          true,
        );
      }
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  Future<void> forgotPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      _showMessage('Enter your email address first.', true);
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      _showMessage('Password reset email sent. Check your inbox.');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      final message = e.code == 'invalid-email'
          ? 'Please enter a valid email address.'
          : 'Unable to send password reset email.';

      _showMessage(message, true);
    }
  }

  void _showMessage(String message, [bool error = false]) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Colors.red : Colors.green,
        ),
      );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 50),
              Image.asset(
                'assets/login_logo.png.png',
                width: 90,
                height: 90,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              Text(
                'Ergobug',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Organize • Remember • Achieve',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 40),
              CustomTextField(
                label: 'Email',
                controller: emailController,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),
              CustomTextField(
                label: 'Password',
                controller: passwordController,
                obscureText: isPasswordObscured,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!_loggingIn) loginUser();
                },
                suffixIcon: IconButton(
                  icon: Icon(
                    isPasswordObscured
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: _loggingIn
                      ? null
                      : () => setState(
                            () => isPasswordObscured = !isPasswordObscured,
                          ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loggingIn ? null : forgotPassword,
                  child: const Text('Forgot Password?'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: _loggingIn ? 'Logging in...' : 'Login',
                  onPressed: _loggingIn ? () {} : loginUser,
                ),
              ),
              const SizedBox(height: 15),
              TextButton(
                onPressed: _loggingIn
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                child: const Text('Create an Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
