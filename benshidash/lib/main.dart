import 'package:flutter/material.dart';
import 'ui/screens/settings/settings.dart'; // Import to access the global notifier
import 'ui/screens/splash.dart';

void main() {
  runApp(const CarHeadUnitApp());
}

/// Defines the color schemes and styles for the app's light and dark themes.
class AppThemes {
  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: Colors.black,
    colorScheme: const ColorScheme.dark(
      primary: Colors.cyanAccent,
      secondary: Colors.greenAccent,
      surface: Color(0xFF212121), // very dark grey
      background: Colors.black,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: Colors.white,
      onBackground: Colors.white,
      error: Colors.redAccent,
      onError: Colors.black,
    ),
    cardTheme: CardThemeData( // <-- FIX: Was CardTheme
      color: Colors.white.withOpacity(0.07),
      elevation: 0,
    ),
    iconTheme: const IconThemeData(color: Colors.white70),
    dividerColor: Colors.white24,
  );

  static final lightTheme = ThemeData(
    brightness: Brightness.light,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: const Color(0xFFE0E0E0), // Grey 300
    colorScheme: ColorScheme.light(
      primary: Colors.blue.shade700,
      secondary: Colors.teal.shade600,
      surface: const Color(0xFFF5F5F5), // Grey 100
      background: const Color(0xFFE0E0E0), // Grey 300
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.black87,
      onBackground: Colors.black87,
      error: Colors.red.shade700,
      onError: Colors.white,
    ),
    cardTheme: CardThemeData( // <-- FIX: Was CardTheme
      color: const Color(0xFFF5F5F5), // Grey 100
      elevation: 1,
      shadowColor: Colors.black26,
    ),
    iconTheme: IconThemeData(color: Colors.grey.shade800),
    dividerColor: Colors.black26,
  );
}

class CarHeadUnitApp extends StatelessWidget {
  const CarHeadUnitApp({super.key});

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder rebuilds the MaterialApp whenever the themeNotifier changes.
    // This makes the entire app's theme reactive.
    return AnimatedBuilder(
      animation: themeNotifier,
      builder: (context, child) {
        return MaterialApp(
          title: 'Car Head Unit',
          debugShowCheckedModeBanner: false,
          theme: AppThemes.lightTheme,
          darkTheme: AppThemes.darkTheme,
          themeMode: themeNotifier.themeMode, // Controlled by the notifier
          home: const SplashScreen(),
        );
      },
    );
  }
}