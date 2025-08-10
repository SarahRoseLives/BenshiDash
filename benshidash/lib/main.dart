import 'package:flutter/material.dart';
import 'benshi/radio_controller.dart';
import 'ui/screens/settings/settings.dart';
import 'ui/screens/splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';


/// A global notifier to hold the app's single RadioController instance.
/// Widgets can listen to this to react to connection/disconnection events.
final ValueNotifier<RadioController?> radioControllerNotifier = ValueNotifier(null);

// The key we'll use to store the device address
const String PREF_LAST_DEVICE_ADDRESS = 'last_connected_device_address';

Future<void> main() async {
  // Ensure Flutter is initialized before we run async code
  WidgetsFlutterBinding.ensureInitialized();

  // Attempt to auto-connect to the last device
  await _tryAutoConnect();

  runApp(const CarHeadUnitApp());
}

/// Checks for a saved device address and attempts to connect to it.
Future<void> _tryAutoConnect() async {
  final prefs = await SharedPreferences.getInstance();
  final String? deviceAddress = prefs.getString(PREF_LAST_DEVICE_ADDRESS);

  if (deviceAddress != null) {
    print("Found saved device: $deviceAddress. Attempting to auto-connect...");
    try {
      // Create a device object from the saved address
      BluetoothDevice device = BluetoothDevice(address: deviceAddress);

      // Create and connect the controller
      final controller = RadioController(device: device);
      await controller.connect();

      // Update the global notifier so the app knows we're connected
      radioControllerNotifier.value = controller;
      print("Auto-connect successful.");

    } catch (e) {
      print("Auto-connect failed: $e. Clearing saved device.");
      // If connection fails, clear the saved address to prevent future errors
      await prefs.remove(PREF_LAST_DEVICE_ADDRESS);
    }
  }
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
    cardTheme: CardThemeData(
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
    cardTheme: CardThemeData(
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