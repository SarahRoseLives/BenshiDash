import 'dart:async';
import 'package:benshidash/models/aprs_packet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../benshi/radio_controller.dart';
import '../../../main.dart'; // To get the global notifier
import '../../widgets/main_layout.dart';
import '../home/dashboard.dart'; // For mock header/footer data

class AprsScreen extends StatelessWidget {
  const AprsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen for connection status changes from the global notifier
    return ValueListenableBuilder<RadioController?>(
      valueListenable: radioControllerNotifier,
      builder: (context, radioController, _) {
        return MainLayout(
          radioController: radioController,
          radio: radio,
          battery: battery,
          gps: gps,
          child: radioController == null
              ? const Center(child: Text("Connect to a radio to view APRS data."))
              : const _AprsMapContent(),
        );
      },
    );
  }
}

class _AprsMapContent extends StatefulWidget {
  const _AprsMapContent();

  @override
  State<_AprsMapContent> createState() => _AprsMapContentState();
}

class _AprsMapContentState extends State<_AprsMapContent> {
  RadioController? _radioController;
  final MapController _mapController = MapController();
  List<AprsPacket> _packets = [];

  // Center of Jefferson, OH (zip 44047)
  static const LatLng _initialCenter = LatLng(41.737, -80.771);

  @override
  void initState() {
    super.initState();
    _radioController = radioControllerNotifier.value;
    if (_radioController != null) {
      _packets = _radioController!.aprsPackets;
      _radioController!.addListener(_onRadioUpdate);
    }
  }

  @override
  void dispose() {
    _radioController?.removeListener(_onRadioUpdate);
    super.dispose();
  }

  void _onRadioUpdate() {
    if (mounted) {
      setState(() {
        // Update the local list of packets from the controller
        _packets = _radioController?.aprsPackets ?? [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Build markers from the current packets list
    final markers = _packets
        .where((p) => p.latitude != null && p.longitude != null)
        .map((packet) {
      return Marker(
        width: 80.0,
        height: 80.0,
        point: LatLng(packet.latitude!, packet.longitude!),
        child: _StationMarker(packet: packet),
      );
    }).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: FlutterMap(
        mapController: _mapController,
        options: const MapOptions(
          initialCenter: _initialCenter,
          initialZoom: 12.0,
          minZoom: 5,
          maxZoom: 18,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.sarahrose.benshidash',
            // For dark mode, we can apply a color filter to the map tiles
            tileBuilder: theme.brightness == Brightness.dark
                ? (context, tileWidget, tile) => ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        // Invert brightness and apply a blueish tint
                        -0.8, 0, 0, 0, 230,
                        0, -0.8, 0, 0, 230,
                        0, 0, -0.8, 0, 230,
                        0, 0, 0, 1, 0,
                      ]),
                      child: tileWidget,
                    )
                : null,
          ),
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }
}

/// A widget to display a single station marker on the map.
class _StationMarker extends StatelessWidget {
  final AprsPacket packet;
  const _StationMarker({required this.packet});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: '${packet.source}\n${packet.comment ?? ''}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            packet.symbolIcon,
            color: theme.colorScheme.primary,
            size: 30,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4.0)],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.65),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white.withOpacity(0.5), width: 0.5),
            ),
            child: Text(
              packet.source,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}