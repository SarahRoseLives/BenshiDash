import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

// MODIFIED: Enum moved here and 'debug' added.
enum GpsSource { radio, device, debug }

class LocationService extends ChangeNotifier {
  Position? currentPosition;
  StreamSubscription<Position>? _positionStream;
  bool _isListening = false;

  // NEW: Static debug position for Jefferson, OH
  static final Position debugPosition = Position(
    latitude: 41.7370,
    longitude: -80.7942,
    timestamp: DateTime.now(),
    accuracy: 10.0,
    altitude: 270.0,
    altitudeAccuracy: 10.0,
    heading: 0.0,
    headingAccuracy: 10.0,
    speed: 0.0,
    speedAccuracy: 0.0,
  );


  /// --- NEW: Get a single location update ---
  /// This is useful for features that need a one-time location check.
  Future<Position>determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> start() async {
    if (_isListening) return;

    // Use the new helper to check permissions first
    try {
      await determinePosition();
    } catch (e) {
      print("Could not start location service: $e");
      return;
    }

    _isListening = true;
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position? position) {
      if (position != null) {
        currentPosition = position;
        notifyListeners();
      }
    });
  }

  void stop() {
    _positionStream?.cancel();
    _isListening = false;
  }
}

final LocationService locationService = LocationService();