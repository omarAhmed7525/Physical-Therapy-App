import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:physical_therapy/core/utils/maps_url_parser.dart';

/// Interactive OpenStreetMap location picker returning a [LatLng] (or null).
class LocationPickerView extends StatefulWidget {
  final LatLng? initialLocation;
  final String? initialAddress;

  const LocationPickerView({
    super.key,
    this.initialLocation,
    this.initialAddress,
  });

  @override
  State<LocationPickerView> createState() => _LocationPickerViewState();
}

class _LocationPickerViewState extends State<LocationPickerView> {
  static const String _appId = 'com.example.physical_therapy';
  static const LatLng _defaultCairo = LatLng(30.0444, 31.2357);

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  late LatLng _center;
  bool _isSearching = false;
  bool _isLocating = false;
  bool _isResolvingUrl = false;

  @override
  void initState() {
    super.initState();
    _center = widget.initialLocation ?? _defaultCairo;
    if (widget.initialLocation == null &&
        widget.initialAddress != null &&
        widget.initialAddress!.trim().isNotEmpty) {
      _geocodeAddress(widget.initialAddress!.trim(), silentOnError: true);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _urlController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _parseAndMoveToUrl(String rawUrl) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return;
    setState(() => _isResolvingUrl = true);
    try {
      final loc = await resolveAndParseMapsUrl(trimmed);
      if (loc != null && mounted) {
        setState(() => _center = loc);
        _mapController.move(loc, 16.0);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر قراءة الرابط')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResolvingUrl = false);
      }
    }
  }

  Future<void> _geocodeAddress(String query, {bool silentOnError = false}) async {
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty && mounted) {
        final loc = LatLng(locations.first.latitude, locations.first.longitude);
        setState(() => _center = loc);
        _mapController.move(loc, 15.0);
      } else if (!silentOnError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر العثور على العنوان')),
        );
      }
    } catch (_) {
      if (!silentOnError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر العثور على العنوان')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر تحديد الموقع الحالي')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر تحديد الموقع الحالي')),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        final loc = LatLng(pos.latitude, pos.longitude);
        setState(() => _center = loc);
        _mapController.move(loc, 16.0);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحديد الموقع الحالي')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تحديد الموقع على الخريطة'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (val) => _geocodeAddress(val.trim()),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن عنوان',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.arrow_forward),
                              onPressed: () =>
                                  _geocodeAddress(_searchController.text.trim()),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: _isLocating ? null : _goToCurrentLocation,
                  tooltip: 'موقعي الحالي',
                  icon: _isLocating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 12.0),
            child: TextField(
              controller: _urlController,
              textInputAction: TextInputAction.done,
              onSubmitted: _parseAndMoveToUrl,
              decoration: InputDecoration(
                hintText: 'لصق رابط من خرائط جوجل',
                prefixIcon: const Icon(Icons.link),
                suffixIcon: _isResolvingUrl
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: () =>
                            _parseAndMoveToUrl(_urlController.text),
                      ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 15.0,
                    onPositionChanged: (position, hasGesture) {
                      _center = position.center;
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: _appId,
                    ),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('© OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
                Center(
                  child: IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 32.0),
                      child: Icon(
                        Icons.location_pin,
                        size: 44,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context, _center);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('تثبيت الموقع هنا'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
