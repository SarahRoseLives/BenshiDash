import 'dart:async';
import 'package:benshidash/benshi/protocol/protocol.dart';
import 'package:benshidash/models/aprs_packet.dart';
import 'package:benshidash/services/location_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../benshi/radio_controller.dart';
import '../../../main.dart'; // To get the global notifier
import '../../widgets/main_layout.dart';
import '../settings/settings.dart'; // Import settings to access the notifier

class AprsScreen extends StatelessWidget {
  const AprsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RadioController?>(
      valueListenable: radioControllerNotifier,
      builder: (context, radioController, _) {
        return MainLayout(
          radioController: radioController,
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
  List<Polyline> _pathPolylines = [];

  // Default center if no GPS is available yet
  static const LatLng _initialCenter = LatLng(41.737, -80.771);
  LatLng _currentCenter = _initialCenter;

  @override
  void initState() {
    super.initState();
    _radioController = radioControllerNotifier.value;
    if (_radioController != null) {
      _packets = _radioController!.aprsPackets;
      _radioController!.addListener(_onDataUpdate);
      _activateAprsMode(); // --- NEW: Call to activate APRS mode ---
    }
    // Listen for changes from all relevant sources
    showAprsPathsNotifier.addListener(_onDataUpdate);
    gpsSourceNotifier.addListener(_onDataUpdate);
    locationService.addListener(_onDataUpdate);
  }

  @override
  void dispose() {
    _radioController?.removeListener(_onDataUpdate);
    showAprsPathsNotifier.removeListener(_onDataUpdate);
    gpsSourceNotifier.removeListener(_onDataUpdate);
    locationService.removeListener(_onDataUpdate);
    super.dispose();
  }

  /// --- NEW: Activates dual watch and tunes VFO B to the APRS frequency ---
  Future<void> _activateAprsMode() async {
    if (_radioController == null || !_radioController!.isReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Radio not ready for APRS mode.")),
        );
      }
      return;
    }

    const aprsChannelId = 251; // Use a high, likely unused channel
    final aprsFreq = aprsFrequencyNotifier.value;

    try {
      // 1. Create a channel object for the APRS frequency.
      final aprsChannel = Channel(
        channelId: aprsChannelId,
        name: 'APRS',
        rxFreq: aprsFreq,
        txFreq: aprsFreq,
        rxMod: ModulationType.FM,
        txMod: ModulationType.FM,
        bandwidth: BandwidthType.WIDE, // APRS is typically wide
        scan: false,
        txDisable: true, // Don't transmit on this channel from the app
        txAtMaxPower: false,
        txAtMedPower: false,
      );

      // 2. Write this temporary channel to the radio.
      await _radioController!.writeChannel(aprsChannel);
      await Future.delayed(const Duration(milliseconds: 100)); // Give radio time

      // 3. Get current settings and update them for dual watch on VFO B.
      final currentSettings = _radioController!.settings;
      if (currentSettings != null) {
        final newSettings = currentSettings.copyWith(
          doubleChannel: ChannelType.B.index, // Enable Dual Watch, VFO B active
          channelB: aprsChannelId,
        );
        await _radioController!.writeSettings(newSettings);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("APRS mode activated on VFO B ($aprsFreq MHz).")),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to activate APRS mode: $e")),
        );
      }
    }
  }


  /// A single update handler for all data changes.
  void _onDataUpdate() {
    if (mounted) {
      setState(() {
        _packets = _radioController?.aprsPackets ?? [];
        _updateCurrentCenter();
        _updatePathLines();
      });
    }
  }

  void _updateCurrentCenter() {
    LatLng? newCenter;

    if (gpsSourceNotifier.value == GpsSource.device && locationService.currentPosition != null) {
      final pos = locationService.currentPosition!;
      newCenter = LatLng(pos.latitude, pos.longitude);
    } else if (gpsSourceNotifier.value == GpsSource.radio && _radioController?.gps != null) {
      final pos = _radioController!.gps!;
      newCenter = LatLng(pos.latitude, pos.longitude);
    } else if (kDebugMode && gpsSourceNotifier.value == GpsSource.debug) {
      final pos = LocationService.debugPosition;
      newCenter = LatLng(pos.latitude, pos.longitude);
    }

    if (newCenter != null && newCenter != _currentCenter) {
      _currentCenter = newCenter;
      _mapController.move(_currentCenter, _mapController.camera.zoom);
    }
  }

  void _updatePathLines() {
    _pathPolylines = [];
    final latestPacket = _radioController?.latestAprsPacket;
    if (!showAprsPathsNotifier.value || latestPacket == null || latestPacket.path.isEmpty) {
      return;
    }

    AprsPacket? sourcePacket;
    try {
      sourcePacket = _packets.firstWhere((p) => p.source == latestPacket.source);
    } catch(e) { /* not found */ }

    if (sourcePacket?.latitude == null) return;

    final pathPoints = <LatLng>[
      LatLng(sourcePacket!.latitude!, sourcePacket.longitude!),
    ];

    for (final callsign in latestPacket.path) {
      final cleanCallsign = callsign.replaceAll('*', '');
      AprsPacket? digipeaterPacket;
      try {
        digipeaterPacket = _packets.firstWhere((p) => p.source == cleanCallsign);
      } catch (e) { /* not found */ }

      if (digipeaterPacket?.latitude != null) {
        pathPoints.add(LatLng(digipeaterPacket!.latitude!, digipeaterPacket.longitude!));
        break;
      }
    }

    if (pathPoints.length > 1) {
      _pathPolylines.add(
        Polyline(
          points: pathPoints,
          color: Colors.orange.withOpacity(0.8),
          strokeWidth: 3.0,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 8.0,
              minZoom: 5,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sarahrose.benshidash',
                tileBuilder: theme.brightness == Brightness.dark
                    ? (context, tileWidget, tile) => ColorFiltered(
                          colorFilter: const ColorFilter.matrix([
                            -0.8, 0, 0, 0, 230,
                            0, -0.8, 0, 0, 230,
                            0, 0, -0.8, 0, 230,
                            0, 0, 0, 1, 0,
                          ]),
                          child: tileWidget,
                        )
                    : null,
              ),
              PolylineLayer(polylines: _pathPolylines),
              MarkerLayer(markers: markers),
            ],
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () {
                _mapController.move(_currentCenter, _mapController.camera.zoom);
              },
              backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
              child: Icon(Icons.my_location, color: theme.colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _StationMarker extends StatelessWidget {
  final AprsPacket packet;
  const _StationMarker({required this.packet});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: '${packet.source}\n${packet.path.join(' -> ')}\n${packet.comment ?? ''}',
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