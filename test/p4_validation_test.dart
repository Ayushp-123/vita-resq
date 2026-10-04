import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:jan_sarthi/models/emergency_model.dart';
import 'package:jan_sarthi/models/responder_model.dart';
import 'package:jan_sarthi/services/accident_detection_evaluator.dart';
import 'package:jan_sarthi/services/accident_detection_service.dart';
import 'package:jan_sarthi/services/local_database_service.dart';
import 'package:jan_sarthi/services/offline_nearby_service.dart';
import 'package:jan_sarthi/services/p2p_payload_integrity.dart';
import 'package:jan_sarthi/services/offline_communication_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P4 — Release Hardening & Sensor/Dual-Transport Validation Tests', () {
    late LocalDatabaseService localDb;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      localDb = LocalDatabaseService();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'requestPermissions') {
            return <int, int>{0: 1, 1: 1, 2: 1, 3: 1, 4: 1, 5: 1};
          }
          if (methodCall.method == 'checkPermissionStatus') {
            return 1;
          }
          return 1;
        },
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('nearby_connections'),
        (MethodCall methodCall) async {
          return true;
        },
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/sensors/method'),
        (MethodCall methodCall) async {
          return null;
        },
      );
    });

    // -------------------------------------------------------------------------
    // 1. ACCIDENT / CRASH DETECTION SENSOR EVALUATOR VALIDATION
    // -------------------------------------------------------------------------
    test('P4-1.1: Crash Evaluator correctly identifies high-confidence vehicle collision', () {
      // Impact: 30 m/s^2 X, 18 m/s^2 Y, 12 m/s^2 Z => magnitude ~37.0 m/s^2 (net impact ~27.2 m/s^2 -> +40 pts)
      // Speed drop: 10.0 m/s to 4.0 m/s (6 m/s drop -> +25 pts)
      // Gyro rotation: 2.5 X, 3.0 Y, 2.0 Z => magnitude ~4.35 rad/s (>4.0 -> +15 pts)
      // Vehicle speed context: 10.0 m/s (>=5.0 -> +10 pts)
      // Total score: 90 => SUSPECTED
      final result = AccidentDetectionEvaluator.evaluate(
        xAcc: 30.0,
        yAcc: 18.0,
        zAcc: 12.0,
        xGyro: 2.5,
        yGyro: 3.0,
        zGyro: 2.0,
        speedBeforeMps: 10.0,
        speedAfterMps: 4.0,
      );

      expect(result.confidence, AccidentConfidence.SUSPECTED);
      expect(result.score, greaterThanOrEqualTo(70));
      expect(result.reasoning, contains('Severe Impact'));
      expect(result.reasoning, contains('Sudden Speed Drop'));
      expect(result.reasoning, contains('Severe Vehicle Rotation'));
    });

    test('P4-1.2: False-Positive Protection caps isolated acceleration spikes (phone drop on desk)', () {
      // Severe acceleration spike (35 m/s^2), BUT:
      // Zero speed drop, zero vehicle speed, zero rotation
      final result = AccidentDetectionEvaluator.evaluate(
        xAcc: 35.0,
        yAcc: 0.0,
        zAcc: 0.0,
        xGyro: 0.0,
        yGyro: 0.0,
        zGyro: 0.0,
        speedBeforeMps: 0.0,
        speedAfterMps: 0.0,
      );

      // Score should be capped at 45 (NORMAL or POSSIBLE, NEVER SUSPECTED)
      expect(result.confidence, isNot(AccidentConfidence.SUSPECTED));
      expect(result.score, lessThanOrEqualTo(45));
      expect(result.confidence, AccidentConfidence.POSSIBLE);
    });

    test('P4-1.3: Minor acceleration and normal driving produce NORMAL confidence', () {
      final result = AccidentDetectionEvaluator.evaluate(
        xAcc: 1.0,
        yAcc: 2.0,
        zAcc: 9.8,
        xGyro: 0.1,
        yGyro: 0.1,
        zGyro: 0.1,
        speedBeforeMps: 12.0,
        speedAfterMps: 11.5,
      );

      expect(result.confidence, AccidentConfidence.NORMAL);
      expect(result.score, lessThan(40));
    });

    test('P4-1.4: AccidentDetectionService settings toggle and duplicate suppression', () async {
      final service = AccidentDetectionService();
      await service.initialize();

      expect(service.isEnabled, isTrue);

      await service.setEnabled(false);
      expect(service.isEnabled, isFalse);
      expect(service.isMonitoring, isFalse);

      await service.setEnabled(true);
      expect(service.isEnabled, isTrue);

      // Set confirmation active to simulate active dialog/SOS
      service.setConfirmationActive(true);

      // Attempting to simulate accident should be suppressed to avoid duplicate dialogs
      bool triggered = false;
      final sub = service.possibleAccidentStream.listen((_) => triggered = true);
      service.simulateAccidentEvent();

      await Future.delayed(const Duration(milliseconds: 50));
      expect(triggered, isFalse);

      service.setConfirmationActive(false);
      await sub.cancel();
      service.stop();
    });

    // -------------------------------------------------------------------------
    // 2. DUAL-TRANSPORT OFFLINE DISPATCH VALIDATION
    // -------------------------------------------------------------------------
    test('P4-2.1: OfflineCommunicationService generates valid local emergency with integrity signature', () async {
      final offlineComm = OfflineCommunicationService();

      final emergencyId = await offlineComm.broadcastSOS(
        position: Position(
          latitude: 19.0760,
          longitude: 72.8777,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        ),
        currentUserId: 'victim_offline_p4',
      );

      expect(emergencyId, startsWith('JS-OFF-'));

      // Verify stored in local database
      final emergency = await localDb.getEmergencyById(emergencyId);
      expect(emergency, isNotNull);
      expect(emergency!.victimId, 'victim_offline_p4');
      expect(emergency.status, EmergencyStatus.SEARCHING);
      expect(emergency.latitude, 19.0760);
      expect(emergency.longitude, 72.8777);
      expect(emergency.isOffline, isTrue);

      await offlineComm.stop();
    });

    // -------------------------------------------------------------------------
    // 3. EMERGENCY LIFECYCLE & INTEGRITY PROTOCOL HARDENING
    // -------------------------------------------------------------------------
    test('P4-3.1: Full offline lifecycle from SOS creation to PRIMARY, STANDBY, and COMPLETION', () async {
      const emergencyId = 'JS-OFF-LIFECYCLE-001';

      final emergency = EmergencyModel(
        id: emergencyId,
        victimId: 'victim_user',
        type: 'MEDICAL',
        latitude: 12.9716,
        longitude: 77.5946,
        status: EmergencyStatus.SEARCHING,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await localDb.saveEmergencyLocally(emergency);

      // 1. Responder A claims emergency -> PRIMARY
      final claimA = {
        'eventType': 'CLAIM_REQUEST',
        'requestId': 'req_a',
        'emergencyId': emergencyId,
        'responderId': 'responder_a',
        'responderName': 'Responder Alice',
        'latitude': 12.9720,
        'longitude': 77.5950,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final signedClaimA = P2PPayloadIntegrity.signPayload(claimA);
      expect(P2PPayloadIntegrity.verifyPayload(signedClaimA), isTrue);

      final resultA = await OfflineNearbyService.processClaimRequest(signedClaimA, localDb);
      expect(resultA.accepted, isTrue);
      expect(resultA.role, ResponderRole.PRIMARY);

      // Verify victim's local record is updated to ASSIGNED with primary responder
      var current = await localDb.getEmergencyById(emergencyId);
      expect(current?.status, EmergencyStatus.ASSIGNED);
      expect(current?.helperId, 'responder_a');
      expect(current?.responders['responder_a']?.role, ResponderRole.PRIMARY);

      // 2. Responder B claims emergency -> STANDBY (does not override primary)
      final claimB = {
        'eventType': 'CLAIM_REQUEST',
        'requestId': 'req_b',
        'emergencyId': emergencyId,
        'responderId': 'responder_b',
        'responderName': 'Responder Bob',
        'latitude': 12.9730,
        'longitude': 77.5960,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final signedClaimB = P2PPayloadIntegrity.signPayload(claimB);
      final resultB = await OfflineNearbyService.processClaimRequest(signedClaimB, localDb);
      expect(resultB.accepted, isTrue);
      expect(resultB.role, ResponderRole.STANDBY);

      // Primary helper is still responder_a
      current = await localDb.getEmergencyById(emergencyId);
      expect(current?.helperId, 'responder_a');
      expect(current?.responders['responder_b']?.role, ResponderRole.STANDBY);

      // 3. Responder A sends ARRIVED status update
      final arrivalUpdate = {
        'eventType': 'STATUS_UPDATE',
        'emergencyId': emergencyId,
        'responderId': 'responder_a',
        'status': 'ARRIVED',
        'latitude': 12.9717,
        'longitude': 77.5947,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final signedArrival = P2PPayloadIntegrity.signPayload(arrivalUpdate);
      expect(P2PPayloadIntegrity.verifyPayload(signedArrival), isTrue);

      final updatedArrival = await OfflineNearbyService.processStatusUpdatePayload(signedArrival, localDb);
      expect(updatedArrival?.status, EmergencyStatus.ARRIVED);
      expect(updatedArrival?.responders['responder_a']?.status, ResponderStatus.ARRIVED);

      // 4. Victim ends/completes emergency
      final completionUpdate = {
        'eventType': 'STATUS_UPDATE',
        'emergencyId': emergencyId,
        'status': 'COMPLETED',
        'isVictim': true,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final signedCompletion = P2PPayloadIntegrity.signPayload(completionUpdate);
      final updatedCompletion = await OfflineNearbyService.processStatusUpdatePayload(signedCompletion, localDb);
      expect(updatedCompletion?.status, EmergencyStatus.COMPLETED);
      expect(updatedCompletion?.isClosed, isTrue);

      // 5. Subsequent claim attempt on COMPLETED emergency must be rejected
      final claimLate = {
        'eventType': 'CLAIM_REQUEST',
        'requestId': 'req_late',
        'emergencyId': emergencyId,
        'responderId': 'responder_c',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final resultLate = await OfflineNearbyService.processClaimRequest(claimLate, localDb);
      expect(resultLate.accepted, isFalse);
      expect(resultLate.reason, 'EMERGENCY_INACTIVE');
    });

    test('P4-3.2: Victim cannot volunteer for own emergency', () async {
      const emergencyId = 'JS-OFF-SELF-001';
      final emergency = EmergencyModel(
        id: emergencyId,
        victimId: 'same_user_123',
        type: 'ACCIDENT',
        latitude: 28.6139,
        longitude: 77.2090,
        status: EmergencyStatus.SEARCHING,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await localDb.saveEmergencyLocally(emergency);

      final selfClaim = {
        'eventType': 'CLAIM_REQUEST',
        'requestId': 'req_self',
        'emergencyId': emergencyId,
        'responderId': 'same_user_123',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final result = await OfflineNearbyService.processClaimRequest(selfClaim, localDb);
      expect(result.accepted, isFalse);
      expect(result.reason, 'VICTIM_CANNOT_RESPOND');
    });

    test('P4-3.3: Duplicate claim returns existing assignment without duplicating responder records', () async {
      const emergencyId = 'JS-OFF-DUP-001';
      final emergency = EmergencyModel(
        id: emergencyId,
        victimId: 'victim_dup',
        type: 'MEDICAL',
        latitude: 19.0760,
        longitude: 72.8777,
        status: EmergencyStatus.SEARCHING,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await localDb.saveEmergencyLocally(emergency);

      final claim = {
        'eventType': 'CLAIM_REQUEST',
        'requestId': 'req_dup_1',
        'emergencyId': emergencyId,
        'responderId': 'responder_dup',
        'responderName': 'Responder Charlie',
        'latitude': 19.0765,
        'longitude': 72.8780,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // First claim
      final res1 = await OfflineNearbyService.processClaimRequest(claim, localDb);
      expect(res1.accepted, isTrue);
      expect(res1.role, ResponderRole.PRIMARY);

      // Repeat claim with new request ID
      final repeatClaim = Map<String, dynamic>.from(claim);
      repeatClaim['requestId'] = 'req_dup_2';
      final res2 = await OfflineNearbyService.processClaimRequest(repeatClaim, localDb);
      expect(res2.accepted, isTrue);
      expect(res2.role, ResponderRole.PRIMARY);
      expect(res2.ackPayload['isDuplicate'], isTrue);

      // Responders map should have exactly 1 entry
      final record = await localDb.getEmergencyById(emergencyId);
      expect(record?.responders.length, 1);
    });

    test('P4-3.4: P2P Payload Integrity correctly detects tampered GPS coordinates in status update', () {
      final statusUpdate = {
        'eventType': 'STATUS_UPDATE',
        'emergencyId': 'JS-OFF-TAMPER-001',
        'responderId': 'responder_legit',
        'status': 'RESPONDING',
        'latitude': 13.0827,
        'longitude': 80.2707,
        'timestamp': 1700000000000,
      };

      final signed = P2PPayloadIntegrity.signPayload(statusUpdate);
      expect(P2PPayloadIntegrity.verifyPayload(signed), isTrue);

      // Maliciously spoof GPS coordinates
      final spoofed = Map<String, dynamic>.from(signed);
      spoofed['latitude'] = 28.7041;
      spoofed['longitude'] = 77.1025;

      expect(P2PPayloadIntegrity.verifyPayload(spoofed), isFalse);

      final jsonSpoofed = jsonEncode(spoofed);
      expect(P2PPayloadIntegrity.parseAndVerifyString(jsonSpoofed), isNull);
    });
  });
}
