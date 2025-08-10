// ui/widgets/main_layout.dart

import 'dart:math';
import 'package:benshidash/benshi/radio_controller.dart';
import 'package:benshidash/main.dart';
import 'package:flutter/material.dart';

// Import all the destination screens
import '../screens/about/about.dart';
import '../screens/aprs/aprs.dart';
import '../screens/channels/channels.dart';
import '../screens/home/dashboard.dart';
import '../screens/radio_settings/radio_settings.dart';
import '../screens/scan/scan.dart';
import '../screens/settings/settings.dart';

// An InheritedWidget to pass layout data down the tree.
class LayoutData extends InheritedWidget {
  final double scale;
  final bool compact;
  final bool isPortrait;

  const LayoutData({
    super.key,
    required this.scale,
    required this.compact,
    required this.isPortrait,
    required super.child,
  });

  static LayoutData? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LayoutData>();
  }

  @override
  bool updateShouldNotify(LayoutData oldWidget) {
    return scale != oldWidget.scale ||
        compact != oldWidget.compact ||
        isPortrait != oldWidget.isPortrait;
  }
}

// The main layout shell widget.
class MainLayout extends StatelessWidget {
  final Widget child;
  final Map radio;
  final Map battery;
  final Map gps;
  final RadioController? radioController;

