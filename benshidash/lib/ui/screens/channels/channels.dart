import 'dart:convert';
import 'package:benshidash/models/repeater.dart';
import 'package:benshidash/services/location_service.dart';
import 'package:benshidash/services/repeaterbook_service.dart';
import 'package:benshidash/ui/screens/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/memory_list.dart';
import '../../../benshi/protocol/protocol.dart';
import '../../widgets/main_layout.dart';
import '../../../benshi/radio_controller.dart';
import '../../../main.dart';
import '../home/dashboard.dart';

Future<List<Map<String, List<Channel>>>> _loadMemoryAssets() async {
  try {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);

    final memoryFilesPaths = manifestMap.keys
        .where((String key) => key.startsWith('assets/memorylists/') && key.endsWith('.json'))
        .toList();

    final List<Map<String, List<Channel>>> memoryLists = [];
    for (final path in memoryFilesPaths) {
      final jsonString = await rootBundle.loadString(path);
      final memoryFile = MemoryList.fromJson(json.decode(jsonString));
      memoryLists.add({memoryFile.name: memoryFile.channels});
    }
    return memoryLists;
  } catch (e) {
    if (kDebugMode) {
      print("Error loading memory assets: $e");
    }
    return [];
  }
}

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  List<Channel>? _channels;
  bool _isLoading = true;
  String _statusMessage = 'Initializing...';
  RadioController? _radioController;
  bool _isSelectingMemory = false;
  List<Map<String, List<Channel>>> _allMemoryLists = [];
  bool _isInEditMode = false;

  @override
  void initState() {
    super.initState();
    _radioController = radioControllerNotifier.value;
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _loadAllMemoryLists();
    await _loadAllChannels();
  }

  Future<void> _loadAllMemoryLists() async {
    final assetMemories = await _loadMemoryAssets();
    final prefs = await SharedPreferences.getInstance();
    final savedMemories = <Map<String, List<Channel>>>[];
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith('memory_backup_')) {
        final name = key.replaceFirst('memory_backup_', '');
        final jsonString = prefs.getString(key);
        if (jsonString != null) {
          final List<dynamic> channelJson = json.decode(jsonString);
          final channels = channelJson.map((c) => Channel.fromJson(c)).toList();
          savedMemories.add({name: channels});
        }
      }
    }

    if (mounted) {
      setState(() {
        _allMemoryLists = [...assetMemories, ...savedMemories];
      });
    }
  }

  Future<void> _loadAllChannels() async {
    if (!mounted) return;
    if (_radioController == null) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Connect to a radio to program channels.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Reading all channels from radio...';
    });

    try {
      final channels = await _radioController!.getAllChannels();
      if (mounted) {
        setState(() {
          _channels = channels;
          _isLoading = false;
          _statusMessage = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Error loading channels: $e';
        });
      }
    }
  }

  void _editChannel(int index) async {
    if (_channels == null || _radioController == null) return;

    final Channel? updatedChannel = await showModalBottomSheet<Channel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChannelEditor(channel: _channels![index]),
    );

    if (updatedChannel != null) {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Writing channel ${updatedChannel.channelId + 1} to radio...';
      });

      try {
        await _radioController!.writeChannel(updatedChannel);
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Channel ${updatedChannel.channelId + 1} written."), duration: const Duration(seconds: 1)),
          );
        }
        if (mounted) {
          setState(() {
            _channels![index] = updatedChannel;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to save channel: $e")),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _tuneToChannel(Channel channel) async {
    if (_radioController == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Radio not connected.")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Tuning to Ch ${channel.channelId + 1}: ${channel.name.trim()}..."), duration: const Duration(seconds: 2)),
    );

    final currentStatus = _radioController!.status;
    final currentSettings = _radioController!.settings;

    if (currentStatus == null || currentSettings == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Radio state not fully loaded. Cannot tune.")),
      );
      return;
    }

    try {
      Settings newSettings;
      if (currentStatus.doubleChannel == ChannelType.B) {
        newSettings = currentSettings.copyWith(channelB: channel.channelId);
      } else {
        newSettings = currentSettings.copyWith(channelA: channel.channelId);
      }

      await _radioController!.writeSettings(newSettings);

      await Future.delayed(const Duration(milliseconds: 200));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, _, __) => const DashboardScreen(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to tune: $e")),
        );
      }
    }
  }

  void _saveCurrentMemories() async {
    if (_channels == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No channels loaded to save.")),
        );
        return;
    }
    final TextEditingController nameController = TextEditingController();

    final String? name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Save Memories Backup"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: "Name for backup",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.of(ctx).pop(nameController.text.trim());
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> channelsJson = _channels!.map((c) => c.toJson()).toList();
      final jsonString = json.encode(channelsJson);
      await prefs.setString('memory_backup_$name', jsonString);
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Saved backup as '$name'")),
        );
      }
      await _loadAllMemoryLists();
    }
  }

  void _enterMemorySelectionMode() {
    setState(() {
      _isSelectingMemory = true;
    });
  }

  Future<void> _loadMemoriesToRadio(List<Channel> channelsToLoad, String name) async {
    if (_radioController == null) return;

    setState(() {
      _isLoading = true;
      _isSelectingMemory = false;
      _statusMessage = 'Writing ${channelsToLoad.length} channels from "$name"...';
    });

    try {
      for (final channel in channelsToLoad) {
        await _radioController!.writeChannel(channel);
        await Future.delayed(const Duration(milliseconds: 60));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Finished writing memories: '$name'")),
        );
        await _loadAllChannels();
      }
    } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error writing memories: $e")),
          );
        }
    } finally {
      if(mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _importNearbyRepeaters() async {
    if (_radioController == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connect to a radio first.")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Finding nearby repeaters...';
    });

    try {
      geolocator.Position position;
      if (kDebugMode && gpsSourceNotifier.value == GpsSource.debug) {
        position = LocationService.debugPosition;
      } else {
        position = await locationService.determinePosition();
      }

      final repeaterService = RepeaterBookService();
      final repeaters = await repeaterService.getRepeatersNearby(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (repeaters.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No nearby repeaters found.")),
          );
        }
        return;
      }

      final channelsToWrite = <Channel>[];
      for (int i = 0; i < repeaters.length; i++) {
        channelsToWrite.add(repeaters[i].toChannel(i));
      }

      for (int i = 0; i < channelsToWrite.length; i++) {
        if (mounted) {
          setState(() {
            _statusMessage = 'Writing channel ${i + 1}/${channelsToWrite.length}...';
          });
        }
        await _radioController!.writeChannel(channelsToWrite[i]);
        await Future.delayed(const Duration(milliseconds: 60));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${channelsToWrite.length} channels imported successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error during import: $e")),
        );
      }
    } finally {
      await _loadAllChannels();
    }
  }


  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RadioController?>(
      valueListenable: radioControllerNotifier,
      builder: (context, radioController, _) {
        return MainLayout(
          radioController: radioController,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
                  const SizedBox(height: 22),
                  _buildHeader(context, constraints.maxWidth),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _isLoading
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 16),
                                Text(_statusMessage, style: Theme.of(context).textTheme.titleMedium),
                              ],
                            ),
                          )
                        : _isSelectingMemory
                            ? _buildMemorySelectionGrid(context)
                            : (_channels == null
                                ? Center(child: Text(_statusMessage, style: Theme.of(context).textTheme.titleMedium))
                                : _buildChannelGrid(context)),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, double gridWidth) {
    final theme = Theme.of(context);
    final maxButtonWidth = (gridWidth / 4).clamp(100.0, 200.0);

    if (_isSelectingMemory) {
      // Header for when the user is picking a memory list to load
      return Row(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxButtonWidth),
            child: SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.cancel),
                onPressed: () => setState(() => _isSelectingMemory = false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.errorContainer,
                  foregroundColor: theme.colorScheme.onErrorContainer,
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                ),
                label: const Text("Cancel"),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Select Memory to Load',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.onBackground,
                  fontWeight: FontWeight.w700,
                  fontSize: 32,
                ),
              ),
            ),
          ),
          // Placeholder to balance the row
          SizedBox(width: maxButtonWidth * 2 + 8),
        ],
      );
    }

    // Normal header for channel tuning/editing
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxButtonWidth),
          child: SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.travel_explore),
              onPressed: _isLoading || !_isInEditMode ? null : _importNearbyRepeaters,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 44),
                backgroundColor: theme.colorScheme.secondaryContainer,
                foregroundColor: theme.colorScheme.onSecondaryContainer,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
              ),
              label: const Text("GPS Import", overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Tooltip(
              message: _isInEditMode
                ? "Tap a channel below to edit its details."
                : "Tap a channel below to tune the radio.",
              child: TextButton.icon(
                onPressed: _isLoading ? null : () => setState(() => _isInEditMode = !_isInEditMode),
                icon: Icon(_isInEditMode ? Icons.check_circle_outline : Icons.track_changes_outlined),
                label: Text(_isInEditMode ? "Edit Mode" : "Tune Mode"),
                style: TextButton.styleFrom(
                  foregroundColor: _isInEditMode ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  backgroundColor: _isInEditMode ? theme.colorScheme.primary.withOpacity(0.12) : theme.cardTheme.color?.withOpacity(0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: const StadiumBorder(),
                  side: BorderSide(color: theme.dividerColor),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxButtonWidth),
              child: SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_alt),
                  onPressed: _isLoading || !_isInEditMode ? null : _saveCurrentMemories,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    foregroundColor: theme.colorScheme.onSecondaryContainer,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                  ),
                  label: const Text("Save Backup", overflow: TextOverflow.ellipsis),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxButtonWidth),
              child: SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.folder_open),
                  onPressed: _isLoading || !_isInEditMode ? null : _enterMemorySelectionMode,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    foregroundColor: theme.colorScheme.onSecondaryContainer,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                  ),
                  label: const Text("Load Memories", overflow: TextOverflow.ellipsis),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMemorySelectionGrid(BuildContext context) {
    const int crossAxisCount = 4;
    const double gridSpacing = 16.0;
    final theme = Theme.of(context);

    if (_allMemoryLists.isEmpty) {
      return const Center(child: Text("No predefined or saved memories found."));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(gridSpacing),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: gridSpacing,
        crossAxisSpacing: gridSpacing,
        childAspectRatio: 2.5,
      ),
      itemCount: _allMemoryLists.length,
      itemBuilder: (context, index) {
        final memoryItem = _allMemoryLists[index];
        final name = memoryItem.keys.first;
        final channels = memoryItem.values.first;
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.cardTheme.color,
            foregroundColor: theme.colorScheme.onSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor),
            ),
          ),
          onPressed: () => _loadMemoriesToRadio(channels, name),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(name, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text("${channels.length} channels", style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        );
      },
    );
  }

  /// MODIFIED: Now uses LayoutBuilder to dynamically size buttons to fit the available space.
  Widget _buildChannelGrid(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final int totalChannels = _channels!.length;
    const int crossAxisCount = 8;
    final int rowCount = (totalChannels / crossAxisCount).ceil();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double gridSpacing = 8.0;

        // Calculate available height, subtracting spacing between rows and a small vertical padding
        final double verticalPadding = gridSpacing;
        final double availableHeight = constraints.maxHeight - (rowCount > 0 ? (rowCount - 1) * gridSpacing : 0) - verticalPadding;

        final double cellHeight = rowCount > 0 ? availableHeight / rowCount : 0;
        final double cellWidth = (constraints.maxWidth - (crossAxisCount > 0 ? (crossAxisCount - 1) * gridSpacing : 0)) / crossAxisCount;

        final double childAspectRatio = (cellHeight > 0 && cellWidth > 0) ? cellWidth / cellHeight : 1.0;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: gridSpacing / 2, vertical: verticalPadding / 2),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: gridSpacing,
            crossAxisSpacing: gridSpacing,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: _channels!.length,
          itemBuilder: (context, index) {
            final channel = _channels![index];
            return GestureDetector(
              onTap: () {
                if (_isInEditMode) {
                  _editChannel(index);
                } else {
                  _tuneToChannel(channel);
                }
              },
              child: _ChannelButton(
                channel: channel,
                isDark: isDark,
                theme: theme,
                buttonHeight: cellHeight,
              ),
            );
          },
        );
      },
    );
  }
}

