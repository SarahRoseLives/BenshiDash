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

// --- NEW: Added APRS frequency setting ---
final ValueNotifier<double> aprsFrequencyNotifier = ValueNotifier(144.390);
const String PREF_APRS_FREQUENCY = 'aprs_frequency';
// -----------------------------------------

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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

  // --- NEW: Method to show a dialog for editing the APRS frequency ---
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
    return AnimatedBuilder(
      animation: Listenable.merge([themeNotifier, showAprsPathsNotifier, gpsSourceNotifier, aprsNearbyRadiusNotifier, aprsFrequencyNotifier]),
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
                        // --- NEW: APRS Frequency Setting ---
                        ListTile(
                          leading: Icon(Icons.track_changes, color: theme.colorScheme.primary),
                          title: const Text('APRS Frequency'),
                          subtitle: Text('${aprsFrequencyNotifier.value.toStringAsFixed(3)} MHz'),
                          trailing: const Icon(Icons.edit),
                          onTap: () => _editAprsFrequency(context),
                        ),
                        const Divider(height: 1),
                        // ------------------------------------
                        SwitchListTile(
                          title: const Text('Show APRS Packet Paths'),
                          subtitle: const Text('Draw lines showing the path a packet took.'),
                          value: showAprsPathsNotifier.value,
                          onChanged: _toggleAprsPaths,
                          secondary: Icon(Icons.polyline, color: theme.colorScheme.primary),
                        ),
                        const Divider(height: 1),
                        _buildSliderSetting(
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
    setState(() { isDiscovering = true; });
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
      setState(() { isDiscovering = false; });
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
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(PREF_LAST_DEVICE_ADDRESS, result.device.address);
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