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

  static AprsPacket? fromAX25Frame(Uint8List frameBytes) {
    try {
      if (frameBytes.length < 14) return null;

      final destAddressBytes = frameBytes.sublist(0, 7);
      final sourceAddressBytes = frameBytes.sublist(7, 14);
      final destination = _decodeAX25Address(destAddressBytes);
      final source = _decodeAX25Address(sourceAddressBytes);

      final path = <String>[];
      int pathEndIndex = 14;

      for (int i = 14; i < frameBytes.length - 1; i += 7) {
        if (i + 7 > frameBytes.length) {
            pathEndIndex = i;
            break;
        }
        final digiBytes = frameBytes.sublist(i, i + 7);
        path.add(_decodeAX25Address(digiBytes));
        if ((digiBytes[6] & 0x01) == 1) {
          pathEndIndex = i + 7;
          break;
        }
      }

      int infoStartIndex = -1;
      for (int i = pathEndIndex; i < frameBytes.length - 1; i++) {
        if (frameBytes[i] == 0x03 && frameBytes[i+1] == 0xF0) {
          infoStartIndex = i + 2;
          break;
        }
      }

      if (infoStartIndex == -1) return null;

      final bodyString = ascii.decode(frameBytes.sublist(infoStartIndex));

      final constructedRaw = '$source>$destination,${path.join(',')}:$bodyString';
      final packet = AprsPacket.fromString(constructedRaw);

      if (packet == null) return null;

      return AprsPacket(
        raw: packet.raw,
        source: packet.source,
        destination: packet.destination,
        path: path,
        body: packet.body,
        latitude: packet.latitude,
        longitude: packet.longitude,
        symbolTable: packet.symbolTable,
        symbolCode: packet.symbolCode,
        comment: packet.comment
      );

    } catch (e) {
      return null;
    }
  }

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
      // --- FIX: Ensure path from string is correctly assigned ---
      final path = destAndPath.length > 1 ? destAndPath.sublist(1) : <String>[];

      final dataType = body.isNotEmpty ? body[0] : '';
      if ((dataType == '!' || dataType == '=' || dataType == '/' || dataType == '@') && body.length >= 18) {
        String latStr, lonStr, table, code;
        String? comment;

        if (dataType == '!' || dataType == '=') {
          latStr = body.substring(1, 9);
          lonStr = body.substring(10, 19);
          table = body.substring(9, 10);
          code = body.substring(19, 20);
          comment = body.length > 20 ? body.substring(20) : '';
        }
        else if(dataType == '/' || dataType == '@') {
          latStr = body.substring(1, 9);
          lonStr = body.substring(10, 19);
          table = body.substring(0,1);
          code = body.substring(9,10);
          comment = body.length > 19 ? body.substring(19) : '';
        } else {
            return null;
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