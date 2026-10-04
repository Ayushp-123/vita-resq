import 'package:cloud_firestore/cloud_firestore.dart';
import 'impact_model.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phoneNumber;
  final String? bloodGroup;
  final String userRole; // 'CITIZEN', 'AMBULANCE_DRIVER', 'POLICE_PCR'
  final String? vehicleNumber; // e.g. 'DL-04-108' or 'PCR-12'
  final double? latitude;
  final double? longitude;
  final double? locationAccuracy;
  final DateTime? locationUpdatedAt;
  final String? fcmToken;
  final bool isOnline;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserImpactProfile impactProfile;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    this.bloodGroup,
    this.userRole = 'CITIZEN',
    this.vehicleNumber,
    this.latitude,
    this.longitude,
    this.locationAccuracy,
    this.locationUpdatedAt,
    this.fcmToken,
    this.isOnline = true,
    required this.createdAt,
    required this.updatedAt,
    this.impactProfile = const UserImpactProfile(),
  });

  int get impactPoints => impactProfile.impactPoints;
  int get verifiedAssists => impactProfile.verifiedAssists;
  double get reliabilityScore => impactProfile.reliabilityScore;

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    UserImpactProfile profile = const UserImpactProfile();
    if (map.containsKey('impactProfile') && map['impactProfile'] is Map) {
      profile = UserImpactProfile.fromMap(Map<String, dynamic>.from(map['impactProfile']));
    } else if (map.containsKey('impactPoints')) {
      profile = UserImpactProfile(
        impactPoints: (map['impactPoints'] as num?)?.toInt() ?? 0,
        verifiedAssists: (map['verifiedAssists'] as num?)?.toInt() ?? 0,
        victimsReached: (map['victimsReached'] as num?)?.toInt() ?? 0,
        totalAccepted: (map['totalAccepted'] as num?)?.toInt() ?? 0,
      );
    }

    return UserModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'],
      bloodGroup: map['bloodGroup'],
      userRole: map['userRole'] ?? 'CITIZEN',
      vehicleNumber: map['vehicleNumber'],
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      locationAccuracy: (map['locationAccuracy'] as num?)?.toDouble(),
      locationUpdatedAt: (map['locationUpdatedAt'] as Timestamp?)?.toDate(),
      fcmToken: map['fcmToken'],
      isOnline: map['isOnline'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      impactProfile: profile,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'bloodGroup': bloodGroup,
      'userRole': userRole,
      'vehicleNumber': vehicleNumber,
      'latitude': latitude,
      'longitude': longitude,
      'locationAccuracy': locationAccuracy,
      'locationUpdatedAt': locationUpdatedAt != null ? Timestamp.fromDate(locationUpdatedAt!) : null,
      'fcmToken': fcmToken,
      'isOnline': isOnline,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'impactProfile': impactProfile.toMap(),
      'impactPoints': impactProfile.impactPoints,
      'verifiedAssists': impactProfile.verifiedAssists,
      'reliabilityScore': impactProfile.reliabilityScore,
    };
  }
}
