import 'package:cloud_firestore/cloud_firestore.dart';
import 'responder_model.dart';

enum EmergencyStatus {
  SEARCHING,
  ASSIGNED,
  APPROACHING,
  ARRIVED,
  COMPLETED,
  CANCELLED,
}

class EmergencyModel {
  final String id;
  final String victimId;
  final String type;
  final double latitude;
  final double longitude;
  final EmergencyStatus status;
  final String? helperId; // Primary Helper User ID
  final double currentRadiusMeters;
  final List<String> notifiedUserIds;
  final Map<String, ResponderModel> responders;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? lastVictimLocation;
  final Map<String, dynamic>? lastHelperLocation;

  EmergencyModel({
    required this.id,
    required this.victimId,
    this.type = 'MEDICAL',
    required this.latitude,
    required this.longitude,
    required this.status,
    this.helperId,
    this.currentRadiusMeters = 500.0,
    this.notifiedUserIds = const [],
    this.responders = const {},
    required this.createdAt,
    required this.updatedAt,
    this.lastVictimLocation,
    this.lastHelperLocation,
  });

  bool get isOffline => id.startsWith('JS-OFF-');

  bool get isActive =>
      status == EmergencyStatus.SEARCHING ||
      status == EmergencyStatus.ASSIGNED ||
      status == EmergencyStatus.APPROACHING ||
      status == EmergencyStatus.ARRIVED;

  bool get isClosed =>
      status == EmergencyStatus.COMPLETED ||
      status == EmergencyStatus.CANCELLED;

  bool get isTerminal => isClosed;

  bool get isClaimable =>
      isActive &&
      (status == EmergencyStatus.SEARCHING ||
          status == EmergencyStatus.ASSIGNED ||
          status == EmergencyStatus.APPROACHING);

  bool isVictim(String uid) => victimId == uid;

  bool isPrimaryResponder(String uid) {
    if (helperId == uid) return true;
    final r = responders[uid];
    return r?.role == ResponderRole.PRIMARY;
  }

  bool isStandbyResponder(String uid) {
    final r = responders[uid];
    return r?.role == ResponderRole.STANDBY;
  }

  ResponderRole? getRoleForUser(String uid) {
    return responders[uid]?.role;
  }

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

  factory EmergencyModel.fromMap(Map<String, dynamic> map, String id) {
    Map<String, ResponderModel> responderMap = {};
    if (map['responders'] != null && map['responders'] is Map) {
      (map['responders'] as Map).forEach((key, val) {
        if (val is Map) {
          responderMap[key.toString()] = ResponderModel.fromMap(
            Map<String, dynamic>.from(val),
            key.toString(),
          );
        }
      });
    }

    String statusStr = (map['status'] ?? 'SEARCHING').toString().toUpperCase();
    EmergencyStatus parsedStatus;
    if (statusStr == 'RESOLVED' || statusStr == 'ENDED' || statusStr == 'COMPLETED') {
      parsedStatus = EmergencyStatus.COMPLETED;
    } else if (statusStr == 'CANCELLED' || statusStr == 'CANCELED') {
      parsedStatus = EmergencyStatus.CANCELLED;
    } else {
      parsedStatus = EmergencyStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => EmergencyStatus.SEARCHING,
      );
    }

    return EmergencyModel(
      id: id,
      victimId: map['victimId'] ?? '',
      type: map['type'] ?? 'MEDICAL',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      status: parsedStatus,
      helperId: map['helperId'],
      currentRadiusMeters: (map['currentRadiusMeters'] as num?)?.toDouble() ?? 500.0,
      notifiedUserIds: List<String>.from(map['notifiedUserIds'] ?? []),
      responders: responderMap,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      lastVictimLocation: map['lastVictimLocation'] is Map
          ? Map<String, dynamic>.from(map['lastVictimLocation'])
          : null,
      lastHelperLocation: map['lastHelperLocation'] is Map
          ? Map<String, dynamic>.from(map['lastHelperLocation'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> responderData = {};
    responders.forEach((key, val) {
      responderData[key] = val.toMap();
    });

    return {
      'id': id,
      'victimId': victimId,
      'type': type,
      'latitude': latitude,
      'longitude': longitude,
      'status': status.name,
      'helperId': helperId,
      'currentRadiusMeters': currentRadiusMeters,
      'notifiedUserIds': notifiedUserIds,
      'responders': responderData,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastVictimLocation': lastVictimLocation,
      'lastHelperLocation': lastHelperLocation,
    };
  }

  /// Get the active PRIMARY responder
  ResponderModel? get primaryResponder {
    if (helperId != null && responders.containsKey(helperId)) {
      return responders[helperId];
    }
    for (var r in responders.values) {
      if (r.role == ResponderRole.PRIMARY) return r;
    }
    return null;
  }

  /// Get list of STANDBY responders
  List<ResponderModel> get standbyResponders {
    return responders.values
        .where((r) => r.role == ResponderRole.STANDBY)
        .toList();
  }
}
