import 'package:benshidash/ui/screens/scan/vfo_scan_screen.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../../../benshi/radio_controller.dart';
import '../../../benshi/protocol/protocol.dart';
import '../../../main.dart'; // To get the global notifier
import '../home/dashboard.dart';
import '../../widgets/main_layout.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<Channel>? _channels;
  bool _isLoading = true;
  String _statusMessage = '';
  RadioController? _radioController;

  @override
  void initState() {
    super.initState();
    _radioController = radioControllerNotifier.value;
    radioControllerNotifier.addListener(_onControllerChange);

    if (_radioController != null) {
      _radioController!.addListener(_onRadioUpdate);
      _loadAllChannels();
    } else {
      // --- MODIFIED: Never display a message to connect radio, just load the screen ---
      setState(() {
        _isLoading = false;
        _statusMessage = ''; // No message about connecting
      });
    }
  }

  @override
  void dispose() {
    radioControllerNotifier.removeListener(_onControllerChange);
    _radioController?.removeListener(_onRadioUpdate);
    super.dispose();
  }

  void _onControllerChange() {
    _radioController?.removeListener(_onRadioUpdate);
    setState(() {
      _radioController = radioControllerNotifier.value;
    });
    if (_radioController != null) {
      _radioController!.addListener(_onRadioUpdate);
      _loadAllChannels();
    } else {
      // --- MODIFIED: Never display a message to connect radio, just load the screen ---
      setState(() {
        _isLoading = false;
        _channels = null; // Clear channels on disconnect
        _statusMessage = ''; // No message about connecting
      });
    }
  }

  void _onRadioUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadAllChannels() async {
    if (!mounted || _radioController == null) {
      // This case is handled by initState and _onControllerChange
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

  Future<void> _toggleChannel(Channel channel) async {
    if (_radioController == null) return;

    final originalScanState = channel.scan;
    setState(() {
      final index = _channels?.indexWhere((c) => c.channelId == channel.channelId);
      if (index != null && index != -1) {
        _channels![index] = channel.copyWith(scan: !originalScanState);
      }
    });

    try {
      final updatedChannel = channel.copyWith(scan: !originalScanState);
      await _radioController!.writeChannel(updatedChannel);
    } catch (e) {
      if (mounted) {
        setState(() {
          final index = _channels?.indexWhere((c) => c.channelId == channel.channelId);
          if (index != null && index != -1) {
            _channels![index] = channel.copyWith(scan: originalScanState);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error updating channel: $e")));
      }
    }
  }

  Future<void> _bulkUpdateScanList(bool selectAll) async {
    if (_channels == null || _radioController == null) return;

    setState(() {
      _isLoading = true;
      _statusMessage = selectAll ? 'Adding all channels to scan list...' : 'Removing all channels...';
    });

    try {
      for (final channel in _channels!) {
        if (channel.scan != selectAll) {
          final updatedChannel = channel.copyWith(scan: selectAll);
          await _radioController!.writeChannel(updatedChannel);
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("An error occurred during bulk update: $e"))
        );
      }
    } finally {
      await _loadAllChannels();
    }
  }

  Future<void> _toggleMasterScan() async {
    if (_isLoading || _radioController == null) return;

    setState(() => _isLoading = true);

    try {
      await _radioController!.setRadioScan(!_radioController!.isScan);
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error toggling scan: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // --- MODIFIED: Check connection status once ---
    final bool isConnected = _radioController != null;
    final bool isScanning = isConnected && (_radioController?.isScan ?? false);
    final bool canInteract = isConnected && !_isLoading;

    Widget content;

    if (_isLoading) {
      content = _buildLoadingView();
    } else if (!isConnected || _channels == null || _channels!.isEmpty) {
      content = _buildErrorView(_statusMessage);
    } else {
      content = _buildChannelGrid(context);
    }

    return ValueListenableBuilder<RadioController?>(
      valueListenable: radioControllerNotifier,
      builder: (context, radioController, _) {
        return MainLayout(
          radioController: radioController,
          radio: radio,
          battery: battery,
          gps: gps,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    ElevatedButton(
                      onPressed: canInteract ? () => _bulkUpdateScanList(true) : null,
                      style: ElevatedButton.styleFrom(
                        shape: const StadiumBorder(),
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        foregroundColor: theme.colorScheme.onSecondaryContainer,
                        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      child: const Text("Select All"),
                    ),
                    Expanded(
                      child: Center(
                        child: ElevatedButton.icon(
                          icon: Icon(isScanning ? Icons.stop_circle_outlined : Icons.play_circle_outline),
                          label: Text(isScanning ? 'Stop Memory Scan' : 'Start Memory Scan'),
                          onPressed: canInteract ? _toggleMasterScan : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isScanning ? Colors.redAccent : Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.waves),
                      label: const Text('VFO Scan Mode'),
                      onPressed: canInteract ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const VfoScanScreen()),
                        );
                      } : null,
                      style: ElevatedButton.styleFrom(
                        shape: const StadiumBorder(),
                        backgroundColor: theme.colorScheme.primaryContainer,
                        foregroundColor: theme.colorScheme.onPrimaryContainer,
                        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: canInteract ? () => _bulkUpdateScanList(false) : null,
                      style: ElevatedButton.styleFrom(
                        shape: const StadiumBorder(),
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        foregroundColor: theme.colorScheme.onSecondaryContainer,
                        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      child: const Text("Deselect All"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChannelGrid(BuildContext context) {
    final int totalChannels = _channels?.length ?? 0;
    final int crossAxisCount = 8;
    final int rowCount = (totalChannels / crossAxisCount).ceil();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double gridSpacing = 8;
        final double availableHeight = constraints.maxHeight - (rowCount - 1) * gridSpacing;
        final double cellHeight = availableHeight / rowCount;
        final double cellWidth = (constraints.maxWidth - (crossAxisCount - 1) * gridSpacing) / crossAxisCount;
        final double childAspectRatio = cellWidth / cellHeight;

        return GridView.builder(
          padding: EdgeInsets.symmetric(horizontal: gridSpacing),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: gridSpacing,
            crossAxisSpacing: gridSpacing,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: totalChannels,
          itemBuilder: (context, index) {
            final channel = _channels![index];
            final isActive = channel.scan;
            final theme = Theme.of(context);

            return LayoutBuilder(
              builder: (context, constraints) {
                final buttonSize = constraints.maxWidth;
                return GestureDetector(
                  onTap: () => _toggleChannel(channel),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: isActive ? theme.colorScheme.secondary : theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(buttonSize * 0.2),
                      border: Border.all(color: theme.dividerColor, width: 1.2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'CH ${channel.channelId + 1}',
                            style: TextStyle(
                              fontSize: buttonSize * 0.15,
                              fontWeight: FontWeight.bold,
                              color: isActive ? theme.colorScheme.onSecondary.withOpacity(0.8) : theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            channel.name.trim().isEmpty ? 'Empty' : channel.name.trim(),
                            style: TextStyle(
                              fontSize: buttonSize * 0.18,
                              fontWeight: FontWeight.bold,
                              color: isActive ? theme.colorScheme.onSecondary : theme.colorScheme.onSurface.withOpacity(0.9),
                              overflow: TextOverflow.ellipsis,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${channel.rxFreq.toStringAsFixed(3)}',
                            style: TextStyle(
                              fontSize: buttonSize * 0.15,
                              fontWeight: FontWeight.w500,
                              color: isActive ? theme.colorScheme.onSecondary.withOpacity(0.9) : theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(_statusMessage, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  Widget _buildErrorView(String message) {
    // --- MODIFIED: Never display a message to connect the radio, just load the screen ---
    final bool showRetry = _radioController != null && _channels == null && (message.isNotEmpty && !message.toLowerCase().contains('connect'));
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.radio, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              message,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          if (showRetry)
            ElevatedButton(onPressed: _loadAllChannels, child: const Text('Retry')),
        ],
      ),
    );
  }
}