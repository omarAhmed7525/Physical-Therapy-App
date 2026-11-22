import 'package:url_launcher/url_launcher.dart';

class MapsService {
  static Future<bool> openGoogleMaps(double latitude, double longitude) async {
    final String googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    final Uri uri = Uri.parse(googleMapsUrl);

    if (await canLaunchUrl(uri)) {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } else {
      // Try a simpler geo scheme if https fails
      final Uri geoUri = Uri.parse('geo:$latitude,$longitude');
      if (await canLaunchUrl(geoUri)) {
        return await launchUrl(geoUri);
      }
      return false;
    }
  }

  /// Launches Google Maps Navigation / Directions for a full route.
  static Future<bool> openRouteDirections(Uri directionsUri) async {
    if (await canLaunchUrl(directionsUri)) {
      return await launchUrl(
        directionsUri,
        mode: LaunchMode.externalApplication,
      );
    }
    return false;
  }
}