  const MainLayout({
    super.key,
    required this.child,
    required this.radio,
    required this.battery,
    required this.gps,
    this.radioController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // This Scaffold is the key to fixing the context errors.
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final refWidth = 1200.0;
          final refHeight = 600.0;
          final scaleW = constraints.maxWidth / refWidth;
          final scaleH = constraints.maxHeight / refHeight;
          final scale = max(0.2, min(scaleW, scaleH));
          final compact = scale < 0.62;
          final isPortrait =
              constraints.maxWidth < 900 || constraints.maxWidth < constraints.maxHeight;

          return LayoutData(
            scale: scale,
            compact: compact,
            isPortrait: isPortrait,
            child: Builder(
                builder: (context) {
              return Container(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: Padding(
                  padding: EdgeInsets.all(12.0 * scale),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 60 * scale,
                        child: _TopStatusRow(
                          fontScale: scale,
                          radio: radio,
                          battery: battery,
                          gps: gps,
                        ),
                      ),
                      SizedBox(height: 10 * scale),
                      Expanded(
                        child: isPortrait
                            ? _MobileLayout(child: child, radioController: radioController)
                            : _DesktopLayout(child: child, radioController: radioController),
                      ),
                      SizedBox(height: 10 * scale),
                      SizedBox(
                        height: 36 * scale,
                        child: _BottomStatusBar(
                          fontScale: scale,
                          compact: compact,
                          gps: gps,
                          radio: radio,
                          battery: battery,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

void _navigateTo(BuildContext context, Widget screen) {
  Navigator.of(context).pushReplacement(
    PageRouteBuilder(
      pageBuilder: (context, animation1, animation2) => screen,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}

class _DesktopLayout extends StatelessWidget {
  final Widget child;
  final RadioController? radioController;
  const _DesktopLayout({required this.child, this.radioController});

  @override
  Widget build(BuildContext context) {
    final layout = LayoutData.of(context)!;
    return Row(
      children: [
        _Sidebar(
          items: [
            _SidebarItem(
              icon: Icons.tune,
              label: "Radio Setup",
              onTap: () => _navigateTo(context, const RadioSettingsScreen()),
            ),
            // --- FIX #1: Removed the incorrect Builder widget ---
            _SidebarItem(
              icon: Icons.settings_input_antenna,
              label: "Scan",
              onTap: () {
                if (radioController != null) {
                  _navigateTo(context, const ScanScreen());
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please connect to a radio first.')),
                  );
                }
              },
            ),
            _SidebarItem(
              icon: Icons.settings,
              label: "Settings",
              onTap: () => _navigateTo(context, const SettingsScreen()),
            ),
          ],
        ),
        SizedBox(width: 10 * layout.scale),
        Expanded(
          flex: 4,
          child: child,
        ),
        SizedBox(width: 10 * layout.scale),
        _Sidebar(
          right: true,
          items: [
            _SidebarItem(
              icon: Icons.location_on,
              label: "APRS",
              onTap: () => _navigateTo(context, const AprsScreen()),
            ),
            _SidebarItem(
              icon: Icons.list,
              label: "Channels",
              onTap: () => _navigateTo(context, const ChannelsScreen()),
            ),
            _SidebarItem(
              icon: Icons.info_outline,
              label: "About",
              onTap: () => _navigateTo(context, const AboutScreen()),
            ),
          ],
        ),
      ],
    );
  }
}

class _MobileLayout extends StatelessWidget {
  final Widget child;
  final RadioController? radioController;
  const _MobileLayout({required this.child, this.radioController});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Sidebar(
          items: [
            _SidebarItem(
              icon: Icons.tune,
              label: "",
              onTap: () => _navigateTo(context, const RadioSettingsScreen()),
            ),
            // --- FIX #2: Removed the incorrect Builder widget ---
            _SidebarItem(
              icon: Icons.settings_input_antenna,
              label: "",
              onTap: () {
                if (radioController != null) {
                  _navigateTo(context, const ScanScreen());
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please connect to a radio first.')),
                  );
                }
              },
            ),
            _SidebarItem(
              icon: Icons.settings,
              label: "",
              onTap: () => _navigateTo(context, const SettingsScreen()),
            ),
          ],
        ),
        SizedBox(width: 8 * LayoutData.of(context)!.scale),
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: child,
          ),
        ),
        SizedBox(width: 8 * LayoutData.of(context)!.scale),
        _Sidebar(
          right: true,
          items: [
            _SidebarItem(
              icon: Icons.location_on,
              label: "",
              onTap: () => _navigateTo(context, const AprsScreen()),
            ),
            _SidebarItem(
              icon: Icons.list,
              label: "",
              onTap: () => _navigateTo(context, const ChannelsScreen()),
            ),
            _SidebarItem(
              icon: Icons.info_outline,
              label: "",
              onTap: () => _navigateTo(context, const AboutScreen()),
            ),
          ],
        ),
      ],
    );
  }
}

class _SidebarItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  _SidebarItem({required this.icon, required this.label, required this.onTap});
}

class _Sidebar extends StatelessWidget {
  final List<_SidebarItem> items;
  final bool right;
  const _Sidebar({required this.items, this.right = false});

  @override
  Widget build(BuildContext context) {
    final layout = LayoutData.of(context)!;
    final compact = layout.compact;
    final fontScale = layout.scale;
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface.withOpacity(0.9),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: compact ? 56 : 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: items
              .map((item) => Expanded(
                    child: InkWell(
                      onTap: item.onTap,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(item.icon,
                              size: (compact ? 22 : 34) * fontScale,
                              color: theme.colorScheme.primary),
                          const SizedBox(height: 4),
                          if (!compact && item.label.isNotEmpty)
                            Text(item.label,
                                style: TextStyle(
                                    fontSize: 12 * fontScale,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.8))),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _TopStatusRow extends StatelessWidget {
  final double fontScale;
  final Map radio, battery, gps;
  const _TopStatusRow({
    required this.fontScale,
    required this.radio,
    required this.battery,
    required this.gps,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navigateTo(context, const DashboardScreen()),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: _RadioStatus(radio: radio, fontScale: fontScale),
            ),
          ),
        ),
        _BatteryStatus(battery: battery, fontScale: fontScale),
        _GPSStatus(gps: gps, fontScale: fontScale),
      ],
    );
  }
}

class _RadioStatus extends StatelessWidget {
  final Map radio;
  final double fontScale;
  const _RadioStatus({required this.radio, required this.fontScale});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inactiveColor = theme.iconTheme.color?.withOpacity(0.3);

    return Row(
      children: [
        Icon(Icons.radio, color: theme.colorScheme.primary, size: 28 * fontScale),
        SizedBox(width: 6 * fontScale),
        Text("${radio['id']} ${radio['model']}",
            style: TextStyle(
                color: theme.colorScheme.onBackground,
                fontWeight: FontWeight.w600,
                fontSize: 15 * fontScale)),
        SizedBox(width: 8 * fontScale),
        Icon(
            radio['connected'] == true
                ? Icons.bluetooth_connected
                : Icons.bluetooth_disabled,
            color: radio['connected'] == true ? theme.colorScheme.primary : inactiveColor,
            size: 18 * fontScale),
        SizedBox(width: 2 * fontScale),
        Icon(Icons.headset,
            color: radio['audio'] == true ? theme.colorScheme.primary : inactiveColor,
            size: 18 * fontScale),
        SizedBox(width: 2 * fontScale),
        Icon(Icons.settings_input_antenna,
            color: radio['bt'] == true ? theme.colorScheme.primary : inactiveColor,
            size: 18 * fontScale),
      ],
    );
  }
}

class _BatteryStatus extends StatelessWidget {
  final Map battery;
  final double fontScale;
  const _BatteryStatus({required this.battery, required this.fontScale});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          battery['charging'] == true
              ? Icons.battery_charging_full
              : Icons.battery_full,
          color: battery['percent'] > 20
              ? (theme.brightness == Brightness.dark ? Colors.greenAccent : Colors.green)
              : theme.colorScheme.error,
          size: 22 * fontScale,
        ),
        SizedBox(width: 4 * fontScale),
        Text(
          "${battery['percent']}% (${battery['voltage']}V)",
          style: TextStyle(
              color: theme.colorScheme.onBackground, fontSize: 14 * fontScale),
        ),
      ],
    );
  }
}

