import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:student_task_manager/widgets/custom_button.dart';
import 'package:student_task_manager/widgets/custom_textfield.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController matricController = TextEditingController();

  bool isPasswordObscured = true;
  bool _saving = false;
  String _role = 'student';

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    matricController.dispose();
    super.dispose();
  }

  Future<void> registerUser() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final matric = matricController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _message('Please fill in all required fields.', true);
      return;
    }

    if (_role == 'student' && matric.isEmpty) {
      _message('Enter your matric number.', true);
      return;
    }

    setState(() => _saving = true);

    User? user;

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      user = credential.user;
      if (user == null) throw Exception('Account could not be created.');

      await user.updateDisplayName(name);
      await user.reload();
      user = _auth.currentUser;

      await _firestore.collection('users').doc(user!.uid).set({
        'name': name,
        'email': email,
        'role': _role,
        'matricNumber': _role == 'student' ? matric : '',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _auth.signOut();

      if (!mounted) return;
      _message('Registration successful. You can now log in.');
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String message = 'Registration failed.';

      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered.';
          break;
        case 'weak-password':
          message = 'Password should be at least 6 characters.';
          break;
        case 'invalid-email':
          message = 'Invalid email address.';
          break;
      }

      if (mounted) _message(message, true);
    } catch (e) {
      if (mounted) {
        _message(e.toString().replaceFirst('Exception: ', ''), true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text, [bool error = false]) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Colors.red : Colors.green,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Icon(Icons.person_add_alt_1, size: 90, color: colors.primary),
              const SizedBox(height: 20),
              Text(
                'Join Ergobug',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 35),
              CustomTextField(label: 'Full Name', controller: nameController),
              const SizedBox(height: 18),
              CustomTextField(label: 'Email', controller: emailController),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(
                  labelText: 'Account Type',
                  prefixIcon: Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'student',
                    child: Text('Student'),
                  ),
                  DropdownMenuItem(
                    value: 'lecturer',
                    child: Text('Lecturer'),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) setState(() => _role = value);
                      },
              ),
              const SizedBox(height: 18),
              if (_role == 'student') ...[
                CustomTextField(
                  label: 'Matric Number',
                  controller: matricController,
                ),
                const SizedBox(height: 18),
              ],
              CustomTextField(
                label: 'Password',
                controller: passwordController,
                obscureText: isPasswordObscured,
                suffixIcon: IconButton(
                  icon: Icon(
                    isPasswordObscured ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(
                    () => isPasswordObscured = !isPasswordObscured,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: _saving ? 'Creating Account...' : 'Create Account',
                  onPressed: _saving
                      ? () {}
                      : () {
                          registerUser();
                        },
                ),
              ),
              const SizedBox(height: 18),
              TextButton(
                onPressed: _saving
                    ? () {}
                    : () => Navigator.pop(context),
                child: Text(
                  'Already have an account? Login',
                  style: TextStyle(color: colors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
