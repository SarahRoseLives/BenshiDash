import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../benshi/radio_controller.dart';
import '../../../main.dart';
import '../../widgets/main_layout.dart';

class VfoScanScreen extends StatelessWidget {
  const VfoScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RadioController?>(
      valueListenable: radioControllerNotifier,
      builder: (context, radioController, _) {
        return MainLayout(
          radioController: radioController,
          child: radioController == null
              ? const Center(child: Text("Connect to a radio to use VFO Scan."))
              : const _VfoScanContent(),
        );
      },
    );
  }
}

class _VfoScanContent extends StatefulWidget {
  const _VfoScanContent();

  @override
  State<_VfoScanContent> createState() => _VfoScanContentState();
}

class _VfoScanContentState extends State<_VfoScanContent> {
  RadioController? _radioController;
  final _formKey = GlobalKey<FormState>();

  final _startFreqController = TextEditingController(text: '144.000');
  final _endFreqController = TextEditingController(text: '148.000');
  num _stepKhz = 25;

  TextEditingController? _activeController;

  @override
  void initState() {
    super.initState();
    _radioController = radioControllerNotifier.value;
    _radioController?.addListener(_onRadioUpdate);
    _activeController = _startFreqController;
  }

  @override
  void dispose() {
    _radioController?.removeListener(_onRadioUpdate);
    _radioController?.stopVfoScan();
    _startFreqController.dispose();
    _endFreqController.dispose();
    super.dispose();
  }

  void _onRadioUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _toggleScan() {
    if (_radioController == null) return;

    if (_radioController!.isVfoScanning) {
      _radioController!.stopVfoScan();
    } else {
      if (_formKey.currentState!.validate()) {
        final double? startFreq = double.tryParse(_startFreqController.text);
        final double? endFreq = double.tryParse(_endFreqController.text);

        if (startFreq == null || endFreq == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please enter valid start and end frequencies."))
          );
          return;
        }

        _radioController!.startVfoScan(
          startFreqMhz: startFreq,
          endFreqMhz: endFreq,
          stepKhz: _stepKhz,
        );
      }
    }
  }

  void _onNumpadPress(String value) {
    if (_activeController == null) return;

    final currentText = _activeController!.text;
    if (value == 'DEL') {
      if (currentText.isNotEmpty) {
        _activeController!.text = currentText.substring(0, currentText.length - 1);
      }
    } else {
      _activeController!.text = currentText + value;
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isScanning = _radioController?.isVfoScanning ?? false;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('VFO Scanner', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 24),
                _buildTextField(_startFreqController, 'Start Freq (MHz)'),
                const SizedBox(height: 16),
                _buildTextField(_endFreqController, 'End Freq (MHz)'),
                const SizedBox(height: 24),
                _buildStepSelector(theme),
                const Spacer(),
                SizedBox(
                  height: 60,
                  child: ElevatedButton.icon(
                    icon: Icon(isScanning ? Icons.stop_circle_outlined : Icons.play_circle_outline, size: 32),
                    label: Text(isScanning ? 'Stop Scan' : 'Start Scan', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white)),
                    onPressed: _toggleScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isScanning ? Colors.redAccent.shade400 : Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Card(
                    elevation: 4,
                    color: isScanning ? theme.colorScheme.primaryContainer : theme.cardTheme.color,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                        child: Text(
                          '${_radioController?.currentVfoFrequencyMhz.toStringAsFixed(4) ?? "---.----"} MHz',
                          style: theme.textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isScanning ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _Numpad(onTap: _onNumpadPress),
                  ),
                ],
              ),
            ),
          )
        )
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    bool isActive = _activeController == controller;
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () => setState(() => _activeController = controller),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: isActive ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : null,
      ),
      style: Theme.of(context).textTheme.headlineSmall,
    );
  }

  Widget _buildStepSelector(ThemeData theme) {
    final steps = [5, 10, 12.5, 25, 50, 100];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Step Size (kHz)", style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: steps.map((step) {
            bool isSelected = _stepKhz == step;
            return ChoiceChip(
              label: Text('$step kHz'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              labelStyle: TextStyle(
                fontSize: 16,
                color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _stepKhz = step);
                }
              },
              selectedColor: theme.colorScheme.primary,
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Numpad extends StatelessWidget {
  final Function(String) onTap;
  const _Numpad({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final buttons = [
      '1', '2', '3',
      '4', '5', '6',
      '7', '8', '9',
      '.', '0', 'DEL',
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const double crossAxisSpacing = 10;
        const double mainAxisSpacing = 10;
        const double topPadding = 16;
        const int crossAxisCount = 3;
        const int rowCount = 4;

        final double cellWidth = (constraints.maxWidth - (crossAxisCount - 1) * crossAxisSpacing) / crossAxisCount;
        final double cellHeight = (constraints.maxHeight - (rowCount - 1) * mainAxisSpacing - topPadding) / rowCount;

        final double childAspectRatio = (cellHeight > 0) ? (cellWidth / cellHeight) : 1.0;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: topPadding),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: mainAxisSpacing,
          ),
          itemCount: buttons.length,
          itemBuilder: (context, index) {
            final buttonText = buttons[index];
            return ElevatedButton(
              onPressed: () => onTap(buttonText),
              style: ElevatedButton.styleFrom(
                textStyle: Theme.of(context).textTheme.headlineMedium,
                backgroundColor: buttonText == 'DEL' ? Colors.red.shade200 : null,
              ),
              child: Text(buttonText),
            );
          },
        );
      },
    );
  }
}