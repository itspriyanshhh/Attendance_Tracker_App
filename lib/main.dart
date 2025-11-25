// add near the top of the file (next to your imports)
import 'package:attendance_management/screens/splash_screen.dart';
import 'package:attendance_management/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;

final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(false);

/// Load saved dark-mode preference (call before runApp)
Future<void> _loadDarkMode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    isDarkMode.value = prefs.getBool('darkMode') ?? false;
  } catch (e) {
    // ignore errors and keep default
    print('Failed to load dark mode pref: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  // Initialize timezone
  tz.initializeTimeZones();
  await NotificationService.instance.init();
  await _loadDarkMode();
  AttendanceMonitor.instance.start();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // light theme
    final ThemeData lightTheme = ThemeData(
      primarySwatch: Colors.indigo,
      colorScheme: ColorScheme.fromSwatch(
        primarySwatch: Colors.indigo,
        accentColor: Colors.pinkAccent,
        backgroundColor: Colors.white,
      ),
      fontFamily: GoogleFonts.poppins().fontFamily,
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5F5F5),
        elevation: 0,
      ),
      textTheme: TextTheme(
        headlineLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.indigo[900],
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.indigo[800],
        ),
        bodySmall: GoogleFonts.poppins(fontSize: 12, color: Colors.black),
        bodyLarge: GoogleFonts.poppins(fontSize: 16, color: Colors.black),
        bodyMedium: GoogleFonts.poppins(fontSize: 14, color: Colors.black),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return Colors.indigo;
          }
          return Colors.grey.shade600;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return Colors.indigo.shade200;
          }
          return Colors.grey.shade300;
        }),
        trackOutlineColor: MaterialStateProperty.all(Colors.transparent),
      ),
    );

    // dark theme: revamped colors
    final ThemeData darkTheme = ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF121212),
      primaryColor: const Color(0xFF8C9EFF), // Pastel Indigo
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF8C9EFF),
        surface: Color(0xFF1E1E1E), // Rich Dark Grey
        surfaceContainer: Color(0xFF2C2C2C),
        onPrimary: Colors.black,
        onSurface: Color(0xFFE0E0E0), // High emphasis off-white
        onSurfaceVariant: Color(0xFFA0A0A0), // Medium emphasis grey
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF121212),
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFE0E0E0)),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: const Color(0xFF8C9EFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFE0E0E0),
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFE0E0E0),
        ),
        bodySmall: GoogleFonts.poppins(
          fontSize: 12,
          color: const Color(0xFFA0A0A0),
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 16,
          color: const Color(0xFFE0E0E0),
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          color: const Color(0xFFE0E0E0),
        ),
      ),
      iconTheme: const IconThemeData(color: Color(0xFFE0E0E0)),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const Color(0xFF8C9EFF);
          }
          return Colors.grey.shade600;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const Color(0xFF8C9EFF).withOpacity(0.5);
          }
          return Colors.grey.shade800;
        }),
        trackOutlineColor: MaterialStateProperty.all(Colors.transparent),
      ),
    );

    return ValueListenableBuilder<bool>(
      valueListenable: isDarkMode,
      builder: (context, dark, _) {
        return MaterialApp(
          title: 'Attendify',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: const SplashScreen(),
        );
      },
    );
  }
}
