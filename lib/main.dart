import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // =====================================================
  // FIREBASE
  // =====================================================

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // =====================================================
  // NOTIFICATIONS
  // =====================================================

  try {
    await NotificationService.instance.initialize();
    await NotificationService.instance.requestPermission();
  } catch (e) {
    debugPrint('Notification setup failed; app will continue: $e');
  }

  // =====================================================
  // LOAD SAVED THEME
  // =====================================================

  final savedTheme =
      await ThemeService.loadTheme();

  // =====================================================
  // START APP
  // =====================================================

  runApp(
    ErgobugApp(
      initialThemeMode: savedTheme,
    ),
  );
}

// =========================================================
// ERGOBUG APP
// =========================================================

class ErgobugApp extends StatefulWidget {
  final ThemeMode initialThemeMode;

  const ErgobugApp({
    super.key,
    required this.initialThemeMode,
  });

  @override
  State<ErgobugApp> createState() =>
      _ErgobugAppState();
}

class _ErgobugAppState
    extends State<ErgobugApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();

    _themeMode =
        widget.initialThemeMode;
  }

  // =====================================================
  // CHANGE THEME
  // =====================================================

  Future<void> changeTheme(
    ThemeMode mode,
  ) async {
    setState(() {
      _themeMode = mode;
    });

    await ThemeService.saveTheme(mode);
  }

  // =====================================================
  // LIGHT THEME
  // =====================================================

  ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,

      brightness: Brightness.light,

      colorScheme: ColorScheme.fromSeed(
        seedColor:
            const Color(0xFF2563EB),
        brightness:
            Brightness.light,
      ),

      scaffoldBackgroundColor:
          const Color(0xFFF5F7FB),

      cardTheme: CardThemeData(
        color: Colors.white,

        elevation: 3,

        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(18),
        ),
      ),

      textTheme: const TextTheme(
        bodyLarge: TextStyle(
          color: Color(0xFF111827),
        ),

        bodyMedium: TextStyle(
          color: Color(0xFF374151),
        ),

        bodySmall: TextStyle(
          color: Color(0xFF6B7280),
        ),

        titleLarge: TextStyle(
          color: Color(0xFF111827),
        ),

        titleMedium: TextStyle(
          color: Color(0xFF111827),
        ),

        titleSmall: TextStyle(
          color: Color(0xFF374151),
        ),
      ),

      inputDecorationTheme:
          InputDecorationTheme(
        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),
        ),

        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),

          borderSide:
              BorderSide(
            color:
                Colors.grey.shade300,
          ),
        ),

        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),

          borderSide:
              const BorderSide(
            color:
                Color(0xFF2563EB),
            width: 2,
          ),
        ),
      ),
    );
  }

  // =====================================================
  // DARK THEME
  // =====================================================

  ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,

      brightness: Brightness.dark,

      colorScheme: ColorScheme.fromSeed(
        seedColor:
            const Color(0xFF60A5FA),
        brightness:
            Brightness.dark,
      ),

      scaffoldBackgroundColor:
          const Color(0xFF0F172A),

      cardTheme: CardThemeData(
        color:
            const Color(0xFF1E293B),

        elevation: 3,

        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(18),
        ),
      ),

      textTheme: const TextTheme(
        bodyLarge: TextStyle(
          color: Color(0xFFF8FAFC),
        ),

        bodyMedium: TextStyle(
          color: Color(0xFFE2E8F0),
        ),

        bodySmall: TextStyle(
          color: Color(0xFFCBD5E1),
        ),

        titleLarge: TextStyle(
          color: Color(0xFFF8FAFC),
        ),

        titleMedium: TextStyle(
          color: Color(0xFFF8FAFC),
        ),

        titleSmall: TextStyle(
          color: Color(0xFFE2E8F0),
        ),
      ),

      iconTheme:
          const IconThemeData(
        color:
            Color(0xFFE2E8F0),
      ),

      inputDecorationTheme:
          InputDecorationTheme(
        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),
        ),

        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),

          borderSide:
              const BorderSide(
            color:
                Color(0xFF475569),
          ),
        ),

        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),

          borderSide:
              const BorderSide(
            color:
                Color(0xFF60A5FA),
            width: 2,
          ),
        ),
      ),
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'Ergobug',

      theme: lightTheme,

      darkTheme: darkTheme,

      themeMode: _themeMode,

      home: SplashScreen(
        themeMode: _themeMode,
        onThemeChanged: changeTheme,
      ),
    );
  }
}