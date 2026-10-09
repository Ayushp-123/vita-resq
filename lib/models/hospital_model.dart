import 'package:latlong2/latlong.dart';

/// Represents a medical facility or hospital prepared for emergency transport routing.
class HospitalModel {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final double? durationSeconds;
  final String? etaText;
  final String? address;
  final String? phoneNumber;
  final String type; // 'Trauma Center', 'General Hospital', 'Government Hospital', etc.
  final bool isGovernmentTraumaCenter;

  const HospitalModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    this.durationSeconds,
    this.etaText,
    this.address,
    this.phoneNumber,
    this.type = 'General Hospital',
    this.isGovernmentTraumaCenter = false,
  });

  LatLng get location => LatLng(latitude, longitude);

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()}m';
    } else {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
  }

  HospitalModel copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    double? distanceMeters,
    double? durationSeconds,
    String? etaText,
    String? address,
    String? phoneNumber,
    String? type,
    bool? isGovernmentTraumaCenter,
  }) {
    return HospitalModel(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      etaText: etaText ?? this.etaText,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      type: type ?? this.type,
      isGovernmentTraumaCenter: isGovernmentTraumaCenter ?? this.isGovernmentTraumaCenter,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'distanceMeters': distanceMeters,
      'durationSeconds': durationSeconds,
      'etaText': etaText,
      'address': address,
      'phoneNumber': phoneNumber,
      'type': type,
      'isGovernmentTraumaCenter': isGovernmentTraumaCenter,
    };
  }

  factory HospitalModel.fromMap(Map<String, dynamic> map) {
    return HospitalModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Nearby Medical Center',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (map['durationSeconds'] as num?)?.toDouble(),
      etaText: map['etaText'] as String?,
      address: map['address'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      type: map['type'] as String? ?? 'General Hospital',
      isGovernmentTraumaCenter: map['isGovernmentTraumaCenter'] as bool? ?? false,
    );
  }

  @override
  String toString() => 'HospitalModel($name, distance: $formattedDistance)';
}
