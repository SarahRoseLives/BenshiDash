// ui/screens/settings/settings.dart
import 'dart:async';
import 'package:benshidash/services/location_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../../../benshi/radio_controller.dart';
import '../../../main.dart';
import '../../widgets/main_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart'; // Import LatLng
import 'map_settings.dart'; // Import the new Map Settings screen

// --- Notifiers and Constants ---
class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void setTheme(ThemeMode themeMode) {
    if (_themeMode != themeMode) {
      _themeMode = themeMode;
      notifyListeners();
    }
  }
}

final ThemeNotifier themeNotifier = ThemeNotifier();

final ValueNotifier<bool> showAprsPathsNotifier = ValueNotifier(false);
const String PREF_SHOW_APRS_PATHS = 'show_aprs_paths';

final ValueNotifier<GpsSource> gpsSourceNotifier = ValueNotifier(GpsSource.radio);
const String PREF_GPS_SOURCE = 'gps_source';

final ValueNotifier<double> aprsNearbyRadiusNotifier = ValueNotifier(50.0);
const String PREF_APRS_RADIUS = 'aprs_nearby_radius';

final ValueNotifier<double> aprsFrequencyNotifier = ValueNotifier(144.390);
const String PREF_APRS_FREQUENCY = 'aprs_frequency';

final ValueNotifier<bool> offlineModeNotifier = ValueNotifier(false);
const String PREF_OFFLINE_MODE = 'offline_mode';

final ValueNotifier<LatLng?> homeLocationNotifier = ValueNotifier(null);
const String PREF_HOME_LAT = 'home_latitude';
const String PREF_HOME_LON = 'home_longitude';

// --- Top-Level Helper Functions for Settings ---

// Loads map-specific settings from SharedPreferences
Future<void> loadMapSettings(SharedPreferences prefs) async {
  offlineModeNotifier.value = prefs.getBool(PREF_OFFLINE_MODE) ?? false;
  final double? lat = prefs.getDouble(PREF_HOME_LAT);
  final double? lon = prefs.getDouble(PREF_HOME_LON);
  if (lat != null && lon != null) {
    homeLocationNotifier.value = LatLng(lat, lon);
  } else {
    homeLocationNotifier.value = null;
  }
}

// Updates the home location notifier and saves to SharedPreferences
Future<void> updateHomeLocation(LatLng? newLocation) async {
  homeLocationNotifier.value = newLocation;
  final prefs = await SharedPreferences.getInstance();
  if (newLocation != null) {
    await prefs.setDouble(PREF_HOME_LAT, newLocation.latitude);
    await prefs.setDouble(PREF_HOME_LON, newLocation.longitude);
  } else {
    await prefs.remove(PREF_HOME_LAT);
    await prefs.remove(PREF_HOME_LON);
  }
}

// Toggles the offline mode notifier and saves to SharedPreferences
Future<void> toggleOfflineMode(bool value) async {
  offlineModeNotifier.value = value;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(PREF_OFFLINE_MODE, value);
}

