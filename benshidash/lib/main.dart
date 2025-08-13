import 'package:benshidash/services/location_service.dart';
import 'package:flutter/material.dart';
import 'benshi/radio_controller.dart';
import 'ui/screens/settings/settings.dart';
import 'ui/screens/splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

final ValueNotifier<RadioController?> radioControllerNotifier = ValueNotifier(null);
const String PREF_LAST_DEVICE_ADDRESS = 'last_connected_device_address';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  await _loadSettings(prefs);
  await _tryAutoConnect(prefs);

  runApp(const TabletGatekeeper());
}

Future<void> _loadSettings(SharedPreferences prefs) async {
  showAprsPathsNotifier.value = prefs.getBool(PREF_SHOW_APRS_PATHS) ?? false;
  final savedSource = GpsSource.values[prefs.getInt(PREF_GPS_SOURCE) ?? GpsSource.radio.index];
  gpsSourceNotifier.value = savedSource;
  // --- NEW: Load the APRS radius setting ---
  aprsNearbyRadiusNotifier.value = prefs.getDouble(PREF_APRS_RADIUS) ?? 50.0;

  // Start the location service if the saved preference is 'device'
  if (savedSource == GpsSource.device) {
    await locationService.start();
  }
}

Future<void> _tryAutoConnect(SharedPreferences prefs) async {
  final String? deviceAddress = prefs.getString(PREF_LAST_DEVICE_ADDRESS);

  if (deviceAddress != null) {
    print("Found saved device: $deviceAddress. Attempting to auto-connect...");
    try {
      BluetoothDevice device = BluetoothDevice(address: deviceAddress);
      final controller = RadioController(device: device);
      await controller.connect();
      radioControllerNotifier.value = controller;
      print("Auto-connect successful.");
    } catch (e) {
      print("Auto-connect failed: $e. Clearing saved device.");
      await prefs.remove(PREF_LAST_DEVICE_ADDRESS);
    }
  }
}

class AppThemes {
  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: Colors.black,
    colorScheme: const ColorScheme.dark(
      primary: Colors.cyanAccent,
      secondary: Colors.greenAccent,
      surface: Color(0xFF212121),
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
    scaffoldBackgroundColor: const Color(0xFFE0E0E0),
    colorScheme: ColorScheme.light(
      primary: Colors.blue.shade700,
      secondary: Colors.teal.shade600,
      surface: const Color(0xFFF5F5F5),
      background: const Color(0xFFE0E0E0),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.black87,
      onBackground: Colors.black87,
      error: Colors.red.shade700,
      onError: Colors.white,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFFF5F5F5),
      elevation: 1,
      shadowColor: Colors.black26,
    ),
    iconTheme: IconThemeData(color: Colors.grey.shade800),
    dividerColor: Colors.black26,
  );
}

class TabletGatekeeper extends StatelessWidget {
  const TabletGatekeeper({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car Head Unit',
      debugShowCheckedModeBanner: false,
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      home: Builder(
        builder: (context) {
          final shortestSide = MediaQuery.of(context).size.shortestSide;
          if (shortestSide < 600) {
            // Not a tablet: block app usage
            return const Scaffold(
              body: Center(
                child: Text(
                  'This app is only available on tablets.',
                  style: TextStyle(fontSize: 24),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          // Tablet: run the actual app
          return const CarHeadUnitApp();
        },
      ),
    );
  }
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
          themeMode: themeNotifier.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}