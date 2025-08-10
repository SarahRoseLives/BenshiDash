import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../../../benshi/radio_controller.dart';
import '../../../main.dart';
import '../home/dashboard.dart';
import '../../widgets/main_layout.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences

// --- Theme Notifier ---
/// A simple state manager for the app's theme.
class ThemeNotifier extends ChangeNotifier {
  // Default to dark mode as per the original UI design.
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Sets the new theme and notifies any listening widgets to rebuild.
  void setTheme(ThemeMode themeMode) {
    if (_themeMode != themeMode) {
      _themeMode = themeMode;
      notifyListeners(); // This is what triggers the UI update.
    }
  }
}

/// A global instance of the theme notifier, accessible throughout the app.
final ThemeNotifier themeNotifier = ThemeNotifier();

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _showDeviceSelectionDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (ctx) => const _DeviceListDialog(),
    );
  }

  // --- NEW: Method to handle disconnection ---
  Future<void> _disconnect(RadioController radioController) async {
    // Dispose the controller to close the connection
    radioController.dispose();
    radioControllerNotifier.value = null;

    // Remove the saved device address from preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PREF_LAST_DEVICE_ADDRESS);
    print("Disconnected and cleared saved device.");
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use an AnimatedBuilder to ensure the Switch updates when the theme changes.
    return AnimatedBuilder(
      animation: themeNotifier,
      builder: (context, child) {
        return ValueListenableBuilder<RadioController?>(
          valueListenable: radioControllerNotifier,
          builder: (context, radioController, _) {
            return MainLayout(
              // --- THIS IS THE CHANGE ---
              radioController: radioController,
              // --- END OF CHANGE ---
              radio: radio,
              battery: battery,
              gps: gps,
              child: ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  _buildSectionTitle('Bluetooth Connection', theme),
                  Card(
                    color: theme.cardTheme.color,
                    child: radioController == null
                        ? ListTile(
                            leading: const Icon(Icons.bluetooth_disabled),
                            title: const Text('Connect to Radio'),
                            subtitle: const Text('Not connected'),
                            onTap: () => _showDeviceSelectionDialog(context),
                          )
                        : ListTile(
                            leading: Icon(Icons.bluetooth_connected, color: Colors.green.shade400),
                            title: Text('Connected to ${radioController.device.name ?? 'Unknown Device'}'),
                            subtitle: Text(radioController.device.address),
                            trailing: TextButton(
                              child: const Text('Disconnect'),
                              // --- MODIFIED: Call the new disconnect method ---
                              onPressed: () => _disconnect(radioController),
                            ),
                          ),
                  ),
                  _buildSectionTitle('Appearance', theme),
                  Card(
                    color: theme.cardTheme.color,
                    child: SwitchListTile(
                      title: const Text('Enable Dark Mode'),
                      subtitle: Text(
                        'Switch between light and dark themes.',
                        style: TextStyle(color: theme.textTheme.bodySmall?.color),
                      ),
                      value: themeNotifier.isDarkMode,
                      onChanged: (isDark) {
                        // Calling this method triggers the update across the app.
                        themeNotifier.setTheme(isDark ? ThemeMode.dark : ThemeMode.light);
                      },
                      secondary: Icon(
                        themeNotifier.isDarkMode ? Icons.nightlight_round : Icons.wb_sunny,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Padding _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0, left: 4.0),
      child: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}

class _DeviceListDialog extends StatefulWidget {
  const _DeviceListDialog();
  @override
  State<_DeviceListDialog> createState() => _DeviceListDialogState();
}

class _DeviceListDialogState extends State<_DeviceListDialog> {
  StreamSubscription<BluetoothDiscoveryResult>? _streamSubscription;
  List<BluetoothDiscoveryResult> results = [];
  bool isDiscovering = false;
  bool isConnecting = false;

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  void _startDiscovery() {
    setState(() {
      isDiscovering = true;
    });
    _streamSubscription = FlutterBluetoothSerial.instance.startDiscovery().listen((r) {
      setState(() {
        final existingIndex = results.indexWhere((element) => element.device.address == r.device.address);
        if (existingIndex >= 0) {
          results[existingIndex] = r;
        } else {
          results.add(r);
        }
      });
    });

    _streamSubscription!.onDone(() {
      setState(() {
        isDiscovering = false;
      });
    });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(children: [
        const Text('Select a Radio'),
        if (isDiscovering || isConnecting)
          const Padding(
            padding: EdgeInsets.only(left: 8.0),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          )
      ]),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: results.length,
          itemBuilder: (context, index) {
            BluetoothDiscoveryResult result = results[index];
            return ListTile(
              leading: const Icon(Icons.radio),
              title: Text(result.device.name ?? 'Unknown Device'),
              subtitle: Text(result.device.address),
              onTap: isConnecting ? null : () async {
                setState(() { isConnecting = true; });

                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);

                try {
                  final controller = RadioController(device: result.device);
                  await controller.connect();
                  radioControllerNotifier.value = controller;

                  // --- NEW: Save the device address on successful connection ---
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(PREF_LAST_DEVICE_ADDRESS, result.device.address);
                  print("Saved device ${result.device.address} to preferences.");

                  navigator.pop();

                  messenger.showSnackBar(
                    const SnackBar(content: Text('Successfully connected!'), backgroundColor: Colors.green),
                  );

                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Connection failed: $e'), backgroundColor: Colors.red),
                  );
                  if (mounted) {
                    setState(() { isConnecting = false; });
                  }
                }
              },
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))],
    );
  }
}