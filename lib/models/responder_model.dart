import 'package:cloud_firestore/cloud_firestore.dart';

enum ResponderRole {
  PRIMARY,
  STANDBY,
  SECONDARY,
}

enum ResponderStatus {
  SEARCHING,
  PRIMARY,
  STANDBY,
  RESPONDING,
  DELAYED,
  AT_RISK,
  ARRIVED,
  ASSISTING,
  COMPLETED,
  UNAVAILABLE,
  REPLACED,
}

class ResponderModel {
  final String userId;
  final String userName;
  final String? phoneNumber;
  final String? bloodGroup;
  final String userRole; // 'CITIZEN', 'AMBULANCE_DRIVER', 'POLICE_PCR'
  final String? vehicleNumber; // e.g. 'DL-04-108' or 'PCR-12'
  final ResponderRole role;
  final ResponderStatus status;
  final double latitude;
  final double longitude;
  final DateTime acceptedAt;
  final DateTime lastLocationUpdate;
  final DateTime? assignedAt;
  final double? distanceToVictim;
  final String? etaText;
  final double? etaMinutes;
  final String? problemReason;

  ResponderModel({
    required this.userId,
    this.userName = 'Responder',
    this.phoneNumber,
    this.bloodGroup,
    this.userRole = 'CITIZEN',
    this.vehicleNumber,
    required this.role,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.acceptedAt,
    required this.lastLocationUpdate,
    this.assignedAt,
    this.distanceToVictim,
    this.etaText,
    this.etaMinutes,
    this.problemReason,
  });

  static DateTime parseDate(dynamic val) {
    if (val == null) return DateTime.now();
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String) {
      try {
        return DateTime.parse(val);
      } catch (_) {}
    }
    if (val is int) {
      return DateTime.fromMillisecondsSinceEpoch(val);
    }
    return DateTime.now();
  }

  factory ResponderModel.fromMap(Map<String, dynamic> map, String userId) {
    return ResponderModel(
      userId: userId,
      userName: map['userName'] ?? 'Responder',
      phoneNumber: map['phoneNumber'],
      bloodGroup: map['bloodGroup'],
      userRole: map['userRole'] ?? 'CITIZEN',
      vehicleNumber: map['vehicleNumber'],
      role: ResponderRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => ResponderRole.STANDBY,
      ),
      status: ResponderStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ResponderStatus.STANDBY,
      ),
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      acceptedAt: parseDate(map['acceptedAt']),
      lastLocationUpdate: parseDate(map['lastLocationUpdate']),
      assignedAt: map['assignedAt'] != null ? parseDate(map['assignedAt']) : null,
      distanceToVictim: (map['distanceToVictim'] as num?)?.toDouble(),
      etaText: map['etaText'],
      etaMinutes: (map['etaMinutes'] as num?)?.toDouble(),
      problemReason: map['problemReason'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'phoneNumber': phoneNumber,
      'bloodGroup': bloodGroup,
      'userRole': userRole,
      'vehicleNumber': vehicleNumber,
      'role': role.name,
      'status': status.name,
      'latitude': latitude,
      'longitude': longitude,
      'acceptedAt': Timestamp.fromDate(acceptedAt),
      'lastLocationUpdate': Timestamp.fromDate(lastLocationUpdate),
      'assignedAt': assignedAt != null ? Timestamp.fromDate(assignedAt!) : null,
      'distanceToVictim': distanceToVictim,
      'etaText': etaText,
      'etaMinutes': etaMinutes,
      'problemReason': problemReason,
    };
  }
}
