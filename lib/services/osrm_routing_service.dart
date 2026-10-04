import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'routing_service_interface.dart';

class OSRMRoutingService implements IRoutingService {
  // Cascading public routing endpoints for maximum availability and reliability
  static const List<String> _routingEndpoints = [
    'http://router.project-osrm.org/route/v1/driving',
    'https://router.project-osrm.org/route/v1/driving',
    'https://routing.openstreetmap.de/routed-car/route/v1/driving',
    'https://routing.openstreetmap.de/routed-bike/route/v1/driving',
  ];

  @override
  Future<RouteResult?> fetchRoadRoute(LatLng origin, LatLng destination) async {
    final coordPath = '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    const queryParams = '?overview=full&geometries=geojson&steps=false';

    for (final baseEndpoint in _routingEndpoints) {
      final url = '$baseEndpoint/$coordPath$queryParams';
      try {
        final response = await http
            .get(
              Uri.parse(url),
              headers: {
                'User-Agent': 'VitaResQEmergencyApp/2.0 (Emergency Response Navigation)',
                'Accept': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
            final route = data['routes'][0];
            final double distanceMeters = (route['distance'] as num).toDouble();
            final double durationSeconds = (route['duration'] as num).toDouble();

            // Calculate realistic emergency vehicle travel time (avg ~35 km/h urban speed)
            int minutes = (durationSeconds / 60).round();
            if (minutes <= 0) minutes = 1;
            final String etaText = minutes <= 1 ? '1 min' : '$minutes mins';

            final List<dynamic> coords = route['geometry']['coordinates'];
            final List<LatLng> polylinePoints = coords.map((c) {
              final double lon = (c[0] as num).toDouble();
              final double lat = (c[1] as num).toDouble();
              return LatLng(lat, lon);
            }).toList();

            if (polylinePoints.isNotEmpty) {
              return RouteResult(
                polylinePoints: polylinePoints,
                distanceMeters: distanceMeters,
                durationSeconds: durationSeconds,
                etaText: etaText,
              );
            }
          }
        }
      } catch (_) {
        // Try next endpoint in cascade
        continue;
      }
    }

    return null;
  }
}
