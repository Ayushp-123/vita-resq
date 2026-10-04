import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jan_sarthi/models/emergency_model.dart';
import 'package:jan_sarthi/models/responder_model.dart';
import 'package:jan_sarthi/services/local_database_service.dart';
import 'package:jan_sarthi/services/offline_nearby_service.dart';

void main() {
  group('Jan Sarthi Data Models', () {
    test('EmergencyModel parsing and helper getters', () {
      final now = DateTime.now();
      final emergency = EmergencyModel(
        id: 'test-123',
        victimId: 'victim-001',
        type: 'MEDICAL',
        latitude: 28.6139,
        longitude: 77.2090,
        status: EmergencyStatus.SEARCHING,
        createdAt: now,
        updatedAt: now,
        responders: {
          'resp-1': ResponderModel(
            userId: 'resp-1',
            userName: 'Helper 1',
            role: ResponderRole.PRIMARY,
            status: ResponderStatus.RESPONDING,
            latitude: 28.6140,
            longitude: 77.2091,
            acceptedAt: now,
            lastLocationUpdate: now,
          ),
          'resp-2': ResponderModel(
            userId: 'resp-2',
            userName: 'Helper 2',
            role: ResponderRole.STANDBY,
            status: ResponderStatus.STANDBY,
            latitude: 28.6150,
            longitude: 77.2095,
            acceptedAt: now,
            lastLocationUpdate: now,
          ),
        },
      );

      expect(emergency.id, 'test-123');
      expect(emergency.primaryResponder?.userId, 'resp-1');
      expect(emergency.standbyResponders.length, 1);
      expect(emergency.standbyResponders.first.userId, 'resp-2');

      final map = emergency.toMap();
      expect(map['status'], 'SEARCHING');
      expect(map['responders'], isA<Map>());
      // Verify online Firestore representation uses Timestamp
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['updatedAt'], isA<Timestamp>());
    });

    test('LocalDatabaseService persists and restores offline emergency with Timestamps', () async {
      SharedPreferences.setMockInitialValues({});
      final localDb = LocalDatabaseService();

      final now = DateTime.now();
      final emergency = EmergencyModel(
        id: 'JS-OFF-999',
        victimId: 'victim-off-1',
        type: 'MEDICAL',
        latitude: 19.0760,
        longitude: 72.8777,
        status: EmergencyStatus.SEARCHING,
        createdAt: now,
        updatedAt: now,
        responders: {
          'resp-off-1': ResponderModel(
            userId: 'resp-off-1',
            userName: 'Nearby Responder',
            role: ResponderRole.STANDBY,
            status: ResponderStatus.STANDBY,
            latitude: 19.0765,
            longitude: 72.8780,
            acceptedAt: now,
            lastLocationUpdate: now,
            assignedAt: now,
          ),
        },
      );

      // Must not throw JsonUnsupportedObjectError
      await localDb.saveEmergencyLocally(emergency);

      // Retrieve unsynced
      final unsynced = await localDb.getUnsyncedEmergencies();
      expect(unsynced.length, 1);

      final restored = unsynced.first;
      expect(restored.id, 'JS-OFF-999');
      expect(restored.victimId, 'victim-off-1');
      expect(restored.responders.containsKey('resp-off-1'), isTrue);
      expect(restored.responders['resp-off-1']?.role, ResponderRole.STANDBY);

      // Verify restored model produces standard Firestore Timestamps for sync
      final syncMap = restored.toMap();
      expect(syncMap['createdAt'], isA<Timestamp>());
      expect(syncMap['responders']['resp-off-1']['acceptedAt'], isA<Timestamp>());

      // Mark synced
      await localDb.markAsSynced('JS-OFF-999');
      final afterSync = await localDb.getUnsyncedEmergencies();
      expect(afterSync.isEmpty, isTrue);

      // getEmergencyById should still find it
      final byId = await localDb.getEmergencyById('JS-OFF-999');
      expect(byId, isNotNull);
      expect(byId!.id, 'JS-OFF-999');

      // Unknown ID returns null
      final unknown = await localDb.getEmergencyById('NON-EXISTENT');
      expect(unknown, isNull);
    });

    test('OfflineNearbyService processes acceptance payload with PRIMARY, STANDBY and duplicate protection', () async {
      SharedPreferences.setMockInitialValues({});
      final localDb = LocalDatabaseService();

      final now = DateTime.now();
      final initialEmergency = EmergencyModel(
        id: 'JS-OFF-100',
        victimId: 'victim-off-100',
        type: 'MEDICAL',
        latitude: 28.6139,
        longitude: 77.2090,
        status: EmergencyStatus.SEARCHING,
        createdAt: now,
        updatedAt: now,
      );

      await localDb.saveEmergencyLocally(initialEmergency);

      // 1. First helper accepts -> Becomes PRIMARY
      final payload1 = {
        'eventType': 'RESPONDER_ACCEPTANCE',
        'emergencyId': 'JS-OFF-100',
        'responderId': 'helper-1',
        'responderName': 'Alice (First)',
        'latitude': 28.6140,
        'longitude': 77.2091,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final updated1 = await OfflineNearbyService.processAcceptancePayload(payload1, localDb);
      expect(updated1, isNotNull);
      expect(updated1!.helperId, 'helper-1');
      expect(updated1.status, EmergencyStatus.ASSIGNED);
      expect(updated1.primaryResponder?.userId, 'helper-1');
      expect(updated1.primaryResponder?.role, ResponderRole.PRIMARY);
      expect(updated1.standbyResponders.isEmpty, isTrue);

      // 2. Second helper accepts -> Becomes STANDBY
      final payload2 = {
        'eventType': 'RESPONDER_ACCEPTANCE',
        'emergencyId': 'JS-OFF-100',
        'responderId': 'helper-2',
        'responderName': 'Bob (Second)',
        'latitude': 28.6150,
        'longitude': 77.2095,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final updated2 = await OfflineNearbyService.processAcceptancePayload(payload2, localDb);
      expect(updated2, isNotNull);
      expect(updated2!.helperId, 'helper-1'); // PRIMARY unchanged
      expect(updated2.primaryResponder?.userId, 'helper-1');
      expect(updated2.standbyResponders.length, 1);
      expect(updated2.standbyResponders.first.userId, 'helper-2');
      expect(updated2.responders.length, 2);

      // 3. Duplicate payload from helper-1 -> No changes / No duplicate
      final updated3 = await OfflineNearbyService.processAcceptancePayload(payload1, localDb);
      expect(updated3, isNotNull);
      expect(updated3!.responders.length, 2);
      expect(updated3.primaryResponder?.userId, 'helper-1');

      // 4. Invalid payload / unknown emergencyId -> Returns null safely
      final invalidPayload = {
        'eventType': 'RESPONDER_ACCEPTANCE',
        'emergencyId': 'NON-EXISTENT-EMERGENCY',
        'responderId': 'helper-3',
      };
      final resultInvalid = await OfflineNearbyService.processAcceptancePayload(invalidPayload, localDb);
      expect(resultInvalid, isNull);
    });

    test('Active vs Terminal/Closed Emergency lifecycle definitions and claimability', () {
      final now = DateTime.now();
      final active1 = EmergencyModel(
        id: 'e-1',
        victimId: 'v-1',
        latitude: 0,
        longitude: 0,
        status: EmergencyStatus.SEARCHING,
        createdAt: now,
        updatedAt: now,
      );
      expect(active1.isActive, isTrue);
      expect(active1.isClosed, isFalse);
      expect(active1.isTerminal, isFalse);
      expect(active1.isClaimable, isTrue);

      final active2 = EmergencyModel(
        id: 'e-2',
        victimId: 'v-1',
        latitude: 0,
        longitude: 0,
        status: EmergencyStatus.ASSIGNED,
        createdAt: now,
        updatedAt: now,
      );
      expect(active2.isActive, isTrue);
      expect(active2.isClosed, isFalse);
      expect(active2.isClaimable, isTrue);

      final arrived = EmergencyModel(
        id: 'e-3',
        victimId: 'v-1',
        latitude: 0,
        longitude: 0,
        status: EmergencyStatus.ARRIVED,
        createdAt: now,
        updatedAt: now,
      );
      expect(arrived.isActive, isTrue);
      expect(arrived.isClosed, isFalse);

      final completed = EmergencyModel(
        id: 'e-4',
        victimId: 'v-1',
        latitude: 0,
        longitude: 0,
        status: EmergencyStatus.COMPLETED,
        createdAt: now,
        updatedAt: now,
      );
      expect(completed.isActive, isFalse);
      expect(completed.isClosed, isTrue);
      expect(completed.isTerminal, isTrue);
      expect(completed.isClaimable, isFalse);

      final cancelled = EmergencyModel(
        id: 'e-5',
        victimId: 'v-1',
        latitude: 0,
        longitude: 0,
        status: EmergencyStatus.CANCELLED,
        createdAt: now,
        updatedAt: now,
      );
      expect(cancelled.isActive, isFalse);
      expect(cancelled.isClosed, isTrue);
      expect(cancelled.isTerminal, isTrue);
      expect(cancelled.isClaimable, isFalse);
    });

    test('EmergencyModel.fromMap correctly parses RESOLVED and ENDED aliases as COMPLETED', () {
      final now = DateTime.now();
      final mapResolved = {
        'victimId': 'v-1',
        'status': 'RESOLVED',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };
      final parsedResolved = EmergencyModel.fromMap(mapResolved, 'res-1');
      expect(parsedResolved.status, EmergencyStatus.COMPLETED);
      expect(parsedResolved.isClosed, isTrue);

      final mapEnded = {
        'victimId': 'v-1',
        'status': 'ENDED',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };
      final parsedEnded = EmergencyModel.fromMap(mapEnded, 'end-1');
      expect(parsedEnded.status, EmergencyStatus.COMPLETED);
      expect(parsedEnded.isClosed, isTrue);
    });
  });
}



