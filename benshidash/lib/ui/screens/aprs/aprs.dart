// ui/screens/aprs/aprs.dart
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
import '../settings/settings.dart'; // Import settings to access the notifier AND top-level functions
// --- Add Caching Import ---
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
// --------------------------

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
              // Use AnimatedBuilder to listen to offline/home notifiers
              : AnimatedBuilder(
                  animation: Listenable.merge([offlineModeNotifier, homeLocationNotifier]),
                  builder: (context, _) => const _AprsMapContent(),
                ),
        );
      },
    );
  }
}

class _AprsMapContent extends StatefulWidget {
  const _AprsMapContent({super.key});

  @override
  State<_AprsMapContent> createState() => _AprsMapContentState();
}

class _AprsMapContentState extends State<_AprsMapContent> {
  RadioController? _radioController;
  final MapController _mapController = MapController();
  List<AprsPacket> _packets = [];
  List<Polyline> _pathPolylines = [];

  static const LatLng _initialCenter = LatLng(41.737, -80.771); // Example: Jefferson, OH

  late FMTCTileProvider _tileProvider;

  @override
  void initState() {
    super.initState();
    _radioController = radioControllerNotifier.value;
    if (_radioController != null) {
      _packets = _radioController!.aprsPackets;
      _radioController!.addListener(_onDataUpdate);
      if(_radioController?.settings?.channelB != 251 || _radioController?.settings?.doubleChannel != ChannelType.B.index) {
          _activateAprsMode();
      }
    }
    showAprsPathsNotifier.addListener(_onDataUpdate);
    gpsSourceNotifier.addListener(_onDataUpdate);
    locationService.addListener(_onDataUpdate);
    homeLocationNotifier.addListener(_centerOnHomeIfNeeded);
    offlineModeNotifier.addListener(_onDataUpdate); // Listen for offline mode changes too

    _updateTileProvider();
    _centerOnHomeIfNeeded();
  }

  @override
  void dispose() {
    _radioController?.removeListener(_onDataUpdate);
    showAprsPathsNotifier.removeListener(_onDataUpdate);
    gpsSourceNotifier.removeListener(_onDataUpdate);
    locationService.removeListener(_onDataUpdate);
    homeLocationNotifier.removeListener(_centerOnHomeIfNeeded);
    offlineModeNotifier.removeListener(_onDataUpdate);
    _mapController.dispose();
    super.dispose();
  }

  void _updateTileProvider() {
     _tileProvider = FMTCTileProvider.allStores(
        // --- CORRECTED ENUM NAME AND VALUE from WaveADSB Example ---
        allStoresStrategy: BrowseStoreStrategy.readUpdateCreate,
        // ---------------------------------------------------------
        loadingStrategy: offlineModeNotifier.value
            ? BrowseLoadingStrategy.cacheOnly
            : BrowseLoadingStrategy.cacheFirst,
     );
     // If the widget is already built, trigger a rebuild to use the new provider
     if (mounted) {
       setState(() {});
     }
  }


