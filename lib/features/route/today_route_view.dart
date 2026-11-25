import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:physical_therapy/core/services/maps_service.dart';
import 'package:physical_therapy/core/utils/date_helper.dart';
import 'package:physical_therapy/core/utils/maps_route_builder.dart';
import 'package:physical_therapy/providers/patient_provider.dart';
import 'package:physical_therapy/providers/session_provider.dart';
import 'package:physical_therapy/widgets/gradient_card.dart';
import 'package:provider/provider.dart';

class TodayRouteView extends StatelessWidget {
  const TodayRouteView({super.key});

  static const String _appId = 'com.example.physical_therapy';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final sessionProvider = context.watch<SessionProvider>();
    final patientProvider = context.watch<PatientProvider>();

    final patientsMap = {for (var p in patientProvider.patients) p.id: p};
    final todaySessions = sessionProvider.todaySessions;

    final stops = MapsRouteBuilder.buildTodayRoute(
      todaySessions: todaySessions,
      patientsMap: patientsMap,
    );

    // Initial center point: first stop location, or default to Cairo (30.0444, 31.2357)
    final initialCenter = stops.isNotEmpty
        ? stops.first.location
        : const LatLng(30.0444, 31.2357);

    return Scaffold(
      appBar: AppBar(
        title: const Text('خريطة اليوم'),
      ),
      body: stops.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.map_outlined,
                      size: 64,
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد جلسات منزلية محددة الموقع لليوم',
                      style: textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'تأكد من تسجيل الموقع الجغرافي للمرضى أصحاب جلسات اليوم',
                      style: textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                // ── Interactive Map ──────────────────────────────────────────
                Expanded(
                  flex: 3,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: initialCenter,
                      initialZoom: 13.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: _appId,
                      ),
                      if (stops.length > 1)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: stops.map((s) => s.location).toList(),
                              strokeWidth: 4.0,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: stops.map((stop) {
                          return Marker(
                            point: stop.location,
                            width: 38,
                            height: 38,
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${stop.stopNumber}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                // ── Action Banner ────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  color: theme.colorScheme.surface,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'مسار الزيارات (${stops.length} محطات)',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final uri = MapsRouteBuilder.buildDirectionsUri(stops);
                          final ok = await MapsService.openRouteDirections(uri);
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تعذر فتح تطبيق الخرائط')),
                            );
                          }
                        },
                        icon: const Icon(Icons.navigation, size: 18),
                        label: const Text('ابدأ الطريق'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // ── Stops List ───────────────────────────────────────────────
                Expanded(
                  flex: 2,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12.0),
                    itemCount: stops.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final stop = stops[index];
                      return GradientCard(
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: theme.colorScheme.primary,
                            child: Text(
                              '${stop.stopNumber}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          title: Text(
                            stop.patient.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'الساعة ${DateHelper.formatTime(stop.session.date)} • ${stop.patient.address.isNotEmpty ? stop.patient.address : 'عنوان غير محدد'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.directions),
                            tooltip: 'الاتجاهات لهذه المحطة',
                            onPressed: () {
                              MapsService.openGoogleMaps(
                                stop.location.latitude,
                                stop.location.longitude,
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
