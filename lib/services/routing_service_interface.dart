import 'package:latlong2/latlong.dart';

class RouteResult {
  final List<LatLng> polylinePoints;
  final double distanceMeters;
  final double durationSeconds;
  final String etaText;

  RouteResult({
    required this.polylinePoints,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.etaText,
  });
}

abstract class IRoutingService {
  Future<RouteResult?> fetchRoadRoute(LatLng origin, LatLng destination);
}
