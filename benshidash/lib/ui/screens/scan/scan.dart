import 'package:flutter/material.dart';
import '../home/dashboard.dart';
import '../../widgets/main_layout.dart';

// Example data for 32 real radio channels
class RadioChannel {
  final String name;
  final String modulation; // "AM", "FM", "NFM"
  final String frequency; // e.g. "118.00 MHz"

  const RadioChannel(this.name, this.modulation, this.frequency);
}

// 32 realistic aviation, marine, and public service channels
const List<RadioChannel> channels = [
  RadioChannel("ATIS", "AM", "118.00 MHz"),
  RadioChannel("Ground Control", "AM", "121.90 MHz"),
  RadioChannel("Tower", "AM", "119.10 MHz"),
  RadioChannel("Departure", "AM", "123.70 MHz"),
  RadioChannel("Approach", "AM", "124.50 MHz"),
  RadioChannel("Center (ARTCC)", "AM", "133.55 MHz"),
  RadioChannel("Unicom", "AM", "122.80 MHz"),
  RadioChannel("CTAF", "AM", "122.90 MHz"),
  RadioChannel("Clearance Delivery", "AM", "121.60 MHz"),
  RadioChannel("Company Ops", "AM", "131.00 MHz"),
  RadioChannel("Flight Service", "AM", "122.20 MHz"),
  RadioChannel("AWOS", "AM", "118.50 MHz"),
  RadioChannel("Helicopter", "AM", "123.025 MHz"),
  RadioChannel("Emergency Guard", "AM", "121.50 MHz"),
  RadioChannel("Marine VHF Ch. 16", "FM", "156.80 MHz"),
  RadioChannel("Marine VHF Ch. 13", "FM", "156.65 MHz"),
  RadioChannel("NOAA Weather 1", "FM", "162.400 MHz"),
  RadioChannel("NOAA Weather 2", "FM", "162.425 MHz"),
  RadioChannel("NOAA Weather 3", "FM", "162.450 MHz"),
  RadioChannel("Railroad Ch. 1", "NFM", "160.800 MHz"),
  RadioChannel("Railroad Ch. 2", "NFM", "161.100 MHz"),
  RadioChannel("Fire Dispatch", "NFM", "154.430 MHz"),
  RadioChannel("EMS Dispatch", "NFM", "155.340 MHz"),
  RadioChannel("Police Dispatch", "NFM", "155.700 MHz"),
  RadioChannel("Search & Rescue", "NFM", "155.160 MHz"),
  RadioChannel("HAM 2m Simplex", "FM", "146.520 MHz"),
  RadioChannel("HAM 70cm Simplex", "FM", "446.000 MHz"),
  RadioChannel("GMRS Channel 1", "FM", "462.5625 MHz"),
  RadioChannel("FRS Channel 1", "FM", "462.5625 MHz"),
  RadioChannel("MURS Ch. 1", "FM", "151.820 MHz"),
  RadioChannel("Business Band", "NFM", "464.500 MHz"),
  RadioChannel("Weather Spotter", "FM", "146.940 MHz"),
];

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  // Track which channels are enabled for scanning
  final List<bool> _channelActive = List<bool>.filled(32, false);

  void _toggleChannel(int index) {
    setState(() {
      _channelActive[index] = !_channelActive[index];
    });
  }

  void _selectAll() {
    setState(() {
      for (int i = 0; i < _channelActive.length; i++) {
        _channelActive[i] = true;
      }
    });
  }

  void _deselectAll() {
    setState(() {
      for (int i = 0; i < _channelActive.length; i++) {
        _channelActive[i] = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 8 columns x 4 rows
    final int crossAxisCount = 8;
    final double gridSpacing = 8;
    final Size size = MediaQuery.of(context).size;

    // This calculation remains to make the content inside the buttons responsive
    final double availableWidth = size.width - (gridSpacing * (crossAxisCount + 1));
    final double buttonSize = (availableWidth / crossAxisCount).clamp(36.0, 64.0);

    final theme = Theme.of(context);

    return MainLayout(
      radio: radio,
      battery: battery,
      gps: gps,
      child: Column(
        children: [
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                // Left button
                ElevatedButton(
                  onPressed: _selectAll,
                  style: ElevatedButton.styleFrom(
                    shape: const StadiumBorder(),
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    foregroundColor: theme.colorScheme.onSecondaryContainer,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  child: const Text("Select All"),
                ),
                // Expanded Scan Channels center title
                Expanded(
                  child: Center(
                    child: Text(
                      'Scan Channels',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.onBackground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Right button
                ElevatedButton(
                  onPressed: _deselectAll,
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
          Expanded(
            child: AspectRatio(
              aspectRatio: crossAxisCount / 4,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: gridSpacing),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: gridSpacing,
                  crossAxisSpacing: gridSpacing,
                ),
                itemCount: 32,
                itemBuilder: (context, index) {
                  final isActive = _channelActive[index];
                  final channel = channels[index];
                  return GestureDetector(
                    onTap: () => _toggleChannel(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeInOut,
                      width: buttonSize,
                      height: buttonSize,
                      decoration: BoxDecoration(
                        color: isActive
                            ? theme.colorScheme.secondary
                            : theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(buttonSize * 0.28),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: theme.colorScheme.secondary.withOpacity(0.3),
                                  spreadRadius: 1,
                                  blurRadius: 8,
                                ),
                              ]
                            : (theme.brightness == Brightness.light
                                ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2, offset: const Offset(0, 1))]
                                : []),
                        border: Border.all(
                          color: theme.dividerColor,
                          width: 1.2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              channel.name,
                              style: TextStyle(
                                fontSize: buttonSize * 0.21,
                                fontWeight: FontWeight.bold,
                                color: isActive
                                    ? theme.colorScheme.onSecondary
                                    : theme.colorScheme.onSurface.withOpacity(0.7),
                                overflow: TextOverflow.ellipsis,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? theme.colorScheme.onSecondary.withOpacity(0.2)
                                    : theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                channel.modulation,
                                style: TextStyle(
                                  fontSize: buttonSize * 0.15,
                                  fontWeight: FontWeight.w600,
                                  color: isActive
                                      ? theme.colorScheme.onSecondary
                                      : theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              channel.frequency,
                              style: TextStyle(
                                fontSize: buttonSize * 0.16,
                                fontWeight: FontWeight.w500,
                                color: isActive
                                    ? theme.colorScheme.onSecondary
                                    : theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}