import 'package:flutter/material.dart';
import '../../widgets/main_layout.dart';
import '../home/dashboard.dart'; // For mock header/footer data

import '../../../benshi/radio_controller.dart';
import '../../../main.dart'; // To get the global notifier

// A simple, custom class to hold coordinates. NO external package needed.
class SimpleLatLng {
  final double latitude;
  final double longitude;
  const SimpleLatLng(this.latitude, this.longitude);
}

// Simple data class for a mock APRS station using our custom class
class MockAprsStation {
  final String callsign;
  final IconData icon;
  final Color color;
  final Offset position; // Positioned from top-left (x, y) as a percentage
  final String type;

  const MockAprsStation({
    required this.callsign,
    required this.icon,
    required this.color,
    required this.position,
    required this.type,
  });
}

// Mock Data for the APRS Map
final List<MockAprsStation> mockStations = [
  const MockAprsStation(
    callsign: 'K8JTK-9',
    icon: Icons.directions_car,
    color: Colors.lightBlueAccent,
    position: Offset(0.25, 0.40),
    type: 'Vehicle',
  ),
  const MockAprsStation(
    callsign: 'W8WKY-1',
    icon: Icons.router,
    color: Colors.greenAccent,
    position: Offset(0.55, 0.20),
    type: 'Digipeater',
  ),
  const MockAprsStation(
    callsign: 'N8IG-10',
    icon: Icons.cloudy_snowing,
    color: Colors.white,
    position: Offset(0.75, 0.65),
    type: 'Weather Station',
  ),
];

class AprsScreen extends StatelessWidget {
  const AprsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          child: const _AprsContent(),
        );
      },
    );
  }
}

class _AprsContent extends StatelessWidget {
  const _AprsContent();

  @override
  Widget build(BuildContext context) {
    final layout = LayoutData.of(context)!;
    final fontScale = layout.scale;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 12.0 * fontScale, top: 8.0 * fontScale),
          child: Center(
            child: Text(
              'APRS',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onBackground,
                fontWeight: FontWeight.bold,
                fontSize: 24 * fontScale,
              ),
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20 * fontScale),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border.all(color: theme.dividerColor, width: 2.0),
                borderRadius: BorderRadius.circular(20 * fontScale),
              ),
              // FIX: Using LayoutBuilder to get constraints for positioning
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: mockStations.map((station) {
                      // FIX: The Positioned widget is now the direct child of the Stack
                      return Positioned(
                        left: constraints.maxWidth * station.position.dx,
                        top: constraints.maxHeight * station.position.dy,
                        child: _AprsStationWidget(station: station, fontScale: fontScale),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AprsStationWidget extends StatelessWidget {
  final MockAprsStation station;
  final double fontScale;

  const _AprsStationWidget({
    required this.station,
    required this.fontScale,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(
          station.icon,
          color: station.color,
          size: 32 * fontScale,
          shadows: const [Shadow(color: Colors.black, blurRadius: 5.0)],
        ),
        SizedBox(height: 4 * fontScale),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6 * fontScale, vertical: 2 * fontScale),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? Colors.black.withOpacity(0.6)
                : Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(4 * fontScale),
          ),
          child: Text(
            station.callsign,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 12 * fontScale,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}