import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../benshi/protocol/protocol.dart';
import '../home/dashboard.dart';
import '../../widgets/main_layout.dart';

import '../../../benshi/radio_controller.dart';
import '../../../main.dart'; // To get the global notifier

List<Channel> generateMockChannels() {
  return List.generate(32, (index) {
    bool isAm = index < 4;
    bool isFm = !isAm && index < 20;

    return Channel(
      channelId: index,
      name: 'Channel_${index + 1}',
      txMod: isAm ? ModulationType.AM : ModulationType.FM,
      rxMod: isAm ? ModulationType.AM : ModulationType.FM,
      txFreq: 462.5625 + (index * 0.0125),
      rxFreq: 462.5625 + (index * 0.0125),
      txSubAudio: index % 5 == 0 ? 100.0 : null,
      rxSubAudio: index % 7 == 0 ? 123 : null,
      txAtMaxPower: index % 3 == 0,
      txAtMedPower: index % 3 == 1,
      bandwidth: isFm ? BandwidthType.WIDE : BandwidthType.NARROW,
      scan: index % 2 == 0,
      talkAround: index % 8 == 0,
      txDisable: index == 31,
    );
  });
}

final List<Map<String, List<Channel>>> predefinedMemories = [
  { "Family Trip": generateMockChannels() },
  { "Bay Area Repeaters": generateMockChannels() },
  { "Work Channels": generateMockChannels() },
];

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  late List<Channel> _channels;
  final List<Map<String, List<Channel>>> _savedMemories = [];

  @override
  void initState() {
    super.initState();
    _channels = generateMockChannels();
  }

  void _editChannel(int index) async {
    final Channel? updatedChannel = await showModalBottomSheet<Channel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChannelEditor(channel: _channels[index]),
    );

    if (updatedChannel != null) {
      setState(() {
        _channels[index] = updatedChannel;
      });
    }
  }

  void _saveCurrentMemories() async {
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
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
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
      setState(() {
        _savedMemories.add({name: List<Channel>.from(_channels)});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Saved backup as '$name'")),
        );
      });
    }
  }

  void _showLoadMemoriesDialog() async {
    final List<Map<String, List<Channel>>> allMemories = [
      ...predefinedMemories,
      ..._savedMemories,
    ];

    final List<String> memoryNames = allMemories.map((mem) => mem.keys.first).toList();

    final int? selected = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Load Memories"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: memoryNames.length,
            itemBuilder: (context, idx) => ListTile(
              title: Text(memoryNames[idx]),
              trailing: Icon(Icons.download),
              onTap: () => Navigator.of(ctx).pop(idx),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );

    if (selected != null && selected >= 0 && selected < allMemories.length) {
      setState(() {
        _channels = List<Channel>.from(allMemories[selected].values.first);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Loaded memories: '${allMemories[selected].keys.first}'")),
        );
      });
    }
  }

  void _showImportRepeaterBook() async {
    final importedChannels = await showModalBottomSheet<List<Channel>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _RepeaterBookImportSheet(),
    );
    if (importedChannels != null && importedChannels.isNotEmpty) {
      setState(() {
        for (int i = 0; i < importedChannels.length && i < _channels.length; i++) {
          _channels[i] = importedChannels[i];
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Imported channels from RepeaterBook (mock).")),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    const int crossAxisCount = 8;
    const int rowCount = 4;
    const double gridSpacing = 8.0;

    // Listen for connection status changes from the global notifier
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double gridWidth = constraints.maxWidth;
              final double gridHeight = constraints.maxHeight;
              final double availableWidth = gridWidth - (gridSpacing * (crossAxisCount + 1));
              final double availableHeight = gridHeight - (gridSpacing * (rowCount + 1));
              final double buttonWidth = (availableWidth / crossAxisCount).clamp(36.0, 96.0);
              final double buttonHeight = (availableHeight / rowCount).clamp(36.0, 96.0);
              final double childAspectRatio = buttonWidth / buttonHeight;
              final double maxButtonWidth = buttonWidth * 1.5;

              return Column(
                children: [
                  const SizedBox(height: 22),
                  SizedBox(
                    width: gridWidth,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: maxButtonWidth,
                          ),
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.import_export),
                              onPressed: _showImportRepeaterBook,
                              style: ElevatedButton.styleFrom(
                                minimumSize: Size(0, 44),
                                backgroundColor: theme.colorScheme.secondaryContainer,
                                foregroundColor: theme.colorScheme.onSecondaryContainer,
                                shape: const StadiumBorder(),
                                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                              ),
                              label: const Text("GPS Import", overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Center(
                            child: Text(
                              'Channel Programming',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: theme.colorScheme.onBackground,
                                fontWeight: FontWeight.w700,
                                fontSize: 32,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: maxButtonWidth,
                              ),
                              child: SizedBox(
                                height: 44,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.save_alt),
                                  onPressed: _saveCurrentMemories,
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: Size(0, 44),
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
                              constraints: BoxConstraints(
                                maxWidth: maxButtonWidth,
                              ),
                              child: SizedBox(
                                height: 44,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.folder_open),
                                  onPressed: _showLoadMemoriesDialog,
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: Size(0, 44),
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
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SizedBox(
                      width: gridWidth,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: gridSpacing),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: gridSpacing,
                          crossAxisSpacing: gridSpacing,
                          childAspectRatio: childAspectRatio,
                        ),
                        itemCount: 32,
                        itemBuilder: (context, index) {
                          final channel = _channels[index];
                          return GestureDetector(
                            onTap: () => _editChannel(index),
                            child: _ChannelButton(
                              channel: channel,
                              isDark: isDark,
                              theme: theme,
                              buttonHeight: buttonHeight,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
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
          border: Border.all(
            color: borderColor,
            width: 1.2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'CH ${channel.channelId + 1}',
                style: TextStyle(
                  fontSize: buttonHeight * 0.18,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                channel.name.trim(),
                style: TextStyle(
                  fontSize: buttonHeight * 0.16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  overflow: TextOverflow.ellipsis,
                  decoration: TextDecoration.underline,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
              Text(
                channel.rxFreq.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: buttonHeight * 0.15,
                  fontWeight: FontWeight.w500,
                  color: subColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- MOCK REPEATERBOOK IMPORT SHEET ---
// (No changes needed for theme adaptation, so omitted for brevity. See previous versions.)

class _RepeaterBookImportSheet extends StatefulWidget {
  const _RepeaterBookImportSheet();

  @override
  State<_RepeaterBookImportSheet> createState() => _RepeaterBookImportSheetState();
}

class _RepeaterBookImportSheetState extends State<_RepeaterBookImportSheet> {
  final List<_MockRepeater> _repeaters = [
    _MockRepeater(
      name: "Local 146.940-",
      rxFreq: 146.94,
      txFreq: 146.34,
      rxTone: 100.0,
      txTone: 100.0,
      city: "Springfield",
      band: "2m",
    ),
    _MockRepeater(
      name: "Metropolis 147.120+",
      rxFreq: 147.12,
      txFreq: 147.72,
      rxTone: 123.0,
      txTone: 123.0,
      city: "Metropolis",
      band: "2m",
    ),
    _MockRepeater(
      name: "UHF 443.800+",
      rxFreq: 443.8,
      txFreq: 448.8,
      rxTone: 114.8,
      txTone: 114.8,
      city: "Smallville",
      band: "70cm",
    ),
    _MockRepeater(
      name: "444.925+",
      rxFreq: 444.925,
      txFreq: 449.925,
      rxTone: 131.8,
      txTone: 131.8,
      city: "Shelbyville",
      band: "70cm",
    ),
    _MockRepeater(
      name: "Simplex 146.520",
      rxFreq: 146.52,
      txFreq: 146.52,
      rxTone: null,
      txTone: null,
      city: "Anywhere",
      band: "2m",
    ),
  ];

  final Set<int> _selected = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Import Repeaters (Mock)", style: theme.textTheme.headlineSmall),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _repeaters.length,
                  itemBuilder: (context, i) {
                    final r = _repeaters[i];
                    return CheckboxListTile(
                      value: _selected.contains(i),
                      title: Text('${r.name} (${r.city})'),
                      subtitle: Text('${r.band}  RX: ${r.rxFreq}  TX: ${r.txFreq}'
                          '${r.rxTone != null ? "  Tone: ${r.rxTone}" : ""}'),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selected.add(i);
                          } else {
                            _selected.remove(i);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    onPressed: _selected.isEmpty
                        ? null
                        : () {
                            Navigator.of(context).pop(_selected.map((i) => _repeaters[i].toChannel(i)).toList());
                          },
                    label: const Text('Import Selected'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MockRepeater {
  final String name;
  final double rxFreq;
  final double txFreq;
  final double? rxTone;
  final double? txTone;
  final String city;
  final String band;

  _MockRepeater({
    required this.name,
    required this.rxFreq,
    required this.txFreq,
    this.rxTone,
    this.txTone,
    required this.city,
    required this.band,
  });

  Channel toChannel(int idx) {
    return Channel(
      channelId: idx,
      name: name.padRight(10).substring(0, 10),
      txMod: ModulationType.FM,
      rxMod: ModulationType.FM,
      txFreq: txFreq,
      rxFreq: rxFreq,
      txSubAudio: txTone,
      rxSubAudio: rxTone,
      txAtMaxPower: true,
      txAtMedPower: false,
      bandwidth: BandwidthType.WIDE,
      scan: true,
      talkAround: false,
      txDisable: false,
    );
  }
}

// --- THE EDITOR WIDGET and Helpers remain unchanged below this line ---

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
                                    TextButton(
                                        onPressed: () => Navigator.of(context).pop(),
                                        child: const Text('Cancel'),
                                    ),
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
                            inputFormatters: [FilteringTextInputFormatter.allow(currentType == 'CTCSS' ? RegExp(r'[\d.]') : RegExp(r'[\d]'))],
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