// models/repeater.dart
import 'package:benshidash/benshi/protocol/protocol.dart';

class Repeater {
  final String callsign;
  final double outputFrequency;
  final double inputFrequency;
  final double? plTone;
  final String city;
  final String state;
  final double latitude;
  final double longitude;
  final String band;

  Repeater({
    required this.callsign,
    required this.outputFrequency,
    required this.inputFrequency,
    this.plTone,
    required this.city,
    required this.state,
    required this.latitude,
    required this.longitude,
    required this.band,
  });

  factory Repeater.fromJson(Map<String, dynamic> json) {
    // Helper to parse values that might be strings or numbers
    double? tryParseDouble(dynamic value) {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return Repeater(
      callsign: json['Callsign'] ?? 'N/A',
      outputFrequency: tryParseDouble(json['Frequency']) ?? 0.0,
      inputFrequency: tryParseDouble(json['Input Freq']) ?? 0.0,
      plTone: tryParseDouble(json['PL']),
      city: json['Nearest City'] ?? 'Unknown',
      state: json['State'] ?? '',
      latitude: tryParseDouble(json['Lat']) ?? 0.0,
      longitude: tryParseDouble(json['Lon']) ?? 0.0,
      band: _getBand(tryParseDouble(json['Frequency']) ?? 0.0),
    );
  }

  static String _getBand(double freq) {
    if (freq >= 144 && freq <= 148) return '2m';
    if (freq >= 420 && freq <= 450) return '70cm';
    return 'Other';
  }

  /// Converts this Repeater object into a radio Channel object.
  Channel toChannel(int channelId) {
    final name = callsign.length > 10 ? callsign.substring(0, 10) : callsign;
    return Channel(
      channelId: channelId,
      name: name,
      txMod: ModulationType.FM,
      rxMod: ModulationType.FM,
      txFreq: inputFrequency,
      rxFreq: outputFrequency,
      txSubAudio: plTone,
      rxSubAudio: plTone,
      scan: true, // Add to scan list by default
      txAtMaxPower: true,
      txAtMedPower: false,
      bandwidth: BandwidthType.NARROW, // Most repeaters are narrow
    );
  }
}