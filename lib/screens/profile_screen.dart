import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const ProfileScreen({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // =================================================
          // PROFILE HEADER
          // =================================================

          Center(
            child: CircleAvatar(
              radius: 45,
              backgroundColor:
                  colorScheme.primaryContainer,
              child: Icon(
                Icons.person,
                size: 50,
                color: colorScheme.primary,
              ),
            ),
          ),

          const SizedBox(height: 15),

          Center(
            child: Text(
  user?.displayName?.isNotEmpty == true
      ? user!.displayName!
      : 'My Account',
  textAlign: TextAlign.center,
  style: TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: colorScheme.onSurface,
  ),
),
          ),

          const SizedBox(height: 6),

          Center(
            child: Text(
              user?.email ?? 'No email available',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          const SizedBox(height: 30),

          // =================================================
          // ACCOUNT INFORMATION
          // =================================================

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.email_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text(
                    'Email',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    user?.email ?? 'Not available',
                  ),
                ),

                const Divider(height: 1),

                ListTile(
                  leading: Icon(
                    Icons.verified_user_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text(
                    'Account status',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    'Authenticated with Firebase',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // =================================================
          // APP INFORMATION
          // =================================================

          Card(
            child: ListTile(
              leading: Icon(
                Icons.task_alt,
                color: colorScheme.primary,
              ),
              title: const Text(
                'Ergobug',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Organize • Remember • Achieve',
              ),
            ),
          ),
        ],
      ),
    );
  }
}