import 'dart:math';
import 'package:flutter/material.dart';
import '../../../benshi/protocol/protocol.dart';
import '../../../benshi/radio_controller.dart';
import '../../../main.dart'; // To get the global notifier
import '../../widgets/main_layout.dart';

// Mock data for demonstration when not connected
const vfoA = {
  "name": "Simplex",
  "channel": 12,
  "tx": "146.520",
  "rx": "146.520",
  "mod": "FM",
  "power": "High",
  "bandwidth": "Wide",
};
const vfoB = {
  "name": "W6XYZ",
  "channel": 34,
  "tx": "147.345+",
  "rx": "147.945",
  "mod": "FM",
  "power": "Med",
  "bandwidth": "Narrow",
};
const battery = {"voltage": 7.8, "percent": 85, "charging": false};
const gps = {
  "locked": true,
  "lat": 37.7749,
  "lon": -122.4194,
  "alt": 22.5,
  "spd": 38.6,
  "heading": 123,
  "utc": "2025-08-08 21:03:57",
  "accuracy": 3.1
};
const radio = {
  "id": "Benshi",
  "model": "Commander Pro",
  "fw": "2.1.7",
  "bt": true,
  "audio": true,
  "scan": true,
  "scanType": "Memory",
  "wx": true,
  "noaa": 7,
  "connected": true,
};

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen for connection status changes from the global notifier
    return ValueListenableBuilder<RadioController?>(
      valueListenable: radioControllerNotifier,
      builder: (context, radioController, _) {
        return MainLayout(
          radio: radio,
          battery: battery,
          gps: gps,
          child: radioController == null || !radioController.isReady
              ? const _NotConnectedView()
              : AnimatedBuilder(
                    animation: radioController,
                    builder: (context, __) {
                      return _DashboardContent(
                        radioController: radioController,
                      );
                    },
                  ),
        );
      },
    );
  }
}

class _NotConnectedView extends StatelessWidget {
  const _NotConnectedView();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bluetooth_disabled, size: 64, color: theme.colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            "Not Connected to Radio",
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            "Go to Settings > Bluetooth to connect.",
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final RadioController radioController;

  const _DashboardContent({required this.radioController});

  @override
  Widget build(BuildContext context) {
    final layout = LayoutData.of(context)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        return _MainPanels(
          radioController: radioController,
          fontScale: layout.scale,
          compact: layout.compact,
          gps: gps,
          radio: radio,
          maxHeight: constraints.maxHeight,
          maxWidth: constraints.maxWidth,
        );
      },
    );
  }
}

class _MainPanels extends StatelessWidget {
  final RadioController radioController;
  final double fontScale;
  final bool compact;
  final Map radio, gps;
  final double maxHeight;
  final double maxWidth;
  const _MainPanels({
    required this.radioController,
    required this.fontScale,
    required this.compact,
    required this.radio,
    required this.gps,
    required this.maxHeight,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    const topFlex = 22.0;
    const middleFlex = 13.0;
    const bottomFlex = 12.0;
    const dividerCount = 2;
    const dividerHeight = 12.0;
    final totalFlex = topFlex + middleFlex + bottomFlex;
    final totalDivider = dividerCount * dividerHeight;
    final usableHeight = maxHeight - totalDivider;

    final topHeight = usableHeight * (topFlex / totalFlex);
    final middleHeight = usableHeight * (middleFlex / totalFlex);
    final bottomHeight = usableHeight * (bottomFlex / totalFlex);

    final contentWidth = maxWidth < 1100 ? maxWidth : 1100.0;

    return Center(
      child: SizedBox(
        width: contentWidth,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            SizedBox(
              height: topHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _VfoPanel(radioController: radioController, isA: true, fontScale: fontScale, compact: compact)),
                  const SizedBox(width: 12),
                  Expanded(child: _VfoPanel(radioController: radioController, isA: false, fontScale: fontScale, compact: compact)),
                ],
              ),
            ),
            SizedBox(height: dividerHeight),
            SizedBox(
              height: middleHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _GPSFollowWidget(fontScale: fontScale, gps: gps)),
                  const SizedBox(width: 10),
                  Expanded(child: _NearbyRepeatersWidget(fontScale: fontScale, maxHeight: middleHeight)),
                ],
              ),
            ),
            SizedBox(height: dividerHeight),
            SizedBox(
              height: bottomHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _APRSWidget(fontScale: fontScale, compact: compact, gps: gps)),
                  const SizedBox(width: 10),
                  Expanded(child: _NOAAWidget(radio: radio, fontScale: fontScale)),
                  const SizedBox(width: 10),
                  Expanded(child: _ScanStatusWidget(radio: radio, fontScale: fontScale)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StyledCard extends StatelessWidget {
  final Widget child;
  final double fontScale;
  final Color? color;
  final EdgeInsets? padding;

  const _StyledCard({required this.child, required this.fontScale, this.color, this.padding});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: color ?? theme.cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24 * fontScale)),
      elevation: theme.cardTheme.elevation,
      shadowColor: theme.cardTheme.shadowColor,
      clipBehavior: Clip.antiAlias,
      child: Container(
        alignment: Alignment.center,
        padding: padding,
        child: child,
      ),
    );
  }
}

