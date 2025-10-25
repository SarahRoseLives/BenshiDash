// ui/screens/settings/map_settings.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'settings.dart'; // Import to access notifiers AND top-level functions

// Constants for slider
const double _minRadiusNM = 10.0;
const double _maxRadiusNM = 200.0;
const int _sliderDivisions = 19; // (200 - 10) / 10 = 19 steps

class MapSettingsScreen extends StatefulWidget {
  const MapSettingsScreen({super.key});

  @override
  State<MapSettingsScreen> createState() => _MapSettingsScreenState();
}

class _MapSettingsScreenState extends State<MapSettingsScreen> {
  Future<int?>? _tileCountFuture;
  Stream<DownloadProgress>? _downloadProgressStream;
  DownloadProgress? _latestDownloadProgress;
  bool _isDownloading = false;
  double _selectedRadiusNM = 50.0; // Default radius

  @override
  void initState() {
    super.initState();
    _loadTileCount();
    // Potentially load saved radius preference here if implemented
  }

  void _loadTileCount() {
    if (!mounted) return;
    setState(() {
      // Accessing stats requires the store instance
      _tileCountFuture = FMTCStore('default').stats.length;
    });
  }


  void _showSnackbar(BuildContext context, String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.redAccent : Colors.blueGrey,
      ),
    );
  }

  Future<void> _startDownload() async {
    final LatLng? homeLocation = homeLocationNotifier.value; // Use the notifier

    if (_isDownloading) {
      _showSnackbar(context, 'Download already in progress.');
      return;
    }
    if (homeLocation == null) {
      _showSnackbar(context, 'Please set a home location on the APRS map first (long-press).', error: true);
      return;
    }

    if (!mounted) return;
    setState(() {
      _isDownloading = true;
      _latestDownloadProgress = null;
    });

    final double radiusInMeters = _selectedRadiusNM * 1852; // Convert NM to meters
    _showSnackbar(context, 'Starting download for ${_selectedRadiusNM.round()} NM radius...');

    try {
      final store = FMTCStore('default'); // Get store instance
      const Distance distance = Distance();
      final LatLng northEast = distance.offset(homeLocation, radiusInMeters, 45);
      final LatLng southWest = distance.offset(homeLocation, radiusInMeters, 225);
      final LatLngBounds bounds = LatLngBounds(northEast, southWest);

      final downloadableRegion = RectangleRegion(bounds).toDownloadable(
        minZoom: 1,
        maxZoom: 12, // Keep max zoom reasonable
        // --- CORRECTED PARAMETER NAME: 'options' ---
        options: TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.sarahrose.benshidash', // CHANGE TO YOUR PACKAGE NAME
        ),
        // ------------------------------------------
      );

      // --- Call download on the store instance ---
      final streams = store.download.startForeground(
        region: downloadableRegion,
      );
      // ------------------------------------------

      _downloadProgressStream = streams.downloadProgress;

      await for (final progress in _downloadProgressStream!) {
        if (!mounted) break;
        setState(() {
          _latestDownloadProgress = progress;
        });
      }
       if (mounted && _isDownloading) { // Check _isDownloading flag in case it was cancelled
         _showSnackbar(context, 'Offline map download finished!');
       }


    } catch (e, s) {
      print('Download Error: $e\n$s');
       if (mounted) {
         _showSnackbar(context, 'Download failed: $e', error: true);
       }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgressStream = null;
        });
      }
      _loadTileCount();
    }
  }

   Future<void> _cancelDownload() async {
    if (!_isDownloading) return;
    try {
      // --- Cancel requires the store instance ---
      await FMTCStore('default').download.cancel();
      // -----------------------------------------
      if(mounted) _showSnackbar(context, 'Download cancelled.');
    } catch (e, s) {
      print('Cancel Error: $e\n$s');
       if (mounted) _showSnackbar(context, 'Failed to cancel download: $e', error: true);
    } finally {
        // State update happens naturally when the download stream finishes/errors after cancel
        // Or forcefully set _isDownloading false if needed, though the finally block in _startDownload should handle it.
         if (mounted && _isDownloading) {
           setState(() { _isDownloading = false; });
         }
    }
  }


  Future<void> _clearCache() async {
      try {
        // --- Reset requires the store instance ---
        await FMTCStore('default').manage.reset();
        // ----------------------------------------
        if (mounted) _showSnackbar(context, 'Tile cache cleared.');
        _loadTileCount(); // Reload count after clearing
      } catch (e, s) {
        print('Cache Clear Error: $e\n$s');
        if (mounted) _showSnackbar(context, 'Failed to clear cache: $e', error: true);
        _loadTileCount(); // Still try reloading count
      }
  }


  @override
  Widget build(BuildContext context) {
    // Use AnimatedBuilder to listen to notifier changes
    return AnimatedBuilder(
      animation: Listenable.merge([offlineModeNotifier, homeLocationNotifier]),
      builder: (context, child) {
         final bool offlineMode = offlineModeNotifier.value;
         final LatLng? homeLocation = homeLocationNotifier.value;

         return Scaffold(
          appBar: AppBar(
            title: const Text('Map Settings'),
            actions: [
              if (_isDownloading)
                IconButton(
                  icon: const Icon(Icons.cancel),
                  tooltip: 'Cancel Download',
                  onPressed: _cancelDownload,
                ),
            ],
          ),
          body: ListView(
            children: [
              SwitchListTile(
                title: const Text('Offline Mode'),
                subtitle: const Text('Use downloaded map tiles (if available)'),
                value: offlineMode,
                onChanged: _isDownloading ? null : (bool newValue) {
                  // Call top-level function from settings.dart
                  toggleOfflineMode(newValue);
                },
                 secondary: Icon(Icons.cloud_off, color: Theme.of(context).colorScheme.primary),
              ),
              const Divider(),
              ListTile(
                  leading: Icon(Icons.home_filled, color: Theme.of(context).colorScheme.primary),
                  title: const Text('Home Location'),
                  subtitle: Text(homeLocation == null
                      ? 'Not Set (Long-press on APRS map)'
                      : '${homeLocation.latitude.toStringAsFixed(4)}, ${homeLocation.longitude.toStringAsFixed(4)}'),
                  trailing: homeLocation != null
                    ? IconButton(
                       icon: Icon(Icons.clear, color: Colors.redAccent.withOpacity(0.7)),
                       tooltip: 'Clear Home Location',
                       // Call top-level function from settings.dart
                       onPressed: _isDownloading ? null : () => updateHomeLocation(null),
                      )
                    : null,
              ),
              const Divider(),
              FutureBuilder<int?>(
                future: _tileCountFuture,
                builder: (context, snapshot) {
                  String countText = 'Loading...';
                  IconData icon = Icons.storage_rounded;
                  if (snapshot.connectionState == ConnectionState.done) {
                    if (snapshot.hasError) {
                      countText = 'Error';
                      icon = Icons.error_outline;
                      print("Error loading tile count: ${snapshot.error}");
                    } else {
                      countText = '${snapshot.data ?? 0} tiles';
                      icon = Icons.storage_rounded;
                    }
                  }
                  return ListTile(
                    leading: Icon(icon),
                    title: const Text('Cached Tiles'),
                    trailing: Text(countText),
                    dense: true,
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
                child: Text(
                  'Download Radius: ${_selectedRadiusNM.round()} NM',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Slider(
                value: _selectedRadiusNM,
                min: _minRadiusNM,
                max: _maxRadiusNM,
                divisions: _sliderDivisions,
                label: '${_selectedRadiusNM.round()} NM',
                onChanged: _isDownloading ? null : (double value) {
                  setState(() {
                    _selectedRadiusNM = value;
                  });
                },
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveColor: Colors.grey[700],
              ),
              ListTile(
                leading: const Icon(Icons.download_for_offline),
                title: const Text('Download Map Area'),
                subtitle: Text(
                  'Download ${_selectedRadiusNM.round()} NM radius around home (Zooms 1-12)'),
                trailing: IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: _isDownloading || homeLocation == null ? null : _startDownload,
                ),
                enabled: homeLocation != null, // Disable if no home location
              ),
              if (_isDownloading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text(
                        'Downloading: ${_latestDownloadProgress == null ? 0 : _latestDownloadProgress!.percentageProgress.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: _latestDownloadProgress == null ? 0 : _latestDownloadProgress!.percentageProgress / 100,
                        backgroundColor: Colors.grey[700],
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                      ),
                       const SizedBox(height: 4),
                       Text(
                        _latestDownloadProgress == null
                            ? 'Starting...'
                            // Use more detailed progress info
                            : 'Tiles: ${_latestDownloadProgress!.successfulTilesCount}/${_latestDownloadProgress!.maxTilesCount} | Speed: ${_latestDownloadProgress!.tilesPerSecond.toStringAsFixed(1)}/s | Est: ~${_latestDownloadProgress!.estRemainingDuration.inMinutes} min',
                         style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[400]),
                       ),
                    ],
                  ),
                ),
               const Divider(),
               ListTile(
                leading: Icon(Icons.delete_forever, color: Colors.red[400]),
                title: Text('Clear Tile Cache',
                    style: TextStyle(color: Colors.red[400])),
                subtitle: const Text('Delete all downloaded map tiles'),
                onTap: _isDownloading ? null : _clearCache,
               ),
            ],
          ),
        );
      },
    );
  }
}