  void _centerOnHomeIfNeeded() {
      final homeLoc = homeLocationNotifier.value;
      if (homeLoc != null && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _mapController.camera.center != homeLoc) { // Avoid unnecessary moves
              _mapController.move(homeLoc, _mapController.camera.zoom);
            }
          });
      }
  }

  Future<void> _activateAprsMode() async {
    if (_radioController == null || !_radioController!.isReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Radio not ready for APRS mode.")),
        );
      }
      return;
    }

    const aprsChannelId = 251;
    final aprsFreq = aprsFrequencyNotifier.value;

    try {
      // Read the existing channel first, then modify it (like benlink does)
      final existingChannel = await _radioController!.getChannel(aprsChannelId);
      
      // Use copyWith to update only the fields we need for APRS
      final aprsChannel = existingChannel.copyWith(
        name: 'APRS',
        rxFreq: aprsFreq,
        txFreq: aprsFreq,
        rxMod: ModulationType.FM,
        txMod: ModulationType.FM,
        bandwidth: BandwidthType.WIDE,
        txSubAudio: null,
        rxSubAudio: null,
        scan: false,
        txDisable: true,
      );

      await _radioController!.writeChannel(aprsChannel);
      await Future.delayed(const Duration(milliseconds: 100));

      final currentSettings = _radioController!.settings ?? await _radioController!.getSettings();
      if (currentSettings != null) {
        final newSettings = currentSettings.copyWith(
          doubleChannel: ChannelType.B.value,
          channelB: aprsChannelId,
          scan: false, // Disable scan when enabling dual watch
          vfoX: 2, // Enable VFO mode for channel B (1 = VFO A, 2 = VFO B)
        );
        await _radioController!.writeSettings(newSettings);
      } else {
         throw Exception("Could not load current radio settings.");
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

  void _onDataUpdate() {
    if (mounted) {
      _updateTileProvider();
      setState(() {
        _packets = _radioController?.aprsPackets ?? [];
        _updateCurrentCenter();
        _updatePathLines();
      });
    }
  }

  void _showPacketDetails(BuildContext context, AprsPacket packet) {
      showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => _PacketDetailsSheet(packet: packet),
    );
  }

  LatLng? _currentGpsCenter;
  void _updateCurrentCenter() {
     LatLng? newCenter;
    final GpsSource currentSource = gpsSourceNotifier.value;

    if (currentSource == GpsSource.device && locationService.currentPosition != null) {
      final pos = locationService.currentPosition!;
      newCenter = LatLng(pos.latitude, pos.longitude);
    } else if (currentSource == GpsSource.radio && _radioController?.gps != null) {
      final pos = _radioController!.gps!;
      newCenter = LatLng(pos.latitude, pos.longitude);
    } else if (kDebugMode && currentSource == GpsSource.debug) {
      final pos = LocationService.debugPosition;
      newCenter = LatLng(pos.latitude, pos.longitude);
    }
    _currentGpsCenter = newCenter;
  }

  void _updatePathLines() {
     _pathPolylines = [];
    final latestPacket = _radioController?.latestAprsPacket;
    if (!showAprsPathsNotifier.value || latestPacket == null || latestPacket.path.isEmpty) return;

    AprsPacket? sourcePacket;
    try { sourcePacket = _packets.firstWhere((p) => p.source == latestPacket.source); } catch(e) { /* not found */ }
    if (sourcePacket?.latitude == null || sourcePacket?.longitude == null) return;

    final pathPoints = <LatLng>[ LatLng(sourcePacket!.latitude!, sourcePacket.longitude!) ];

    for (final callsign in latestPacket.path) {
      final cleanCallsign = callsign.replaceAll('*', '');
      AprsPacket? digipeaterPacket;
      try { digipeaterPacket = _packets.firstWhere((p) => p.source == cleanCallsign); } catch (e) { /* not found */ }
      if (digipeaterPacket?.latitude != null && digipeaterPacket?.longitude != null) {
        pathPoints.add(LatLng(digipeaterPacket!.latitude!, digipeaterPacket.longitude!));
        break;
      }
    }

    if (pathPoints.length > 1) {
      _pathPolylines.add( Polyline( points: pathPoints, color: Colors.orange.withOpacity(0.8), strokeWidth: 3.0 ) );
    }
  }

  void _setHomeLocation(LatLng location) {
    // Call top-level function from settings.dart
    updateHomeLocation(location);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Home location set to ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}'),
        backgroundColor: Colors.green, duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final LatLng? homeLoc = homeLocationNotifier.value;

    Marker? homeMarker;
    if (homeLoc != null) {
        homeMarker = Marker(
        point: homeLoc, width: 80, height: 60, alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon( Icons.home_filled, color: Colors.red[400], size: 30, shadows: const [Shadow(blurRadius: 3.0, color: Colors.black54)] ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration( color: Colors.black.withOpacity(0.75), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white.withOpacity(0.5), width: 0.5) ),
              child: Text('HOME', style: TextStyle( color: Colors.red[300], fontSize: 10, fontWeight: FontWeight.bold )),
            ),
          ]
        ),
      );
    }

    final List<Marker> aprsMarkers = _packets
        .where((p) => p.latitude != null && p.longitude != null)
        .map((packet) => Marker(
            width: 80.0, height: 80.0, point: LatLng(packet.latitude!, packet.longitude!),
            child: GestureDetector( onTap: () => _showPacketDetails(context, packet), child: _StationMarker(packet: packet) ),
          )).toList();

    final List<Marker> allMarkers = [];
    if (homeMarker != null) allMarkers.add(homeMarker);
    allMarkers.addAll(aprsMarkers);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: homeLoc ?? _initialCenter, initialZoom: 8.0, minZoom: 5, maxZoom: 18,
              interactionOptions: const InteractionOptions( flags: InteractiveFlag.all & ~InteractiveFlag.rotate ),
              onLongPress: (tapPosition, latLng) => _setHomeLocation(latLng),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sarahrose.benshidash',
                tileProvider: _tileProvider,
                errorTileCallback: (tile, error, stackTrace) => print('Error loading tile ${tile.coordinates}: $error'),
                tileBuilder: theme.brightness == Brightness.dark
                    ? _darkModeTileBuilder // Call the method
                    : null,
              ),
              if (homeLoc != null)
                CircleLayer( circles: [ CircleMarker(
                        point: homeLoc, radius: aprsNearbyRadiusNotifier.value * 1609.34, useRadiusInMeter: true,
                        color: Colors.white.withOpacity(0.1), borderColor: Colors.white.withOpacity(0.5), borderStrokeWidth: 1.5,
                    ) ] ),
              PolylineLayer(polylines: _pathPolylines),
              MarkerLayer(markers: allMarkers),
            ],
          ),
          Positioned(
            bottom: 16, right: 16,
            child: FloatingActionButton(
              heroTag: 'recenterMapFab',
              onPressed: () {
                if (_currentGpsCenter != null) { _mapController.move(_currentGpsCenter!, _mapController.camera.zoom); }
                else { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text("Current GPS location not available."), duration: Duration(seconds: 2)) ); }
              },
              backgroundColor: theme.colorScheme.surface.withOpacity(0.85),
              child: Icon(Icons.my_location, color: theme.colorScheme.onSurface),
            ),
          ),
           if (homeLoc != null)
             Positioned(
               bottom: 16 + 56 + 10, right: 16,
               child: FloatingActionButton(
                 heroTag: 'centerHomeFab', mini: true,
                 onPressed: () => _mapController.move(homeLoc, _mapController.camera.zoom),
                 backgroundColor: theme.colorScheme.surface.withOpacity(0.85),
                 child: Icon(Icons.home_filled, color: Colors.red[400]),
               ),
             ),
        ],
      ),
    );
  }

  // Helper method for dark mode tile building
  Widget _darkModeTileBuilder(BuildContext context, Widget tileWidget, TileImage tile) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
          -1, 0, 0, 0, 255, // Red
          0, -1, 0, 0, 255, // Green
          0, 0, -1, 0, 255, // Blue
          0, 0, 0, 1, 0,    // Alpha
      ]),
      child: tileWidget,
    );
  }
}

// _StationMarker remains unchanged
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


// _PacketDetailsSheet remains unchanged
class _PacketDetailsSheet extends StatelessWidget {
  final AprsPacket packet;
  const _PacketDetailsSheet({required this.packet});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.65,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _buildInfoRow(theme, Icons.alt_route, "Path", '${packet.source} > ${packet.destination} via ${packet.path.join(', ')}'),
                  _buildInfoRow(theme, Icons.location_pin, "Position", 'Lat: ${packet.latitude?.toStringAsFixed(4)}, Lon: ${packet.longitude?.toStringAsFixed(4)}'),
                  if (packet.comment != null && packet.comment!.trim().isNotEmpty)
                    _buildInfoRow(theme, Icons.comment, "Comment", packet.comment!),
                  const Divider(height: 32),
                  Text("Raw Packet Body", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      packet.body,
                      style: theme.textTheme.bodyLarge?.copyWith(fontFamily: 'monospace', fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Close"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Icon(packet.symbolIcon, size: 40, color: theme.colorScheme.primary),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            "Packet: ${packet.source}",
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3.0),
            child: Icon(icon, size: 22, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 16),
          Text("$label:", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}