class _VfoPanel extends StatelessWidget {
  final RadioController radioController;
  final bool isA;
  final double fontScale;
  final bool compact;

  const _VfoPanel({
    required this.radioController,
    required this.isA,
    required this.fontScale,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceColor = theme.colorScheme.onSurface;

    final Channel? channel = isA ? radioController.channelA : radioController.channelB;
    final StatusExt? status = radioController.status;

    if (channel == null || status == null) {
      return _StyledCard(
        fontScale: fontScale,
        padding: EdgeInsets.all(18.0 * fontScale),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final bool isActiveVfo = (isA && status.doubleChannel == ChannelType.A) || (!isA && status.doubleChannel == ChannelType.B);
    final bool ptt = isActiveVfo && status.isInTx;
    final bool sqOpen = isActiveVfo && (status.isInRx || status.isSq);
    final double rssi = isActiveVfo ? status.rssi : 0.0;

    return _StyledCard(
      fontScale: fontScale,
      padding: EdgeInsets.all(18.0 * fontScale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isA ? "VFO A" : "VFO B",
              style: TextStyle(
                  color: theme.colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 18 * fontScale)),
          SizedBox(height: 6 * fontScale),
          Row(
            children: [
              Text("Ch ${channel.channelId}: ${channel.name}",
                  style: TextStyle(color: onSurfaceColor, fontSize: 17 * fontScale)),
              SizedBox(width: 10 * fontScale),
              Icon(
                ptt ? Icons.record_voice_over : Icons.hearing,
                color: ptt
                    ? theme.colorScheme.error
                    : (sqOpen ? theme.colorScheme.primary : onSurfaceColor.withOpacity(0.3)),
                size: 24 * fontScale,
              ),
            ],
          ),
          SizedBox(height: 7 * fontScale),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("TX: ${channel.txFreq.toStringAsFixed(4)} MHz",
                  style: TextStyle(color: onSurfaceColor.withOpacity(0.7), fontSize: 15 * fontScale)),
              Text("RX: ${channel.rxFreq.toStringAsFixed(4)} MHz",
                  style: TextStyle(color: onSurfaceColor.withOpacity(0.7), fontSize: 15 * fontScale)),
            ],
          ),
          SizedBox(height: 4 * fontScale),
          Row(
            children: [
              _LabelChip("Mod: ${channel.rxMod.name}", fontScale: fontScale),
              SizedBox(width: 8 * fontScale),
              _LabelChip("Pwr: ${channel.txPower}", fontScale: fontScale),
              SizedBox(width: 8 * fontScale),
              _LabelChip(channel.bandwidth.name, fontScale: fontScale),
            ],
          ),
          SizedBox(height: 8 * fontScale),
          _RSSIMeter(rssi: rssi.toInt(), fontScale: fontScale),
        ],
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  final String text;
  final double fontScale;
  const _LabelChip(this.text, {required this.fontScale});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * fontScale, vertical: 2 * fontScale),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8 * fontScale),
      ),
      child: Text(text, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 12 * fontScale)),
    );
  }
}

class _RSSIMeter extends StatelessWidget {
  final int rssi; // 0-100
  final double fontScale;
  const _RSSIMeter({required this.rssi, required this.fontScale});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text("RSSI", style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 12 * fontScale)),
        SizedBox(width: 6 * fontScale),
        Expanded(
          child: LinearProgressIndicator(
            value: rssi / 100,
            backgroundColor: theme.colorScheme.onSurface.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
                rssi > 70 ? Colors.greenAccent.shade400 : (rssi > 40 ? Colors.yellow.shade600 : Colors.redAccent)),
            minHeight: 8 * fontScale,
          ),
        ),
        SizedBox(width: 10 * fontScale),
        Text("$rssi%", style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 12 * fontScale)),
      ],
    );
  }
}

// ---- GPS Follow Widget ----
class _GPSFollowWidget extends StatelessWidget {
  final double fontScale;
  final Map gps;
  const _GPSFollowWidget({required this.fontScale, required this.gps});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool locked = gps['locked'] == true;
    final double lat = gps['lat'] ?? 0;
    final double lon = gps['lon'] ?? 0;
    final double accuracy = gps['accuracy'] ?? 0;