// --- Settings Screen Widget ---

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Methods specific to the UI interaction within this screen
  Future<void> _showDeviceSelectionDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (ctx) => const _DeviceListDialog(),
    );
  }

  Future<void> _disconnect(RadioController radioController) async {
    radioController.dispose();
    radioControllerNotifier.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PREF_LAST_DEVICE_ADDRESS);
  }

  Future<void> _toggleAprsPaths(bool value) async {
    showAprsPathsNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PREF_SHOW_APRS_PATHS, value);
  }

  Future<void> _onGpsSourceChanged(GpsSource? source) async {
    if (source == null) return;
    gpsSourceNotifier.value = source;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(PREF_GPS_SOURCE, source.index);

    if (source == GpsSource.device) {
      await locationService.start();
    } else {
      locationService.stop();
    }
  }

  Future<void> _onAprsRadiusChanged(double value) async {
    aprsNearbyRadiusNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(PREF_APRS_RADIUS, value);
  }

  Future<void> _editAprsFrequency(BuildContext context) async {
    final TextEditingController controller = TextEditingController(
      text: aprsFrequencyNotifier.value.toStringAsFixed(3),
    );
    final newFreqString = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Set APRS Frequency"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "Frequency (MHz)",
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (newFreqString != null) {
      final double? newFreq = double.tryParse(newFreqString);
      if (newFreq != null) {
        aprsFrequencyNotifier.value = newFreq;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(PREF_APRS_FREQUENCY, newFreq);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invalid frequency format.")),
          );
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Combine listeners
    return AnimatedBuilder(
      animation: Listenable.merge([
        themeNotifier,
        showAprsPathsNotifier,
        gpsSourceNotifier,
        aprsNearbyRadiusNotifier,
        aprsFrequencyNotifier,
        offlineModeNotifier, // Add new notifier
        homeLocationNotifier, // Add new notifier
      ]),
      builder: (context, child) {
        return ValueListenableBuilder<RadioController?>(
          valueListenable: radioControllerNotifier,
          builder: (context, radioController, _) {
            return MainLayout(
              radioController: radioController,
              child: ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  _buildSectionTitle('Bluetooth Connection', theme),
                  Card(
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
                              onPressed: () => _disconnect(radioController),
                            ),
                          ),
                  ),
                  _buildSectionTitle('Application Settings', theme),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.gps_fixed, color: theme.colorScheme.primary),
                          title: const Text('GPS Source'),
                          trailing: DropdownButton<GpsSource>(
                            value: gpsSourceNotifier.value,
                            items: [
                              const DropdownMenuItem(value: GpsSource.radio, child: Text("Radio GPS")),
                              const DropdownMenuItem(value: GpsSource.device, child: Text("Device GPS")),
                              if (kDebugMode)
                                const DropdownMenuItem(value: GpsSource.debug, child: Text("Debug GPS (Jefferson, OH)")),
                            ],
                            onChanged: _onGpsSourceChanged,
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.track_changes, color: theme.colorScheme.primary),
                          title: const Text('APRS Frequency'),
                          subtitle: Text('${aprsFrequencyNotifier.value.toStringAsFixed(3)} MHz'),
                          trailing: const Icon(Icons.edit),
                          onTap: () => _editAprsFrequency(context),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('Show APRS Packet Paths'),
                          subtitle: const Text('Draw lines showing the path a packet took.'),
                          value: showAprsPathsNotifier.value,
                          onChanged: _toggleAprsPaths,
                          secondary: Icon(Icons.polyline, color: theme.colorScheme.primary),
                        ),
                        const Divider(height: 1),
                        _buildSliderSetting(
                          context: context, // Pass context here
                          title: 'APRS "Nearby" Radius',
                          subtitle: 'Current: ${aprsNearbyRadiusNotifier.value.round()} miles',
                          value: aprsNearbyRadiusNotifier.value,
                          min: 5,
                          max: 200,
                          divisions: 39, // (200-5)/5
                          onChanged: (val) => setState(() => aprsNearbyRadiusNotifier.value = val),
                          onChangeEnd: _onAprsRadiusChanged,
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('Enable Dark Mode'),
                          subtitle: const Text('Switch between light and dark themes.'),
                          value: themeNotifier.isDarkMode,
                          onChanged: (isDark) {
                            themeNotifier.setTheme(isDark ? ThemeMode.dark : ThemeMode.light);
                          },
                          secondary: Icon(
                            themeNotifier.isDarkMode ? Icons.nightlight_round : Icons.wb_sunny,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildSectionTitle('Map Settings', theme),
                   Card(
                      child: Column(
                       children: [
                         SwitchListTile(
                            title: const Text('Offline Map Mode'),
                            subtitle: const Text('Use downloaded map tiles when available.'),
                            value: offlineModeNotifier.value,
                            // --- CORRECTED CALL ---
                            onChanged: toggleOfflineMode, // Call top-level function
                            // ----------------------
                            secondary: Icon(Icons.cloud_off, color: theme.colorScheme.primary),
                          ),
                         const Divider(height: 1),
                         ListTile(
                            leading: Icon(Icons.map, color: theme.colorScheme.primary),
                            title: const Text('Configure Offline Maps'),
                            subtitle: Text(homeLocationNotifier.value == null
                                ? 'Set home location on APRS map first (long-press)' // Updated instruction
                                : 'Home: ${homeLocationNotifier.value!.latitude.toStringAsFixed(4)}, ${homeLocationNotifier.value!.longitude.toStringAsFixed(4)}'),
                            trailing: const Icon(Icons.arrow_forward_ios),
                           onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const MapSettingsScreen()),
                              );
                           },
                          ),
                       ],
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
        style:
            theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }

  Widget _buildSliderSetting({
    required BuildContext context, // Added context
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: value.round().toString(),
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ],
      ),
    );
  }
}

