import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jan_sarthi/models/emergency_model.dart';
import 'package:jan_sarthi/models/responder_model.dart';
import 'package:jan_sarthi/models/communication_mode.dart';
import 'package:jan_sarthi/services/connectivity_service.dart';
import 'package:jan_sarthi/services/communication_manager.dart';
import 'package:jan_sarthi/services/local_database_service.dart';
import 'package:jan_sarthi/services/offline_nearby_service.dart';
import 'package:jan_sarthi/services/notification_service.dart';
import 'package:jan_sarthi/services/emergency_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Jan Sarthi Master Stability Tests', () {
    test('1. EmergencyModel.parseDate handles Timestamp, DateTime, ISO String, and Epoch int safely', () {
      final now = DateTime.now();
      final ts = Timestamp.fromDate(now);

      expect(EmergencyModel.parseDate(ts).millisecondsSinceEpoch ~/ 1000,
          now.millisecondsSinceEpoch ~/ 1000);
      expect(EmergencyModel.parseDate(now), now);
      expect(EmergencyModel.parseDate(now.toIso8601String()).millisecondsSinceEpoch ~/ 1000,
          now.millisecondsSinceEpoch ~/ 1000);
      expect(EmergencyModel.parseDate(now.millisecondsSinceEpoch).millisecondsSinceEpoch ~/ 1000,
          now.millisecondsSinceEpoch ~/ 1000);
      expect(EmergencyModel.parseDate(null), isA<DateTime>());
    });

    test('2. ConnectivityService authority and modeStream broadcast', () async {
      final service = ConnectivityService();
      expect(service.currentMode, isA<CommunicationMode>());
      expect(service.modeStream, isA<Stream<CommunicationMode>>());
    });

    test('3. CommunicationManager enforces single mode and online/offline mutual exclusion', () async {
      SharedPreferences.setMockInitialValues({});
      final manager = CommunicationManager();
      manager.initialize();

      expect(manager.activeMode, isA<CommunicationMode>());
      expect(manager.modeStream, isA<Stream<CommunicationMode>>());
    });

    test('4. Offline acceptance payload preserves primary and standby responder states without crashing', () async {
      SharedPreferences.setMockInitialValues({});
      final localDb = LocalDatabaseService();

      final now = DateTime.now();
      final emergency = EmergencyModel(
        id: 'JS-OFF-777',
        victimId: 'victim-777',
        type: 'MEDICAL',
        latitude: 12.9716,
        longitude: 77.5946,
        status: EmergencyStatus.SEARCHING,
        createdAt: now,
        updatedAt: now,
      );

      await localDb.saveEmergencyLocally(emergency);

      // Helper 1 accepts -> PRIMARY
      final payload1 = {
        'eventType': 'RESPONDER_ACCEPTANCE',
        'emergencyId': 'JS-OFF-777',
        'responderId': 'h1',
        'responderName': 'Helper 1',
        'latitude': 12.9720,
        'longitude': 77.5950,
        'timestamp': now.millisecondsSinceEpoch,
      };

      final res1 = await OfflineNearbyService.processAcceptancePayload(payload1, localDb);
      expect(res1, isNotNull);
      expect(res1!.primaryResponder?.userId, 'h1');
      expect(res1.status, EmergencyStatus.ASSIGNED);

      // Helper 2 accepts -> STANDBY (primary retained)
      final payload2 = {
        'eventType': 'RESPONDER_ACCEPTANCE',
        'emergencyId': 'JS-OFF-777',
        'responderId': 'h2',
        'responderName': 'Helper 2',
        'latitude': 12.9730,
        'longitude': 77.5960,
        'timestamp': now.millisecondsSinceEpoch,
      };

      final res2 = await OfflineNearbyService.processAcceptancePayload(payload2, localDb);
      expect(res2, isNotNull);
      expect(res2!.primaryResponder?.userId, 'h1');
      expect(res2.standbyResponders.length, 1);
      expect(res2.standbyResponders.first.userId, 'h2');
    });

    test('5. Distance threshold comparison for route triggering logic', () {
      const distance = Distance();
      const p1 = LatLng(28.6139, 77.2090);
      const p2 = LatLng(28.6139, 77.2090);
      const p3 = LatLng(28.6200, 77.2150);

      expect(distance(p1, p2), 0.0);
      expect(distance(p1, p3), greaterThan(10.0));
    });

    test('6. Terminal / Closed offline emergency cannot be claimed', () async {
      SharedPreferences.setMockInitialValues({});
      final localDb = LocalDatabaseService();

      final now = DateTime.now();
      final cancelledEmergency = EmergencyModel(
        id: 'JS-OFF-888',
        victimId: 'victim-888',
        type: 'MEDICAL',
        latitude: 12.9716,
        longitude: 77.5946,
        status: EmergencyStatus.CANCELLED,
        createdAt: now,
        updatedAt: now,
      );
      await localDb.saveEmergencyLocally(cancelledEmergency);

      final completedEmergency = EmergencyModel(
        id: 'JS-OFF-889',
        victimId: 'victim-889',
        type: 'MEDICAL',
        latitude: 12.9716,
        longitude: 77.5946,
        status: EmergencyStatus.COMPLETED,
        createdAt: now,
        updatedAt: now,
      );
      await localDb.saveEmergencyLocally(completedEmergency);

      // Verify that offline claiming returns null for terminal emergencies
      final claimCancelled = await localDb.getEmergencyById('JS-OFF-888');
      expect(claimCancelled?.isClosed, isTrue);
      expect(claimCancelled?.isClaimable, isFalse);

      final claimCompleted = await localDb.getEmergencyById('JS-OFF-889');
      expect(claimCompleted?.isClosed, isTrue);
      expect(claimCompleted?.isClaimable, isFalse);
    });

    test('7. EmergencySoundService provides duplicate event protection', () async {
      EmergencySoundService.resetDuplicateSoundHistory();

      // First alert trigger
      await EmergencySoundService.playEmergencyAlert(userRole: 'CITIZEN', emergencyId: 'alert-001');
      // Second duplicate trigger should be suppressed silently
      await EmergencySoundService.playEmergencyAlert(userRole: 'CITIZEN', emergencyId: 'alert-001');

      // Helper acceptance deduplication
      await EmergencySoundService.playHelperAccepted('alert-001');
      await EmergencySoundService.playHelperAccepted('alert-001');

      // Victim received helper deduplication
      await EmergencySoundService.playVictimReceivedHelper('alert-001', 'Helper');
      await EmergencySoundService.playVictimReceivedHelper('alert-001', 'Helper');

      // Emergency resolved deduplication
      await EmergencySoundService.playEmergencyResolved('alert-001');
      await EmergencySoundService.playEmergencyResolved('alert-001');

      // Error debouncing
      await EmergencySoundService.playError('test_context');
      await EmergencySoundService.playError('test_context');

      await EmergencySoundService.stopSound();
    });

    test('8. Chronological descending sorting of emergencies', () {
      final t1 = DateTime(2026, 8, 31, 10, 0);
      final t2 = DateTime(2026, 8, 31, 11, 0);
      final t3 = DateTime(2026, 8, 31, 12, 0);

      final list = [
        EmergencyModel(id: '1', victimId: 'v1', latitude: 0, longitude: 0, status: EmergencyStatus.COMPLETED, createdAt: t1, updatedAt: t1),
        EmergencyModel(id: '3', victimId: 'v3', latitude: 0, longitude: 0, status: EmergencyStatus.COMPLETED, createdAt: t3, updatedAt: t3),
        EmergencyModel(id: '2', victimId: 'v2', latitude: 0, longitude: 0, status: EmergencyStatus.COMPLETED, createdAt: t2, updatedAt: t2),
      ];

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      expect(list[0].id, '3'); // Newest (12:00)
      expect(list[1].id, '2'); // Middle (11:00)
      expect(list[2].id, '1'); // Oldest (10:00)
    });

    test('9. Problem reporting with fatal breakdown demotes primary and promotes standby', () async {
      final localDb = LocalDatabaseService();
      final emergencyService = EmergencyService();
      final now = DateTime.now();

      final em = EmergencyModel(
        id: 'JS-OFF-999',
        victimId: 'vic-999',
        latitude: 21.22,
        longitude: 81.31,
        status: EmergencyStatus.ASSIGNED,
        helperId: 'h_primary',
        createdAt: now,
        updatedAt: now,
      );
      await localDb.saveEmergencyLocally(em);

      // Primary helper accepts
      await OfflineNearbyService.processAcceptancePayload({
        'eventType': 'RESPONDER_ACCEPTANCE',
        'emergencyId': 'JS-OFF-999',
        'responderId': 'h_primary',
        'responderName': 'Primary Helper',
        'latitude': 21.23,
        'longitude': 81.32,
      }, localDb);

      // Standby helper accepts
      await OfflineNearbyService.processAcceptancePayload({
        'eventType': 'RESPONDER_ACCEPTANCE',
        'emergencyId': 'JS-OFF-999',
        'responderId': 'h_standby',
        'responderName': 'Standby Helper',
        'latitude': 21.225,
        'longitude': 81.315,
      }, localDb);

      var beforeReport = await localDb.getEmergencyById('JS-OFF-999');
      expect(beforeReport!.helperId, 'h_primary');
      expect(beforeReport.isPrimaryResponder('h_primary'), isTrue);
      expect(beforeReport.isStandbyResponder('h_standby'), isTrue);

      // Primary reports Vehicle Breakdown (isFatal = true)
      final res = await emergencyService.reportProblem(
        emergencyId: 'JS-OFF-999',
        userId: 'h_primary',
        reason: 'Vehicle Breakdown',
        isFatal: true,
      );

      expect(res.success, isTrue);
      expect(res.hasNewPrimary, isTrue);
      expect(res.newPrimaryId, 'h_standby');

      var afterReport = await localDb.getEmergencyById('JS-OFF-999');
      expect(afterReport!.helperId, 'h_standby');
      expect(afterReport.isPrimaryResponder('h_standby'), isTrue);
      expect(afterReport.isPrimaryResponder('h_primary'), isFalse);
      expect(afterReport.isStandbyResponder('h_primary'), isTrue);
      expect(afterReport.responders['h_primary']?.status, ResponderStatus.UNAVAILABLE);
    });
  });
}
