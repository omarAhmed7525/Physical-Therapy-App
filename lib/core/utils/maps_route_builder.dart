import 'package:latlong2/latlong.dart';
import 'package:physical_therapy/models/patient_model.dart';
import 'package:physical_therapy/models/session_model.dart';

/// One stop on today's home-visit route.
class RouteStop {
  final int stopNumber;
  final SessionModel session;
  final PatientModel patient;
  final LatLng location;

  const RouteStop({
    required this.stopNumber,
    required this.session,
    required this.patient,
    required this.location,
  });
}

/// Pure helper for building and ordering today's home-visit route.
abstract class MapsRouteBuilder {
  /// Builds sorted stops from today's sessions for patients who have coordinates.
  /// Sessions are ordered chronologically by session date/time.
  static List<RouteStop> buildTodayRoute({
    required List<SessionModel> todaySessions,
    required Map<String, PatientModel> patientsMap,
  }) {
    final validSessions = todaySessions.where((s) {
      if (s.status == SessionStatus.cancelled) return false;
      final patient = patientsMap[s.patientId];
      return patient != null && patient.location != null;
    }).toList();

    // Sort chronologically by time
    validSessions.sort((a, b) => a.date.compareTo(b.date));

    final stops = <RouteStop>[];
    for (int i = 0; i < validSessions.length; i++) {
      final s = validSessions[i];
      final p = patientsMap[s.patientId]!;
      stops.add(
        RouteStop(
          stopNumber: i + 1,
          session: s,
          patient: p,
          location: LatLng(p.location!.latitude, p.location!.longitude),
        ),
      );
    }

    return stops;
  }

  /// Builds a Google Maps Directions URL for navigation through the stops in order.
  static Uri buildDirectionsUri(List<RouteStop> stops) {
    if (stops.isEmpty) return Uri.parse('https://www.google.com/maps');

    if (stops.length == 1) {
      final loc = stops.first.location;
      return Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${loc.latitude},${loc.longitude}',
      );
    }

    final dest = stops.last.location;
    final waypoints = stops
        .sublist(0, stops.length - 1)
        .map((s) => '${s.location.latitude},${s.location.longitude}')
        .join('|');

    return Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${dest.latitude},${dest.longitude}&waypoints=${Uri.encodeComponent(waypoints)}',
    );
  }
}
