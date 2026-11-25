import 'dart:io';

import 'package:latlong2/latlong.dart';

/// Pure parser for extracting [LatLng] from Google Maps URLs or plain coordinate strings.
///
/// Supported formats:
/// - `@lat,lng` (e.g. `https://www.google.com/maps/@30.0444,31.2357,15z`)
/// - `q=lat,lng`, `ll=lat,lng`, `query=lat,lng`
/// - `!3dLAT!4dLNG`
/// - Plain `"lat, lng"`
LatLng? parseLatLngFromMapsUrl(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  // 1. Plain "lat, lng"
  final plainMatch = RegExp(
    r'^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$',
  ).firstMatch(trimmed);
  if (plainMatch != null) {
    return _validLatLng(plainMatch.group(1)!, plainMatch.group(2)!);
  }

  // 2. !3dLAT!4dLNG
  final bangMatch = RegExp(
    r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)',
  ).firstMatch(trimmed);
  if (bangMatch != null) {
    return _validLatLng(bangMatch.group(1)!, bangMatch.group(2)!);
  }

  // 3. @lat,lng
  final atMatch = RegExp(
    r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)',
  ).firstMatch(trimmed);
  if (atMatch != null) {
    return _validLatLng(atMatch.group(1)!, atMatch.group(2)!);
  }

  // 4. q=lat,lng | ll=lat,lng | query=lat,lng
  final queryMatch = RegExp(
    r'(?:[?&](?:q|ll|query)=)(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)',
  ).firstMatch(trimmed);
  if (queryMatch != null) {
    return _validLatLng(queryMatch.group(1)!, queryMatch.group(2)!);
  }

  return null;
}

LatLng? _validLatLng(String latStr, String lngStr) {
  final lat = double.tryParse(latStr);
  final lng = double.tryParse(lngStr);
  if (lat == null || lng == null) return null;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  return LatLng(lat, lng);
}

/// Returns true if [url] is a short Google Maps link that needs HTTP redirect resolution.
bool isShortMapsUrl(String url) {
  final lower = url.toLowerCase();
  return lower.contains('maps.app.goo.gl') || lower.contains('goo.gl/maps');
}

/// Resolves redirects for short Google Maps links using `dart:io` [HttpClient]
/// (max 5 hops, 8-second timeout) and parses the final URL.
Future<LatLng?> resolveAndParseMapsUrl(String rawUrl) async {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return null;

  final direct = parseLatLngFromMapsUrl(trimmed);
  if (direct != null) return direct;

  if (!isShortMapsUrl(trimmed)) return null;

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    Uri current = Uri.parse(trimmed);
    for (int hop = 0; hop < 5; hop++) {
      final request = await client
          .getUrl(current)
          .timeout(const Duration(seconds: 8));
      request.followRedirects = false;
      final response = await request.close().timeout(const Duration(seconds: 8));
      await response.drain<void>();

      final location = response.headers.value(HttpHeaders.locationHeader);
      if (location == null || location.isEmpty) {
        break;
      }

      current = current.resolve(location);
      final parsed = parseLatLngFromMapsUrl(current.toString());
      if (parsed != null) return parsed;
    }
    return parseLatLngFromMapsUrl(current.toString());
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}