    return _StyledCard(
      fontScale: fontScale,
      padding: EdgeInsets.symmetric(horizontal: 20 * fontScale, vertical: 20 * fontScale),
      child: InkWell(
        borderRadius: BorderRadius.circular(18 * fontScale),
        onTap: () async {
          final result = await showDialog<bool>(
            context: context,
            builder: (ctx) {
              return AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.gps_fixed, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    const Text("Enable GPS Follow?"),
                  ],
                ),
                content: const Text(
                  "Enabling GPS Follow will re-program your radio channels automatically as you travel.\n\n"
                  "Are you sure you want to enable this feature?\n\n"
                  "You may lose any manual programming.",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text("Enable"),
                  ),
                ],
              );
            },
          );
          if (result == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("GPS Follow enabled (mock).")),
            );
          }
        },
        child: Row(
          children: [
            Icon(Icons.gps_fixed, color: theme.colorScheme.primary, size: 36 * fontScale),
            SizedBox(width: 14 * fontScale),
            Text(
              "GPS Follow",
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 18 * fontScale,
              ),
            ),
            SizedBox(width: 18 * fontScale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locked ? "Locked" : "Searching...",
                    style: TextStyle(
                        color: locked
                            ? Colors.green
                            : theme.colorScheme.error,
                        fontWeight: FontWeight.w500,
                        fontSize: 13.5 * fontScale),
                  ),
                  Text(
                    "Lat: ${lat.toStringAsFixed(4)}",
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 12 * fontScale),
                  ),
                  Text(
                    "Lon: ${lon.toStringAsFixed(4)}",
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 12 * fontScale),
                  ),
                  Text(
                    "±${accuracy.toStringAsFixed(1)} m",
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 12 * fontScale),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Nearby Repeaters Widget ----
class _NearbyRepeatersWidget extends StatelessWidget {
  final double fontScale;
  final double maxHeight;
  const _NearbyRepeatersWidget({required this.fontScale, required this.maxHeight});

  // Mock repeater data
  List<Map<String, dynamic>> get _repeaters => [
    {
      "name": "W6DPS",
      "freq": "146.940-",
      "city": "San Francisco",
      "distance": "2.1 mi",
      "tone": "100.0 Hz"
    },
    {
      "name": "K6POU",
      "freq": "147.120+",
      "city": "Oakland",
      "distance": "5.3 mi",
      "tone": "123.0 Hz"
    },
    {
      "name": "N6NFI",
      "freq": "145.230-",
      "city": "Palo Alto",
      "distance": "25 mi",
      "tone": "114.8 Hz"
    },
    {
      "name": "K6MDD",
      "freq": "444.925+",
      "city": "Berkeley",
      "distance": "7.7 mi",
      "tone": "131.8 Hz"
    },
    {
      "name": "W6CX",
      "freq": "147.060+",
      "city": "Walnut Creek",
      "distance": "20.8 mi",
      "tone": "88.5 Hz"
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Estimate the height needed for each repeater row + header
    final headerHeight = 35 * fontScale;
    final rowHeight = 32 * fontScale;
    final padding = 16 * fontScale + 18 * fontScale; // top + bottom
    final availableRows = ((maxHeight - headerHeight - padding) / rowHeight).floor();

    final visibleRepeaters = _repeaters.take(availableRows).toList();

    return _StyledCard(
      fontScale: fontScale,
      padding: EdgeInsets.symmetric(horizontal: 18 * fontScale, vertical: 16 * fontScale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.broadcast_on_home, color: theme.colorScheme.primary, size: 28 * fontScale),
              SizedBox(width: 10 * fontScale),
              Text(
                "Nearby Repeaters",
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 16 * fontScale,
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * fontScale),
          for (final r in visibleRepeaters)
            Padding(
              padding: EdgeInsets.only(bottom: 7 * fontScale),
              child: Row(
                children: [
                  Icon(Icons.radio, size: 19 * fontScale, color: theme.colorScheme.secondary),
                  SizedBox(width: 7 * fontScale),
                  Expanded(
                    child: Text(
                      "${r['freq']} • ${r['name']} (${r['city']})",
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                        fontSize: 13.5 * fontScale,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 7 * fontScale),
                  Text(
                    r['distance'],
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 12 * fontScale,
                    ),
                  ),
                  SizedBox(width: 7 * fontScale),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 7 * fontScale, vertical: 2.5 * fontScale),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withOpacity(0.09),
                      borderRadius: BorderRadius.circular(8 * fontScale),
                    ),
                    child: Text(
                      r['tone'],
                      style: TextStyle(
                        color: theme.colorScheme.secondary,
                        fontSize: 11 * fontScale,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BandScopeWidget extends StatelessWidget {
  final double fontScale;
  final bool compact;
  const _BandScopeWidget({required this.fontScale, required this.compact});
  @override
  Widget build(BuildContext context) {
    return _StyledCard(
      fontScale: fontScale,
      padding: EdgeInsets.all(10 * fontScale),
      child: CustomPaint(
        size: const Size(double.infinity, double.infinity),
        painter: _BandScopePainter(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _BandScopePainter extends CustomPainter {
  final Color color;
  _BandScopePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.7)
      ..strokeWidth = 2;
    final noise = Random();
    for (double x = 0; x < size.width; x += 6) {
      final y = size.height / 2 +
          (size.height / 3) * (0.2 + noise.nextDouble() * 0.7) * sin(x / 22 + noise.nextDouble());
      canvas.drawLine(Offset(x, size.height), Offset(x, y), paint);
    }
  }
  @override
  bool shouldRepaint(covariant _BandScopePainter oldDelegate) => color != oldDelegate.color;
}

class _LiveAudioWidget extends StatelessWidget {
  final double fontScale;
  const _LiveAudioWidget({required this.fontScale});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _StyledCard(
      fontScale: fontScale,
      padding: EdgeInsets.all(10 * fontScale),
      child: Row(
        children: [
          Icon(Icons.hearing, color: theme.colorScheme.primary, size: 36 * fontScale),
          SizedBox(width: 12 * fontScale),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Live Audio", style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16 * fontScale)),
                Text("PCM 32kHz, Mono", style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 12 * fontScale)),
                SizedBox(height: 6 * fontScale),
                LinearProgressIndicator(
                  value: 0.63,
                  backgroundColor: theme.colorScheme.onSurface.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  minHeight: 7 * fontScale,
                ),
              ],
            ),
          ),
          Icon(Icons.volume_up, color: theme.colorScheme.onSurface.withOpacity(0.7), size: 24 * fontScale),
        ],
      ),
    );
  }
}

class _APRSWidget extends StatelessWidget {
  final double fontScale;
  final bool compact;
  final Map gps;
  const _APRSWidget({required this.fontScale, required this.compact, required this.gps});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.brightness == Brightness.dark ? Colors.orangeAccent : Colors.orange.shade800;
    final textColor = theme.colorScheme.onSurface;
    return _StyledCard(
      fontScale: fontScale,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16 * fontScale, vertical: 8 * fontScale),
        child: Row(
          children: [
            Icon(Icons.location_on, color: iconColor, size: 32 * fontScale),
            SizedBox(width: 10 * fontScale),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "APRS: ${gps['lat'].toStringAsFixed(4)}, ${gps['lon'].toStringAsFixed(4)}",
                    style: TextStyle(color: textColor, fontSize: 15 * fontScale),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!compact)
                    Text("3 stations nearby", style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12 * fontScale)),
                ],
              ),
            ),
            const Spacer(),
            Icon(Icons.message_outlined, color: theme.iconTheme.color?.withOpacity(0.5), size: 22 * fontScale),
            SizedBox(width: 6 * fontScale),
            Icon(Icons.map, color: theme.iconTheme.color?.withOpacity(0.7), size: 22 * fontScale),
          ],
        ),
      ),
    );
  }
}

