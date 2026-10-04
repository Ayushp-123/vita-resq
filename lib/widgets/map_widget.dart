import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class RealMapWidget extends StatelessWidget {
  final Position? initialPosition;
  final LatLng? centerLatLng;
  final double initialZoom;
  final List<Marker>? extraMarkers;
  final List<Polyline>? polylines;
  final MapController? mapController;

  const RealMapWidget({
    super.key,
    this.initialPosition,
    this.centerLatLng,
    this.initialZoom = 16.0,
    this.extraMarkers,
    this.polylines,
    this.mapController,
  }) : assert(initialPosition != null || centerLatLng != null,
            'Either initialPosition or centerLatLng must be provided');

  @override
  Widget build(BuildContext context) {
    final LatLng center = centerLatLng ??
        LatLng(
          initialPosition!.latitude,
          initialPosition!.longitude,
        );

    final List<Marker> markers = [
      if (initialPosition != null && centerLatLng == null)
        Marker(
          point: center,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.my_location,
            color: Colors.blue,
            size: 32,
          ),
        ),
      if (extraMarkers != null) ...extraMarkers!,
    ];

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: initialZoom,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.jan_sarthi',
        ),
        if (polylines != null && polylines!.isNotEmpty)
          PolylineLayer(polylines: polylines!),
        MarkerLayer(markers: markers),
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }
}
