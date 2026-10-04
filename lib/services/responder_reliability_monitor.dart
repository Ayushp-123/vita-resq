import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/emergency_model.dart';
import '../models/responder_model.dart';

class ResponderReliabilityMonitor {
  final FirebaseFirestore? _firestore;
  final int noProgressThresholdSeconds;
  final int locationStaleThresholdSeconds;
  final int primaryMonitorIntervalSeconds;

  Timer? _monitorTimer;
  String? _monitoredEmergencyId;
  double? _lastRecordedDistance;
  DateTime? _lastProgressTimestamp;

  ResponderReliabilityMonitor({
    FirebaseFirestore? firestore,
    this.noProgressThresholdSeconds = AppConstants.noProgressThresholdSeconds,
    this.locationStaleThresholdSeconds = AppConstants.locationStaleThresholdSeconds,
    this.primaryMonitorIntervalSeconds = AppConstants.primaryMonitorIntervalSeconds,
  }) : _firestore = firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  /// Start monitoring reliability for an active emergency session
  void startMonitoring(String emergencyId) {
    _monitoredEmergencyId = emergencyId;
    _lastProgressTimestamp = DateTime.now();
    _lastRecordedDistance = null;

    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(
      Duration(seconds: primaryMonitorIntervalSeconds),
      (_) => _evaluatePrimaryReliability(),
    );
  }

