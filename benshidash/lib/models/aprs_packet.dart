// models/aprs_packet.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// A basic model for a parsed APRS packet.
class AprsPacket {
  final String raw;
  final String source;
  final String destination;
  final List<String> path;
  final String body;

  // Parsed data
  final double? latitude;
  final double? longitude;
  final String? comment;
  final String? symbolTable;
  final String? symbolCode;

  AprsPacket({
    required this.raw,
    required this.source,
    required this.destination,
    required this.path,
    required this.body,
    this.latitude,
    this.longitude,
    this.comment,
    this.symbolTable,
    this.symbolCode,
  });

  /// --- MODIFIED: This factory is now more robust against different APRS formats ---
  /// It parses a raw binary AX.25 frame from the radio.
  static AprsPacket? fromAX25Frame(Uint8List frameBytes) {
    try {
      if (frameBytes.length < 16) {
        // Frame is too short to contain a valid header and UI Frame identifiers.
        return null;
      }

      // The source callsign is the second 7-byte address field.
      final sourceAddressBytes = frameBytes.sublist(7, 14);
      final sourceCallsign = _decodeAX25Address(sourceAddressBytes);

      // The APRS information payload follows a control byte (0x03) and protocol ID (0xF0).
      // This is the standard way to identify the start of the APRS data.
      int infoStartIndex = -1;
      for (int i = 14; i < frameBytes.length - 1; i++) {
        if (frameBytes[i] == 0x03 && frameBytes[i + 1] == 0xF0) {
          infoStartIndex = i + 2;
          break;
        }
      }

      // If we didn't find the UI Frame identifier, it's not a packet we can parse.
      if (infoStartIndex == -1) {
        return null;
      }

      final bodyString = ascii.decode(frameBytes.sublist(infoStartIndex));

      // Reconstruct a string that our existing string parser can handle.
      final parsableString = '$sourceCallsign>APRSTARGET:$bodyString';

      // Reuse the simple string parser for the info field content.
      return AprsPacket.fromString(parsableString);

    } catch (e) {
      // If any part of the parsing fails (invalid characters, etc.),
      // just ignore the packet instead of crashing.
      return null;
    }
  }

  /// Decodes a 7-byte AX.25 address field (callsign + SSID).
  static String _decodeAX25Address(Uint8List addressBytes) {
    final chars = <String>[];
    for (int i = 0; i < 6; i++) {
      final charCode = addressBytes[i] >> 1;
      if (charCode > 32) {
        chars.add(String.fromCharCode(charCode));
      }
    }
    final callsign = chars.join('').trim();

    final ssidByte = addressBytes[6];
    final ssid = (ssidByte >> 1) & 0x0F;

    return ssid > 0 ? '$callsign-$ssid' : callsign;
  }

  /// A very basic parser for APRS position reports from a string.
  static AprsPacket? fromString(String raw) {
    try {
      final parts = raw.split(':');
      if (parts.length < 2) return null;

      final header = parts[0];
      final body = parts.sublist(1).join(':').trim();

      final headerParts = header.split('>');
      if (headerParts.length < 2) return null;

      final source = headerParts[0];
      final destAndPath = headerParts[1].split(',');
      final destination = destAndPath[0];
      final path = destAndPath.length > 1 ? destAndPath.sublist(1) : <String>[];

      // Check for different position report formats
      final dataType = body.isNotEmpty ? body[0] : '';
      if ((dataType == '!' || dataType == '=' || dataType == '/' || dataType == '@') && body.length >= 18) {
        String latStr, lonStr, table, code;
        String? comment;

        // Uncompressed format: !DDMM.mmN/DDDMM.mmW#
        if (dataType == '!' || dataType == '=') {
          latStr = body.substring(1, 9);
          lonStr = body.substring(10, 19);
          table = body.substring(9, 10);
          code = body.substring(19, 20);
          comment = body.length > 20 ? body.substring(20) : '';
        }
        // Compressed format: /DDMM.mmN#DDDMM.mmW#
        else if(dataType == '/' || dataType == '@') {
          latStr = body.substring(1, 9);
          lonStr = body.substring(10, 19);
          table = body.substring(0,1); // Symbol table is part of the data type
          code = body.substring(9,10);
          comment = body.length > 19 ? body.substring(19) : '';
        } else {
            return null; // Not a format we can handle
        }

        double? parseCoord(String coord, int degLen) {
          final isNegative = coord.endsWith('S') || coord.endsWith('W');
          final deg = double.tryParse(coord.substring(0, degLen));
          final min = double.tryParse(coord.substring(degLen, coord.length - 1));
          if (deg == null || min == null) return null;
          double val = deg + min / 60.0;
          return isNegative ? -val : val;
        }

        final lat = parseCoord(latStr, 2);
        final lon = parseCoord(lonStr, 3);

        if (lat != null && lon != null) {
          return AprsPacket(
            raw: raw,
            source: source,
            destination: destination,
            path: path,
            body: body,
            latitude: lat,
            longitude: lon,
            symbolTable: table,
            symbolCode: code,
            comment: comment,
          );
        }
      }

      // If not a position packet, return a basic packet
      return AprsPacket(
        raw: raw,
        source: source,
        destination: destination,
        path: path,
        body: body,
      );
    } catch (e) {
      return null;
    }
  }

  IconData get symbolIcon {
    switch (symbolCode) {
      case '>':
      case '-':
        return Icons.directions_car;
      case 'R':
        return Icons.router;
      case 'W':
        return Icons.cloud;
      case 'h':
        return Icons.home;
      default:
        return Icons.location_pin;
    }
  }
}