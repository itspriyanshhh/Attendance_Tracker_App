// add near the top of the file (next to your imports)
import 'package:attendance_management/screens/splash_screen.dart';
import 'package:attendance_management/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  await NotificationService.instance.init();
  await _loadDarkMode();
  AttendanceMonitor.instance.start();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // light theme: (keep your existing theme code here — I've mirrored it)
    final ThemeData lightTheme = ThemeData(
      primarySwatch: Colors.indigo,
      colorScheme: ColorScheme.fromSwatch(
        primarySwatch: Colors.indigo,
        accentColor: Colors.pinkAccent,
        backgroundColor: Colors.white,

        // surface: const Color(0xFF1E1E1E),
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
        // iconTheme: IconThemeData(color: Colors.white),
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
    );

    // dark theme: dark background (#121212) and adjusted colors for text/icons
    final ThemeData darkTheme = ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF121212),
      primaryColor: Colors.indigo[200],
      colorScheme: ColorScheme.dark(
        primary: Colors.indigo[200]!,
        background: const Color(0xFF121212),
        surface: const Color.fromARGB(255, 80, 80, 80),
        onPrimary: Colors.black,
        onSurface: Colors.white,

      ),


      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF121212),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: const Color.fromARGB(255, 62, 62, 62),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.indigoAccent,
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
          color: Colors.white,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodySmall: GoogleFonts.poppins(fontSize: 12, color: Colors.white),
        bodyLarge: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
        bodyMedium: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    );

    return ValueListenableBuilder<bool>(
      valueListenable: isDarkMode,
      builder: (context, dark, _) {
        return MaterialApp(
          title: 'Your New App Name',
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