  /// Stop reliability monitor
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitoredEmergencyId = null;
  }

  Future<void> _evaluatePrimaryReliability() async {
    if (_monitoredEmergencyId == null) return;

    DocumentSnapshot snap = await _db
        .collection(AppConstants.emergenciesCollection)
        .doc(_monitoredEmergencyId)
        .get();

    if (!snap.exists) return;
    var emergency = EmergencyModel.fromMap(snap.data() as Map<String, dynamic>, snap.id);

    // Only monitor active emergencies with assigned Primary Helper
    if (emergency.status == EmergencyStatus.COMPLETED ||
        emergency.status == EmergencyStatus.CANCELLED ||
        emergency.helperId == null) {
      return;
    }

    ResponderModel? primary = emergency.primaryResponder;
    if (primary == null) return;

    DateTime now = DateTime.now();

    // 1. Check Location Staleness (heartbeat freshness)
    int secondsSinceLastUpdate = now.difference(primary.lastLocationUpdate).inSeconds;
    bool isLocationStale = secondsSinceLastUpdate > locationStaleThresholdSeconds;

    // 2. Check Progress toward Victim
    double currentDistance = _calculateDistance(
      primary.latitude,
      primary.longitude,
      emergency.latitude,
      emergency.longitude,
    );

    if (_lastRecordedDistance == null || currentDistance < (_lastRecordedDistance! - 5.0)) {
      _lastRecordedDistance = currentDistance;
      _lastProgressTimestamp = now;
    }

    int secondsWithoutProgress = _lastProgressTimestamp != null
        ? now.difference(_lastProgressTimestamp!).inSeconds
        : 0;

    // A responder is considered stalled only if no progress has been made for >= noProgressThresholdSeconds (120s)
    bool isNoProgress = secondsWithoutProgress > noProgressThresholdSeconds;

    // 3. Evaluate AT_RISK Condition
    if (isLocationStale || isNoProgress || primary.status == ResponderStatus.AT_RISK) {
      if (primary.status != ResponderStatus.AT_RISK) {
        await _markPrimaryAtRisk(_monitoredEmergencyId!, primary.userId);
      }
      // Attempt Automatic Handover / Standby Promotion
      await promoteStandbyToPrimary(_monitoredEmergencyId!);
    }
  }

  /// Mark current Primary as AT_RISK
  Future<void> _markPrimaryAtRisk(String emergencyId, String primaryUserId) async {
    DocumentReference emergencyRef = _db
        .collection(AppConstants.emergenciesCollection)
        .doc(emergencyId);

    await _db.runTransaction((transaction) async {
      DocumentSnapshot snap = await transaction.get(emergencyRef);
      if (!snap.exists) return;

      var data = snap.data() as Map<String, dynamic>;
      Map<String, dynamic> responders =
          data['responders'] != null ? Map<String, dynamic>.from(data['responders']) : {};

      if (responders.containsKey(primaryUserId)) {
        var pData = Map<String, dynamic>.from(responders[primaryUserId]);
        pData['status'] = ResponderStatus.AT_RISK.name;
        responders[primaryUserId] = pData;

        transaction.update(emergencyRef, {
          'responders': responders,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// Promote nearest suitable Standby responder to Primary
  Future<bool> promoteStandbyToPrimary(String emergencyId) async {
    DocumentReference emergencyRef = _db
        .collection(AppConstants.emergenciesCollection)
        .doc(emergencyId);

    bool promoted = false;

    try {
      await _db.runTransaction((transaction) async {
        DocumentSnapshot snap = await transaction.get(emergencyRef);
        if (!snap.exists) return;

        var data = snap.data() as Map<String, dynamic>;
        var emergency = EmergencyModel.fromMap(data, snap.id);

        String? oldPrimaryId = emergency.helperId;
        Map<String, dynamic> responders = Map<String, dynamic>.from(data['responders'] ?? {});
        List<ResponderModel> standbyList = emergency.standbyResponders;

        if (standbyList.isEmpty) {
          // No standby responder available -> Demote old primary to STANDBY / AT_RISK and reset emergency to SEARCHING
          if (oldPrimaryId != null && responders.containsKey(oldPrimaryId)) {
            var oldData = Map<String, dynamic>.from(responders[oldPrimaryId]);
            oldData['role'] = ResponderRole.STANDBY.name;
            oldData['status'] = ResponderStatus.AT_RISK.name;
            responders[oldPrimaryId] = oldData;
          }

          transaction.update(emergencyRef, {
            'helperId': '',
            'status': AppConstants.statusSearching,
            'responders': responders,
            'lastHelperLocation': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return;
        }

        // Sort standby candidates by distance to victim
        standbyList.sort((a, b) {
          double distA = _calculateDistance(a.latitude, a.longitude, emergency.latitude, emergency.longitude);
          double distB = _calculateDistance(b.latitude, b.longitude, emergency.latitude, emergency.longitude);
          return distA.compareTo(distB);
        });

        ResponderModel bestCandidate = standbyList.first;

        // Demote old Primary to STANDBY
        if (oldPrimaryId != null && responders.containsKey(oldPrimaryId)) {
          var oldData = Map<String, dynamic>.from(responders[oldPrimaryId]);
          oldData['role'] = ResponderRole.STANDBY.name;
          oldData['status'] = ResponderStatus.REPLACED.name;
          responders[oldPrimaryId] = oldData;
        }

        // Promote candidate to PRIMARY
        var candidateData = Map<String, dynamic>.from(responders[bestCandidate.userId]);
        candidateData['role'] = ResponderRole.PRIMARY.name;
        candidateData['status'] = ResponderStatus.RESPONDING.name;
        candidateData['assignedAt'] = Timestamp.now();
        responders[bestCandidate.userId] = candidateData;

        transaction.update(emergencyRef, {
          'helperId': bestCandidate.userId,
          'status': AppConstants.statusAssigned,
          'responders': responders,
          'lastHelperLocation': {
            'latitude': bestCandidate.latitude,
            'longitude': bestCandidate.longitude,
            'updatedAt': DateTime.now().toIso8601String(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });

        promoted = true;
      });

      return promoted;
    } catch (e) {
      return false;
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    double dLat = (lat2 - lat1) * (pi / 180.0);
    double dLon = (lon2 - lon1) * (pi / 180.0);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180.0)) * cos(lat2 * (pi / 180.0)) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }
}