class _ChannelButton extends StatelessWidget {
  final Channel channel;
  final bool isDark;
  final ThemeData theme;
  final double buttonHeight;
  const _ChannelButton({
    required this.channel,
    required this.isDark,
    required this.theme,
    required this.buttonHeight,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = theme.dividerColor.withOpacity(isDark ? 0.7 : 0.6);
    final titleColor = theme.colorScheme.secondary;
    final textColor = theme.colorScheme.onSurface;
    final subColor = theme.colorScheme.onSurface.withOpacity(0.85);

    return Tooltip(
      message: '${channel.name.trim()}\n${channel.rxFreq} MHz',
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? (isDark ? const Color(0xFF181C1F) : Colors.white),
          borderRadius: BorderRadius.circular(buttonHeight * 0.18),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'CH ${channel.channelId + 1}',
                style: TextStyle(fontSize: buttonHeight * 0.18, fontWeight: FontWeight.bold, color: titleColor),
              ),
              const SizedBox(height: 2),
              Text(
                channel.name.trim().isEmpty ? '[empty]' : channel.name.trim(),
                style: TextStyle(
                  fontSize: buttonHeight * 0.16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  overflow: TextOverflow.ellipsis,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
              Text(
                channel.rxFreq == 0.0 ? '- - -' : channel.rxFreq.toStringAsFixed(2),
                style: TextStyle(fontSize: buttonHeight * 0.15, fontWeight: FontWeight.w500, color: subColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _ChannelEditor extends StatefulWidget {
  final Channel channel;
  const _ChannelEditor({required this.channel});
  @override
  State<_ChannelEditor> createState() => _ChannelEditorState();
}

class _ChannelEditorState extends State<_ChannelEditor> {
  late TextEditingController _nameController;
  late TextEditingController _rxFreqController;
  late TextEditingController _txFreqController;
  late TextEditingController _rxToneController;
  late TextEditingController _txToneController;
  late ModulationType _rxMod;
  late ModulationType _txMod;
  late BandwidthType _bandwidth;
  late String _power;
  late String _rxToneType;
  late String _txToneType;
  late bool _scan;
  late bool _txDisable;
  late bool _talkAround;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final c = widget.channel;
    _rxMod = c.rxMod;
    _txMod = c.txMod;
    _bandwidth = c.bandwidth;
    _power = c.txPower;
    _scan = c.scan;
    _txDisable = c.txDisable;
    _talkAround = c.talkAround;
    _rxToneType = c.rxSubAudio == null ? 'None' : (c.rxSubAudio is int ? 'DCS' : 'CTCSS');
    _txToneType = c.txSubAudio == null ? 'None' : (c.txSubAudio is int ? 'DCS' : 'CTCSS');
    _nameController = TextEditingController(text: c.name);
    _rxFreqController = TextEditingController(text: c.rxFreq.toString());
    _txFreqController = TextEditingController(text: c.txFreq.toString());
    _rxToneController = TextEditingController(text: c.rxSubAudio?.toString() ?? '');
    _txToneController = TextEditingController(text: c.txSubAudio?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rxFreqController.dispose();
    _txFreqController.dispose();
    _rxToneController.dispose();
    _txToneController.dispose();
    super.dispose();
  }

  void _saveForm() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      dynamic parseSubAudio(String type, String value) {
        if (type == 'None' || value.isEmpty) return null;
        if (type == 'DCS') return int.tryParse(value);
        if (type == 'CTCSS') return double.tryParse(value);
        return null;
      }
      final updatedChannel = widget.channel.copyWith(
          name: _nameController.text,
          rxFreq: double.tryParse(_rxFreqController.text),
          txFreq: double.tryParse(_txFreqController.text),
          rxMod: _rxMod,
          txMod: _txMod,
          bandwidth: _bandwidth,
          txAtMaxPower: _power == 'High',
          txAtMedPower: _power == 'Medium',
          rxSubAudio: parseSubAudio(_rxToneType, _rxToneController.text),
          txSubAudio: parseSubAudio(_txToneType, _txToneController.text),
          scan: _scan,
          txDisable: _txDisable,
          talkAround: _talkAround,
      );
      Navigator.of(context).pop(updatedChannel);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
            return Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Form(
                    key: _formKey,
                    child: Column(
                        children: [
                            Text('Edit Channel ${widget.channel.channelId + 1}', style: theme.textTheme.headlineSmall),
                            const SizedBox(height: 16),
                            Expanded(
                                child: ListView(
                                    controller: scrollController,
                                    children: [
                                        _buildTextFormField(_nameController, 'Name', maxLength: 10),
                                        _buildFreqFormField(_rxFreqController, 'RX Frequency (MHz)'),
                                        _buildFreqFormField(_txFreqController, 'TX Frequency (MHz)'),
                                        _buildDropdown('RX Modulation', _rxMod, ModulationType.values, (val) => setState(() => _rxMod = val)),
                                        _buildDropdown('TX Modulation', _txMod, ModulationType.values, (val) => setState(() => _txMod = val)),
                                        _buildDropdown('Bandwidth', _bandwidth, BandwidthType.values, (val) => setState(() => _bandwidth = val)),
                                        _buildDropdown('Power', _power, ['High', 'Medium', 'Low'], (val) => setState(() => _power = val)),
                                        _buildToneEditor('RX Tone', _rxToneType, _rxToneController, (val) => setState(() => _rxToneType = val)),
                                        _buildToneEditor('TX Tone', _txToneType, _txToneController, (val) => setState(() => _txToneType = val)),
                                        const SizedBox(height: 8),
                                        _buildSwitch('Add to Scan List', _scan, (val) => setState(() => _scan = val)),
                                        _buildSwitch('Disable Transmit', _txDisable, (val) => setState(() => _txDisable = val)),
                                        _buildSwitch('Talkaround (Repeater Bypass)', _talkAround, (val) => setState(() => _talkAround = val)),
                                    ],
                                ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                        icon: const Icon(Icons.save),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        ),
                                        onPressed: _saveForm,
                                        label: const Text('Save'),
                                    ),
                                ],
                            ),
                        ],
                    ),
                ),
            );
        },
    );
  }

  Widget _buildTextFormField(TextEditingController controller, String label, {int? maxLength}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        maxLength: maxLength,
        validator: (value) => value == null || value.isEmpty ? 'This field cannot be empty' : null,
      ),
    );
  }

  Widget _buildFreqFormField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
        validator: (value) {
          if (value == null || value.isEmpty) return 'Cannot be empty.';
          if (double.tryParse(value) == null) return 'Invalid number format.';
          return null;
        },
      ),
    );
  }

  Widget _buildDropdown<T>(String label, T currentValue, List<T> items, ValueChanged<T> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<T>(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        value: currentValue,
        items: items.map((T value) {
          return DropdownMenuItem<T>(
            value: value,
            child: Text(value is Enum ? value.name : value.toString()),
          );
        }).toList(),
        onChanged: (T? newValue) {
          if (newValue != null) { onChanged(newValue); }
        },
      ),
    );
  }

  Widget _buildToneEditor(String label, String currentType, TextEditingController controller, ValueChanged<String> onTypeChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: _buildDropdown(label, currentType, ['None', 'CTCSS', 'DCS'], onTypeChanged),
          ),
          if (currentType != 'None') ...[
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: currentType == 'CTCSS' ? 'Tone (Hz)' : 'Code',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    currentType == 'CTCSS' ? RegExp(r'[\d.]') : RegExp(r'[\d]')
                  )
                ],
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSwitch(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

extension ChannelUIHelpers on Channel {
    String get txPower {
        if (txAtMaxPower) return "High";
        if (txAtMedPower) return "Medium";
        return "Low";
    }
    static String getFormattedSubAudio(dynamic val) {
        if (val == null) return "None";
        if (val is int) return 'DCS $val';
        if (val is double) return '${val.toStringAsFixed(1)} Hz';
        return "Unknown";
    }
}