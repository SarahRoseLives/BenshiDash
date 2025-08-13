import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../benshi/protocol/protocol.dart';
import '../../../benshi/radio_controller.dart';
import '../../../main.dart';
import '../../widgets/main_layout.dart';

class RadioSettingsScreen extends StatefulWidget {
  const RadioSettingsScreen({super.key});

  @override
  State<RadioSettingsScreen> createState() => _RadioSettingsScreenState();
}

class _RadioSettingsScreenState extends State<RadioSettingsScreen> {
  Settings? _currentSettings;
  Settings? _initialSettings;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final radioController = radioControllerNotifier.value;
    if (radioController != null && radioController.isReady) {
      setState(() {
        _initialSettings = radioController.settings;
        _currentSettings = radioController.settings;
      });
    } else {
      // Provide default mock settings if not connected
      final defaultSettings = Settings(
        channelA: 1, channelB: 2, scan: false, squelchLevel: 5,
        micGain: 3, btMicGain: 4, vfoX: 1, tailElim: true,
        autoPowerOn: false, txTimeLimit: 12, powerSavingMode: true,
        pttLock: false, imperialUnit: true, wxMode: 0,
      );
      setState(() {
        _initialSettings = defaultSettings;
        _currentSettings = defaultSettings;
      });
    }
  }

  void _saveSettings() {
    final radioController = radioControllerNotifier.value;
    if (radioController != null && _currentSettings != null) {
      radioController.writeSettings(_currentSettings!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings written to radio!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected to radio.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<RadioController?>(
      valueListenable: radioControllerNotifier,
      builder: (context, radioController, _) {
        if (radioController != null && _currentSettings != radioController.settings) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadSettings());
        }

        return MainLayout(
          radioController: radioController,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text('Radio Settings'),
              backgroundColor: theme.colorScheme.surface,
              actions: [
                TextButton.icon(
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset'),
                  onPressed: () {
                    setState(() {
                      _currentSettings = _initialSettings;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Settings reset to initial values.')),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                    onPressed: _saveSettings,
                  ),
                ),
              ],
            ),
            body: _currentSettings == null
                ? const Center(child: Text("Connect radio to edit settings."))
                : ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      _buildSectionTitle('General', theme),
                      Card(
                        child: Column(
                          children: [
                            _buildSliderSetting(
                              title: 'Squelch Level',
                              subtitle: 'Current: ${_currentSettings!.squelchLevel}',
                              value: _currentSettings!.squelchLevel.toDouble(),
                              min: 0, max: 9, divisions: 9,
                              onChanged: (val) => setState(() => _currentSettings =
                                  _currentSettings!.copyWith(squelchLevel: val.round())),
                            ),
                            _buildSliderSetting(
                              title: 'Microphone Gain',
                              subtitle: 'Current: ${_currentSettings!.micGain}',
                              value: _currentSettings!.micGain.toDouble(),
                              min: 0, max: 7, divisions: 7,
                              onChanged: (val) => setState(() => _currentSettings =
                                  _currentSettings!.copyWith(micGain: val.round())),
                            ),
                            _buildDropdownSetting<int>(
                              title: 'VFO Mode',
                              value: _currentSettings!.vfoX,
                              items: const {0: 'Memory', 1: 'VFO A', 2: 'VFO B'},
                              onChanged: (val) => setState(
                                () => _currentSettings = _currentSettings!.copyWith(vfoX: val)),
                            ),
                          ],
                        ),
                      ),
                      _buildSectionTitle('Power & Timers', theme),
                      Card(
                        child: Column(
                          children: [
                            _buildSwitchSetting(
                              title: 'Auto Power On',
                              subtitle: 'Turn radio on with vehicle power',
                              value: _currentSettings!.autoPowerOn,
                              onChanged: (val) => setState(() =>
                                  _currentSettings = _currentSettings!.copyWith(autoPowerOn: val)),
                            ),
                            _buildSwitchSetting(
                              title: 'Power Saving Mode',
                              subtitle: 'Reduces battery consumption',
                              value: _currentSettings!.powerSavingMode,
                              onChanged: (val) => setState(() => _currentSettings =
                                  _currentSettings!.copyWith(powerSavingMode: val)),
                            ),
                            _buildDropdownSetting<int>(
                              title: 'Transmit Time-Out',
                              value: _currentSettings!.txTimeLimit,
                              items: const {
                                0: 'Off', 1: '15s', 12: '60s', 24: '120s', 31: '180s'
                              },
                              onChanged: (val) => setState(() => _currentSettings =
                                  _currentSettings!.copyWith(txTimeLimit: val)),
                            ),
                          ],
                        ),
                      ),
                      _buildSectionTitle('Audio & Bluetooth', theme),
                      Card(
                        child: Column(
                          children: [
                            _buildSwitchSetting(
                              title: 'Squelch Tail Elimination',
                              subtitle: 'Reduces noise at the end of transmissions',
                              value: _currentSettings!.tailElim,
                              onChanged: (val) => setState(() =>
                                  _currentSettings = _currentSettings!.copyWith(tailElim: val)),
                            ),
                            _buildSliderSetting(
                              title: 'Bluetooth Mic Gain',
                              subtitle: 'Current: ${_currentSettings!.btMicGain}',
                              value: _currentSettings!.btMicGain.toDouble(),
                              min: 0,
                              max: 7,
                              divisions: 7,
                              onChanged: (val) => setState(() => _currentSettings =
                                  _currentSettings!.copyWith(btMicGain: val.round())),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
            ),
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

  SwitchListTile _buildSwitchSetting({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      value: value,
      onChanged: onChanged,
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
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownSetting<T>({
    required String title,
    required T value,
    required Map<T, String> items,
    required ValueChanged<T?> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<T>(
        value: value,
        items: items.entries.map((entry) {
          return DropdownMenuItem<T>(
            value: entry.key,
            child: Text(entry.value),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}