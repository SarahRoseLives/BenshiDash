import 'dart:async';
import 'dart:math';
import 'package:benshidash/models/repeater.dart';
import 'package:benshidash/services/repeaterbook_service.dart';
import 'package:benshidash/ui/screens/aprs/aprs.dart';
import 'package:benshidash/ui/screens/channels/channels.dart';
import 'package:benshidash/ui/screens/scan/scan.dart';
import 'package:benshidash/ui/screens/settings/settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import '../../../benshi/protocol/protocol.dart';
import '../../../benshi/radio_controller.dart';
import '../../../main.dart';
import '../../../services/location_service.dart';
import '../../widgets/main_layout.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  /// A static helper function for navigation, accessible by child widgets.
  static void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => screen,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RadioController?>(
      valueListenable: radioControllerNotifier,
      builder: (context, radioController, _) {
        return MainLayout(
          radioController: radioController,
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
  final double maxHeight;
  final double maxWidth;
  const _MainPanels({
    required this.radioController,
    required this.fontScale,
    required this.compact,
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
                  Expanded(child: _GPSFollowWidget(fontScale: fontScale, radioController: radioController)),
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
                  Expanded(child: _APRSWidget(radioController: radioController, fontScale: fontScale, compact: compact)),
                  const SizedBox(width: 10),
                  Expanded(child: _NOAAWidget(radioController: radioController, fontScale: fontScale)),
                  const SizedBox(width: 10),
                  Expanded(child: _ScanStatusWidget(radioController: radioController, fontScale: fontScale)),
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
  final VoidCallback? onTap;

  const _StyledCard({required this.child, required this.fontScale, this.color, this.padding, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: color ?? theme.cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24 * fontScale)),
      elevation: theme.cardTheme.elevation,
      shadowColor: theme.cardTheme.shadowColor,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: padding,
          child: child,
        ),
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

class _GPSFollowWidget extends StatelessWidget {
  final double fontScale;
  final RadioController radioController;
  const _GPSFollowWidget({required this.fontScale, required this.radioController});

  void _showGpsFollowWarningDialog(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error, size: 28),
            const SizedBox(width: 8),
            const Text("GPS Follow Mode"),
          ],
        ),
        content: const Text(
          "Warning: Enabling GPS Follow will repeatedly reprogram your radio as you travel. "
          "It is strongly recommended to backup your programming in Channels first.",
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text("Proceed"),
            onPressed: () {
              Navigator.of(context).pop();
              DashboardScreen._navigateTo(context, const ChannelsScreen());
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool locked = radioController.isGpsLocked;
    final double lat = radioController.gps?.latitude ?? 0;
    final double lon = radioController.gps?.longitude ?? 0;
    final double accuracy = radioController.gps?.accuracy.toDouble() ?? 0;

    return _StyledCard(
      fontScale: fontScale,
      padding: EdgeInsets.symmetric(horizontal: 20 * fontScale, vertical: 20 * fontScale),
      onTap: () => _showGpsFollowWarningDialog(context),
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
                      color: locked ? Colors.green : theme.colorScheme.error,
                      fontWeight: FontWeight.w500,
                      fontSize: 13.5 * fontScale),
                ),
                Text(
                  "Lat: ${lat.toStringAsFixed(4)}",
                  style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 12 * fontScale),
                ),
                Text(
                  "Lon: ${lon.toStringAsFixed(4)}",
                  style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 12 * fontScale),
                ),
                Text(
                  "±${accuracy.toStringAsFixed(1)} m",
                  style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 12 * fontScale),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyRepeatersWidget extends StatefulWidget {
  final double fontScale;
  final double maxHeight;
  const _NearbyRepeatersWidget({required this.fontScale, required this.maxHeight});

  @override
  State<_NearbyRepeatersWidget> createState() => _NearbyRepeatersWidgetState();
}

class _NearbyRepeatersWidgetState extends State<_NearbyRepeatersWidget> {
  Future<List<Repeater>>? _repeatersFuture;

  @override
  void initState() {
    super.initState();
    _fetchRepeaters();
  }

  void _fetchRepeaters() async {
    setState(() {
      _repeatersFuture = _getRepeaters();
    });
  }

  Future<List<Repeater>> _getRepeaters() async {
      geolocator.Position position;
      if (kDebugMode && gpsSourceNotifier.value == GpsSource.debug) {
        position = LocationService.debugPosition;
      } else {
        position = await locationService.determinePosition();
      }
      final service = RepeaterBookService();
      return await service.getRepeatersNearby(
        latitude: position.latitude,
        longitude: position.longitude,
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerHeight = 35 * widget.fontScale;
    final rowHeight = 32 * widget.fontScale;
    final padding = 16 * widget.fontScale + 18 * widget.fontScale;
    final availableRows = ((widget.maxHeight - headerHeight - padding) / rowHeight).floor();

    return _StyledCard(
      fontScale: widget.fontScale,
      onTap: () => DashboardScreen._navigateTo(context, const ChannelsScreen()),
      padding: EdgeInsets.symmetric(horizontal: 18 * widget.fontScale, vertical: 16 * widget.fontScale),
      child: FutureBuilder<List<Repeater>>(
        future: _repeatersFuture,
        builder: (context, snapshot) {
          Widget content;
          if (snapshot.connectionState == ConnectionState.waiting) {
            content = const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            content = Center(child: Text("Error: ${snapshot.error}", style: TextStyle(fontSize: 12 * widget.fontScale)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            content = Center(child: Text("No repeaters found.", style: TextStyle(fontSize: 12 * widget.fontScale)));
          } else {
            final visibleRepeaters = snapshot.data!.take(availableRows).toList();
            content = Column(
              children: visibleRepeaters.map((r) =>
                Padding(
                  padding: EdgeInsets.only(bottom: 7 * widget.fontScale),
                  child: Row(
                    children: [
                      Icon(Icons.radio, size: 19 * widget.fontScale, color: theme.colorScheme.secondary),
                      SizedBox(width: 7 * widget.fontScale),
                      Expanded(
                        child: Text(
                          "${r.outputFrequency.toStringAsFixed(3)}${r.outputFrequency > r.inputFrequency ? '-' : '+'} • ${r.callsign} (${r.city})",
                          style: TextStyle(fontSize: 13.5 * widget.fontScale, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
              ).toList(),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.broadcast_on_home, color: theme.colorScheme.primary, size: 28 * widget.fontScale),
                  SizedBox(width: 10 * widget.fontScale),
                  Text("Nearby Repeaters",
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 16 * widget.fontScale,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8 * widget.fontScale),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }
}

class _APRSWidget extends StatelessWidget {
  final RadioController radioController;
  final double fontScale;
  final bool compact;

  const _APRSWidget({required this.radioController, required this.fontScale, required this.compact});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.brightness == Brightness.dark ? Colors.orangeAccent : Colors.orange.shade800;
    final textColor = theme.colorScheme.onSurface;

    // Get current position to calculate nearby stations
    geolocator.Position? myPosition;
    if (gpsSourceNotifier.value == GpsSource.device && locationService.currentPosition != null) {
      myPosition = locationService.currentPosition!;
    } else if (gpsSourceNotifier.value == GpsSource.radio && radioController.gps != null) {
      final pos = radioController.gps!;
      myPosition = geolocator.Position(
        latitude: pos.latitude, longitude: pos.longitude, timestamp: pos.time,
        accuracy: pos.accuracy.toDouble(), altitude: pos.altitude?.toDouble() ?? 0.0,
        heading: pos.heading?.toDouble() ?? 0.0, speed: pos.speed?.toDouble() ?? 0.0, speedAccuracy: 0.0, altitudeAccuracy: 0.0, headingAccuracy: 0.0,
      );
    } else if (kDebugMode && gpsSourceNotifier.value == GpsSource.debug) {
      myPosition = LocationService.debugPosition;
    }

    int nearbyCount = 0;
    if (myPosition != null) {
      final radius = aprsNearbyRadiusNotifier.value;
      for (final packet in radioController.aprsPackets) {
        if (packet.latitude != null && packet.longitude != null) {
          final distance = RepeaterBookService.haversineDistance(
            myPosition.latitude, myPosition.longitude, packet.latitude!, packet.longitude!
          );
          if (distance <= radius) {
            nearbyCount++;
          }
        }
      }
    }

    return _StyledCard(
      fontScale: fontScale,
      onTap: () => DashboardScreen._navigateTo(context, const AprsScreen()),
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
                    "APRS",
                    style: TextStyle(color: textColor, fontSize: 15 * fontScale),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!compact)
                    Text("$nearbyCount stations nearby", style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12 * fontScale)),
                ],
              ),
            ),
            const Spacer(),
            Icon(Icons.map, color: theme.iconTheme.color?.withOpacity(0.7), size: 22 * fontScale),
          ],
        ),
      ),
    );
  }
}

class _NOAAWidget extends StatelessWidget {
  final RadioController radioController;
  final double fontScale;
  const _NOAAWidget({required this.radioController, required this.fontScale});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool enabled = radioController.settings?.wxMode != 0;
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
                      ? "Channel: ${radioController.settings?.noaaCh}"
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
  final RadioController radioController;
  final double fontScale;
  const _ScanStatusWidget({required this.radioController, required this.fontScale});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isScanning = radioController.isScan;
    return _StyledCard(
      fontScale: fontScale,
      onTap: () => DashboardScreen._navigateTo(context, const ScanScreen()),
      color: isScanning ? (theme.brightness == Brightness.dark ? Colors.green.shade900 : Colors.green.shade100) : null,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16 * fontScale, vertical: 8 * fontScale),
        child: Row(
          children: [
            Icon(Icons.search, color: isScanning ? (theme.brightness == Brightness.dark ? Colors.greenAccent : Colors.green.shade800) : theme.iconTheme.color, size: 32 * fontScale),
            SizedBox(width: 10 * fontScale),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isScanning ? "Scanning" : "Scan Off",
                    style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 15 * fontScale)),
                  Text(
                    isScanning
                      ? "Memory scan active"
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