class _GPSStatus extends StatelessWidget {
  final Map gps;
  final double fontScale;
  const _GPSStatus({required this.gps, required this.fontScale});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lockedColor =
        theme.brightness == Brightness.dark ? Colors.lightGreenAccent : Colors.green.shade700;
    return Row(
      children: [
        Icon(
            gps['locked'] == true ? Icons.gps_fixed : Icons.gps_off,
            color: gps['locked'] == true
                ? lockedColor
                : theme.iconTheme.color?.withOpacity(0.4),
            size: 22 * fontScale),
        SizedBox(width: 4 * fontScale),
        Text(
          gps['locked'] == true
              ? "${gps['lat'].toStringAsFixed(4)}, ${gps['lon'].toStringAsFixed(4)}"
              : "No Fix",
          style: TextStyle(
              color: theme.colorScheme.onBackground, fontSize: 14 * fontScale),
        ),
      ],
    );
  }
}

class _BottomStatusBar extends StatelessWidget {
  final Map gps;
  final Map radio;
  final Map battery;
  final double fontScale;
  final bool compact;
  const _BottomStatusBar(
      {required this.gps,
      required this.radio,
      required this.battery,
      required this.fontScale,
      required this.compact});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface.withOpacity(0.8);
    final iconColor = theme.colorScheme.onSurface.withOpacity(0.5);

    return Container(
      color: theme.colorScheme.surface,
      padding:
          EdgeInsets.symmetric(horizontal: 12 * fontScale, vertical: 7 * fontScale),
      child: Row(
        children: [
          Icon(Icons.access_time, color: iconColor, size: 18 * fontScale),
          SizedBox(width: 3 * fontScale),
          Text(gps['utc'],
              style: TextStyle(color: textColor, fontSize: 13 * fontScale)),
          SizedBox(width: 16 * fontScale),
          Icon(Icons.gps_fixed, color: iconColor, size: 16 * fontScale),
          SizedBox(width: 3 * fontScale),
          Text(
              gps['locked'] == true
                  ? "${gps['lat'].toStringAsFixed(3)}, ${gps['lon'].toStringAsFixed(3)}"
                  : "No GPS",
              style: TextStyle(color: textColor, fontSize: 13 * fontScale)),
          SizedBox(width: 16 * fontScale),
          Icon(Icons.battery_full, color: iconColor, size: 16 * fontScale),
          SizedBox(width: 3 * fontScale),
          Text("${battery['percent']}%",
              style: TextStyle(color: textColor, fontSize: 13 * fontScale)),
          if (!compact) ...[
            SizedBox(width: 16 * fontScale),
            Icon(Icons.radio, color: iconColor, size: 16 * fontScale),
            SizedBox(width: 3 * fontScale),
            Text("${radio['model']} v${radio['fw']}",
                style: TextStyle(color: textColor, fontSize: 13 * fontScale)),
          ],
          const Spacer(),
          Icon(Icons.warning_amber, color: Colors.orange, size: 16 * fontScale),
          SizedBox(width: 3 * fontScale),
          Text("All systems nominal",
              style: TextStyle(color: textColor, fontSize: 13 * fontScale)),
        ],
      ),
    );
  }
}