class _NOAAWidget extends StatelessWidget {
  final Map radio;
  final double fontScale;
  const _NOAAWidget({required this.radio, required this.fontScale});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool enabled = radio['wx'] == true;
    return _StyledCard(
      fontScale: fontScale,
      color: enabled ? (theme.brightness == Brightness.dark ? Colors.blueGrey.shade800 : Colors.lightBlue.shade100) : null,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16 * fontScale, vertical: 8 * fontScale),
        child: Row(
          children: [
            Icon(Icons.cloud, color: enabled ? (theme.brightness == Brightness.dark ? Colors.lightBlueAccent : theme.colorScheme.primary) : theme.iconTheme.color, size: 32 * fontScale),
            SizedBox(width: 10 * fontScale),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(enabled ? "NOAA WX Mode" : "NOAA Off",
                    style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 15 * fontScale)),
                  Text(
                    enabled
                      ? "Channel: ${radio['noaa']}"
                      : "Tap to enable",
                    style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 12 * fontScale)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanStatusWidget extends StatelessWidget {
  final Map radio;
  final double fontScale;
  const _ScanStatusWidget({required this.radio, required this.fontScale});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool scanning = radio['scan'] == true;
    return _StyledCard(
      fontScale: fontScale,
      color: scanning ? (theme.brightness == Brightness.dark ? Colors.green.shade900 : Colors.green.shade100) : null,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16 * fontScale, vertical: 8 * fontScale),
        child: Row(
          children: [
            Icon(Icons.search, color: scanning ? (theme.brightness == Brightness.dark ? Colors.greenAccent : Colors.green.shade800) : theme.iconTheme.color, size: 32 * fontScale),
            SizedBox(width: 10 * fontScale),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(scanning ? "Scanning" : "Scan Off",
                    style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 15 * fontScale)),
                  Text(
                    scanning
                      ? "${radio['scanType']} scan"
                      : "Tap to start scan",
                    style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 12 * fontScale)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}