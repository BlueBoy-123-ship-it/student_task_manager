import 'package:student_task_manager/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
class SettingsScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<SettingsScreen> createState() =>
      _SettingsScreenState();
}

class _SettingsScreenState
    extends State<SettingsScreen> {
  late ThemeMode _selectedTheme;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  @override
  void initState() {
    super.initState();

    _selectedTheme = widget.themeMode;
  }

  // =========================================================
  // THEME NAME
  // =========================================================

  String _themeName() {
    switch (_selectedTheme) {
      case ThemeMode.light:
        return 'Light';

      case ThemeMode.dark:
        return 'Dark';

      case ThemeMode.system:
        return 'System Default';
    }
  }

  // =========================================================
  // CHANGE THEME
  // =========================================================

  void _changeTheme(ThemeMode mode) {
    setState(() {
      _selectedTheme = mode;
    });

    widget.onThemeChanged(mode);
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = _auth.currentUser;
    final String displayName =
        user?.displayName?.trim().isNotEmpty == true
            ? user!.displayName!.trim()
            : 'User';
    final String email = user?.email ?? 'No email available';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),

        children: [
          // =================================================
          // ACCOUNT
          // =================================================

          Text(
            'Account',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),

const SizedBox(height: 12),

Card(
  child: ListTile(
    leading: CircleAvatar(
      backgroundColor: colorScheme.primary,
      child: Text(
        displayName.isNotEmpty
            ? displayName[0].toUpperCase()
            : 'U',
        style: TextStyle(
          color: colorScheme.onPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),

    title: Text(
      displayName,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
      ),
    ),

    subtitle: Text(
      email,
    ),
  ),
),

const SizedBox(height: 30),
          // =================================================
          // APPEARANCE
          // =================================================

          Text(
            'Appearance',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Choose how Ergobug should look.',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 14),

          // =================================================
          // THEME OPTIONS
          // =================================================

          Card(
  child: RadioGroup<ThemeMode>(
    groupValue: _selectedTheme,

    onChanged: (value) {
      if (value != null) {
        _changeTheme(value);
      }
    },

    child: Column(
      children: [
        // =================================================
        // LIGHT
        // =================================================

        RadioListTile<ThemeMode>(
          value: ThemeMode.light,

          title: const Text(
            'Light',
          ),

          subtitle: const Text(
            'Always use light mode',
          ),

          secondary: const Icon(
            Icons.light_mode_outlined,
          ),
        ),

        const Divider(
          height: 1,
        ),

        // =================================================
        // DARK
        // =================================================

        RadioListTile<ThemeMode>(
          value: ThemeMode.dark,

          title: const Text(
            'Dark',
          ),

          subtitle: const Text(
            'Always use dark mode',
          ),

          secondary: const Icon(
            Icons.dark_mode_outlined,
          ),
        ),

        const Divider(
          height: 1,
        ),

        // =================================================
        // SYSTEM DEFAULT
        // =================================================

        RadioListTile<ThemeMode>(
          value: ThemeMode.system,

          title: const Text(
            'System Default',
          ),

          subtitle: const Text(
            'Follow your device settings',
          ),

          secondary: const Icon(
            Icons.phone_android_outlined,
          ),
        ),
      ],
    ),
  ),
),

          const SizedBox(height: 20),

          // =================================================
          // CURRENT APPEARANCE
          // =================================================

          Card(
            child: ListTile(
              leading: Icon(
                Icons.palette_outlined,
                color: colorScheme.primary,
              ),

              title: const Text(
                'Current appearance',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),

              subtitle: Text(
                _themeName(),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // =================================================
          // ABOUT ERGOBUG
          // =================================================

          Text(
            'About Ergobug',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 12),

          // =================================================
          // ERGOBUG
          // =================================================

          Card(
            child: ListTile(
              leading: Icon(
                Icons.task_alt,
                color: colorScheme.primary,
                size: 32,
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

          const SizedBox(height: 10),

          // =================================================
          // VERSION
          // =================================================

          Card(
            child: const ListTile(
              leading: Icon(
                Icons.info_outline,
              ),

              title: Text(
                'Version',
              ),

              subtitle: Text(
                '1.0.0',
              ),
            ),
          ),
             // =================================================
             // TEST NOTIFICATION
             // =================================================

const SizedBox(height: 20),

ElevatedButton.icon(
  onPressed: () async {
    await NotificationService.instance.testNotification();

    if (!mounted) return;

    final tzName = NotificationService.instance.currentTimeZone;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Instant notification sent & 10s timer scheduled ($tzName).',
        ),
        backgroundColor: Colors.green,
      ),
    );
  },
  icon: const Icon(Icons.notifications_active_outlined),
  label: const Text('Test Notification & Timezone'),
),
        ],
      ),
    );
  }
}