// --- _DeviceListDialog remains unchanged ---
class _DeviceListDialog extends StatefulWidget {
  const _DeviceListDialog();
  @override
  State<_DeviceListDialog> createState() => _DeviceListDialogState();
}

class _DeviceListDialogState extends State<_DeviceListDialog> {
  StreamSubscription<BluetoothDiscoveryResult>? _streamSubscription;
  List<BluetoothDevice> _bondedDevices = [];
  List<BluetoothDiscoveryResult> _discoveredResults = [];
  bool _isDiscovering = false;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _refreshDeviceLists();
  }

  Future<void> _refreshDeviceLists() async {
    setState(() {
      _isDiscovering = true;
      _bondedDevices = [];
      _discoveredResults = [];
    });

    try {
      _bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (e) {
      if (kDebugMode) print("Error getting bonded devices: $e");
    } finally {
      if(mounted) setState(() {});
    }

    _streamSubscription = FlutterBluetoothSerial.instance.startDiscovery().listen((r) {
      if(mounted) {
        setState(() {
          final isAlreadyBonded = _bondedDevices.any((d) => d.address == r.device.address);
          final isAlreadyDiscovered = _discoveredResults.any((res) => res.device.address == r.device.address);

          if (!isAlreadyBonded && !isAlreadyDiscovered && (r.device.name?.isNotEmpty ?? false)) { // Also filter unnamed devices
            _discoveredResults.add(r);
          }
        });
      }
    });
    _streamSubscription!.onDone(() {
      if (mounted) setState(() => _isDiscovering = false);
    });
     _streamSubscription!.onError((e){
        if (kDebugMode) print("Error during discovery: $e");
        if (mounted) setState(() => _isDiscovering = false);
     });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() => _isConnecting = true);
    // Cancel discovery when attempting connection
    await FlutterBluetoothSerial.instance.cancelDiscovery();
    if(mounted) setState(() => _isDiscovering = false);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final controller = RadioController(device: device);
      await controller.connect();
      radioControllerNotifier.value = controller;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PREF_LAST_DEVICE_ADDRESS, device.address);
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Successfully connected!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Connection failed: $e'), backgroundColor: Colors.red),
      );
      // Don't restart discovery automatically here, let user retry if needed
    } finally {
       if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    // Ensure discovery is cancelled if dialog is closed
    FlutterBluetoothSerial.instance.cancelDiscovery();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    List<Widget> listItems = [];

    listItems.add(
      ListTile(
        dense: true,
        title: Text("Paired Devices", style: theme.textTheme.titleSmall),
      )
    );
    if (_bondedDevices.isEmpty) {
      listItems.add(const ListTile(subtitle: Text("No previously paired devices found.")));
    } else {
      listItems.addAll(
        _bondedDevices.map((device) => ListTile(
            leading: const Icon(Icons.radio),
            title: Text(device.name ?? "Unknown Device"),
            subtitle: Text(device.address),
            onTap: _isConnecting ? null : () => _connectToDevice(device),
          ))
      );
    }

    listItems.add(const Divider());
    listItems.add(
      ListTile(
        dense: true,
        title: Text("Available Devices", style: theme.textTheme.titleSmall),
        trailing: _isDiscovering ? null : IconButton(
           icon: const Icon(Icons.refresh),
           tooltip: "Rescan",
           onPressed: _isConnecting ? null : _refreshDeviceLists,
        ),
      )
    );

    if (_discoveredResults.isEmpty && !_isDiscovering) {
      listItems.add(const ListTile(subtitle: Text("No new devices found. Tap refresh to scan.")));
    } else if (_discoveredResults.isEmpty && _isDiscovering) {
       listItems.add(const ListTile(subtitle: Text("Scanning...")));
    }
    else {
      listItems.addAll(
        _discoveredResults.map((result) => ListTile(
            leading: const Icon(Icons.bluetooth_searching),
            title: Text(result.device.name ?? "Unknown Device"),
            subtitle: Text(result.device.address),
            trailing: Text("${result.rssi} dBm"),
            onTap: _isConnecting ? null : () => _connectToDevice(result.device),
          ))
      );
    }

    return AlertDialog(
      title: Row(children: [
        const Text('Select a Radio'),
        if (_isDiscovering || _isConnecting)
          const Padding(
            padding: EdgeInsets.only(left: 8.0),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          )
      ]),
      content: SizedBox(
        width: double.maxFinite, // Use maxFinite for dialogs
        child: ListView(
          shrinkWrap: true, // Important for ListView in Dialog
          children: listItems,
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))],
    );
  }
}