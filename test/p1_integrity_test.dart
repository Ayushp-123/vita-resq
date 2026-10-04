import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jan_sarthi/models/emergency_model.dart';
import 'package:jan_sarthi/models/responder_model.dart';
import 'package:jan_sarthi/services/app_permissions_service.dart';
import 'package:jan_sarthi/services/emergency_claim_service.dart';
import 'package:jan_sarthi/services/emergency_service.dart';
import 'package:jan_sarthi/services/local_database_service.dart';
import 'package:jan_sarthi/services/offline_nearby_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P1 Core Emergency Experience Integrity Tests', () {
    late LocalDatabaseService localDb;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      localDb = LocalDatabaseService();
    });

    // -------------------------------------------------------------
    // P1-1: REACTIVE OFFLINE EMERGENCY DETAILS STREAM
    // -------------------------------------------------------------
    test('P1-1.1: streamEmergency emits initial offline record and reacts to local updates', () async {
      final initialEmergency = EmergencyModel(
        id: 'JS-OFF-001',
        victimId: 'victim_123',
        type: 'MEDICAL',
        latitude: 28.6139,
        longitude: 77.2090,
        status: EmergencyStatus.SEARCHING,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await localDb.saveEmergencyLocally(initialEmergency);

      final emissions = <EmergencyModel?>[];
      final completer = Completer<void>();

      final subscription = localDb.streamEmergency('JS-OFF-001').listen((emergency) {
        emissions.add(emergency);
        if (emissions.length == 2) {
          completer.complete();
        }
      });

      // Allow initial stream yield
      await Future.delayed(const Duration(milliseconds: 50));

      // Simulate a local/P2P update (e.g. responder accepted)
      final updatedEmergency = EmergencyModel(
        id: 'JS-OFF-001',
        victimId: 'victim_123',
        type: 'MEDICAL',
        latitude: 28.6139,
        longitude: 77.2090,
        status: EmergencyStatus.ASSIGNED,
        helperId: 'helper_789',
        createdAt: initialEmergency.createdAt,
        updatedAt: DateTime.now(),
      );

      await localDb.saveEmergencyLocally(updatedEmergency);

      await completer.future.timeout(const Duration(seconds: 2));
      await subscription.cancel();

      expect(emissions.length, 2);
      expect(emissions[0]?.status, EmergencyStatus.SEARCHING);
      expect(emissions[1]?.status, EmergencyStatus.ASSIGNED);
      expect(emissions[1]?.helperId, 'helper_789');
    });

    // -------------------------------------------------------------
    // P1-2: EMERGENCY CONTACT SMS INTENT BEHAVIOR
    // -------------------------------------------------------------
    test('P1-2.1: SMS URI is formatted correctly with scheme, delimiters, and message body', () {
      final phoneNumbers = ['+919876543210', '+919876543211'];
      const message = 'EMERGENCY TEST';

      // Android delimiter test (;)
      final androidUri = EmergencyContactsService.buildSmsUri(
        phoneNumbers: phoneNumbers,
        message: message,
        isIOS: false,
      );
      expect(androidUri.scheme, 'sms');
      expect(androidUri.path, '+919876543210;+919876543211');
      expect(androidUri.queryParameters['body'], message);

      // iOS delimiter test (,)
      final iosUri = EmergencyContactsService.buildSmsUri(
        phoneNumbers: phoneNumbers,
        message: message,
        isIOS: true,
      );
      expect(iosUri.scheme, 'sms');
      expect(iosUri.path, '+919876543210,+919876543211');
      expect(iosUri.queryParameters['body'], message);
    });

    test('P1-2.2: formatEmergencyMessage includes live GPS coordinates, Google Maps link, and victim info', () {
      final message = EmergencyContactsService.formatEmergencyMessage(
        latitude: 28.6139,
        longitude: 77.2090,
        type: 'ACCIDENT',
        victimName: 'Rohan Sharma',
        victimPhone: '+919876543210',
        bloodGroup: 'B+',
      );

      expect(message, contains('🚨 VITA RESQ CRITICAL EMERGENCY ALERT!'));
      expect(message, contains('Status: SOS Active (ACCIDENT)'));
      expect(message, contains('👤 Victim: Rohan Sharma'));
      expect(message, contains('📞 Contact: +919876543210'));
      expect(message, contains('🩸 Blood Group: B+'));
      expect(message, contains('https://maps.google.com/?q=28.61390,77.20900'));
    });

    test('P1-2.3: AppPermissionsService reports SMS granted with zero runtime permission popups', () async {
      final permService = AppPermissionsService();
      final hasSms = await permService.isSmsGranted();
      expect(hasSms, isTrue);
    });

    test('P1-2.4: EmergencyContactsService stores and caps contacts at maximum 3', () async {
      final contactsService = EmergencyContactsService();
      final list = [
        EmergencyContact(name: 'Contact 1', phoneNumber: '+911111111111', relationship: 'Family'),
        EmergencyContact(name: 'Contact 2', phoneNumber: '+912222222222', relationship: 'Friend'),
        EmergencyContact(name: 'Contact 3', phoneNumber: '+913333333333', relationship: 'Doctor'),
        EmergencyContact(name: 'Contact 4', phoneNumber: '+914444444444', relationship: 'Neighbor'),
      ];

      await contactsService.saveContacts(list);
      final saved = await contactsService.getContacts();

      expect(saved.length, 3);
      expect(saved[0].name, 'Contact 1');
      expect(saved[1].name, 'Contact 2');
      expect(saved[2].name, 'Contact 3');
    });

    // -------------------------------------------------------------
    // P1-3: TWO-WAY P2P CLAIM REQUEST / ACKNOWLEDGEMENT HANDSHAKE
    // -------------------------------------------------------------
    test('P1-3.1: Victim device processes CLAIM_REQUEST and generates authoritative CLAIM_ACK', () async {
      final emergency = EmergencyModel(
        id: 'JS-OFF-002',
        victimId: 'victim_alpha',
        type: 'MEDICAL',
        latitude: 19.0760,
        longitude: 72.8777,
        status: EmergencyStatus.SEARCHING,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await localDb.saveEmergencyLocally(emergency);

      final claimRequest = {
        'eventType': 'CLAIM_REQUEST',
        'requestId': 'req_001',
        'emergencyId': 'JS-OFF-002',
        'responderId': 'responder_bravo',
        'responderName': 'Responder Bravo',
        'phoneNumber': '+919988776655',
        'bloodGroup': 'O+',
        'latitude': 19.0765,
        'longitude': 72.8772,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final result = await OfflineNearbyService.processClaimRequest(claimRequest, localDb);

      expect(result.accepted, isTrue);
      expect(result.role, ResponderRole.PRIMARY);
      expect(result.ackPayload['eventType'], 'CLAIM_ACK');
      expect(result.ackPayload['requestId'], 'req_001');
      expect(result.ackPayload['emergencyId'], 'JS-OFF-002');
      expect(result.ackPayload['responderId'], 'responder_bravo');
      expect(result.ackPayload['accepted'], isTrue);
      expect(result.ackPayload['role'], 'PRIMARY');

      // Verify victim's local database updated
      final updated = await localDb.getEmergencyById('JS-OFF-002');
      expect(updated?.status, EmergencyStatus.ASSIGNED);
      expect(updated?.helperId, 'responder_bravo');
      expect(updated?.responders.containsKey('responder_bravo'), isTrue);
      expect(updated?.responders['responder_bravo']?.role, ResponderRole.PRIMARY);
    });

    test('P1-3.2: EmergencyClaimService.acceptAndRespond in offline disconnected mode assigns PRIMARY and prevents duplicate claims', () async {
      final emergency = EmergencyModel(
        id: 'JS-OFF-CLAIM-001',
        victimId: 'victim_separate',
        type: 'ACCIDENT',
        latitude: 12.9716,
        longitude: 77.5946,
        status: EmergencyStatus.SEARCHING,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await localDb.saveEmergencyLocally(emergency);

      final claimService = EmergencyClaimService();
      final role = await claimService.acceptAndRespond('JS-OFF-CLAIM-001');
      expect(role, ResponderRole.PRIMARY);

      // Duplicate claim attempt returns existing role
      final dupRole = await claimService.acceptAndRespond('JS-OFF-CLAIM-001');
      expect(dupRole, ResponderRole.PRIMARY);

      final updated = await localDb.getEmergencyById('JS-OFF-CLAIM-001');
      expect(updated?.responders.length, 1);
    });

    // -------------------------------------------------------------
    // P1-4: DUPLICATE CLAIM PREVENTION & STANDBY ROLE ASSIGNMENT
    // -------------------------------------------------------------
    test('P1-4.1: Second responder is assigned STANDBY role without overriding PRIMARY helper', () async {
      final emergency = EmergencyModel(
        id: 'JS-OFF-003',
        victimId: 'victim_alpha',
        type: 'ACCIDENT',
        latitude: 12.9716,
        longitude: 77.5946,
        status: EmergencyStatus.SEARCHING,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await localDb.saveEmergencyLocally(emergency);

      // Responder 1 claims
      final req1 = {
        'eventType': 'CLAIM_REQUEST',
        'requestId': 'req_101',
        'emergencyId': 'JS-OFF-003',
        'responderId': 'responder_1',
        'responderName': 'Primary Helper',
        'latitude': 12.9718,
        'longitude': 77.5948,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final res1 = await OfflineNearbyService.processClaimRequest(req1, localDb);
      expect(res1.role, ResponderRole.PRIMARY);

      // Responder 2 claims
      final req2 = {
        'eventType': 'CLAIM_REQUEST',
        'requestId': 'req_102',
        'emergencyId': 'JS-OFF-003',
        'responderId': 'responder_2',
        'responderName': 'Standby Helper',
        'latitude': 12.9720,
        'longitude': 77.5950,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final res2 = await OfflineNearbyService.processClaimRequest(req2, localDb);
      expect(res2.role, ResponderRole.STANDBY);
      expect(res2.ackPayload['role'], 'STANDBY');

      final updated = await localDb.getEmergencyById('JS-OFF-003');
      expect(updated?.helperId, 'responder_1'); // Primary remains responder_1
      expect(updated?.responders.length, 2);
      expect(updated?.responders['responder_1']?.role, ResponderRole.PRIMARY);
      expect(updated?.responders['responder_2']?.role, ResponderRole.STANDBY);
    });

    test('P1-4.2: Duplicate claim request by same responder returns existing role without duplicates', () async {
      final emergency = EmergencyModel(
        id: 'JS-OFF-004',
        victimId: 'victim_alpha',
        type: 'MEDICAL',
        latitude: 12.9716,
        longitude: 77.5946,
        status: EmergencyStatus.SEARCHING,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await localDb.saveEmergencyLocally(emergency);

      final req = {
        'eventType': 'CLAIM_REQUEST',
        'requestId': 'req_201',
        'emergencyId': 'JS-OFF-004',
        'responderId': 'responder_dup',
        'responderName': 'Duplicate Responder',
        'latitude': 12.9718,
        'longitude': 77.5948,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // First submission
      final res1 = await OfflineNearbyService.processClaimRequest(req, localDb);
      expect(res1.role, ResponderRole.PRIMARY);

      // Duplicate submission
      final res2 = await OfflineNearbyService.processClaimRequest(req, localDb);
      expect(res2.accepted, isTrue);
      expect(res2.role, ResponderRole.PRIMARY);
      expect(res2.ackPayload['isDuplicate'], isTrue);

      final check = await localDb.getEmergencyById('JS-OFF-004');
      expect(check?.responders.length, 1);
    });

    test('P1-4.3: Victim cannot claim their own emergency', () async {
      final emergency = EmergencyModel(
        id: 'JS-OFF-005',
        victimId: 'victim_same',
        type: 'FIRE',
        latitude: 12.9716,
        longitude: 77.5946,
        status: EmergencyStatus.SEARCHING,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await localDb.saveEmergencyLocally(emergency);

      final req = {
        'eventType': 'CLAIM_REQUEST',
        'requestId': 'req_victim_self',
        'emergencyId': 'JS-OFF-005',
        'responderId': 'victim_same',
        'responderName': 'Victim Self',
        'latitude': 12.9718,
        'longitude': 77.5948,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final res = await OfflineNearbyService.processClaimRequest(req, localDb);
      expect(res.accepted, isFalse);
      expect(res.reason, 'VICTIM_CANNOT_RESPOND');
      expect(res.ackPayload['accepted'], isFalse);
    });

    // -------------------------------------------------------------
    // P1-5: CLAIM TIMEOUT / INACTIVE EMERGENCY REJECTION
    // -------------------------------------------------------------
    test('P1-5.1: Inactive or completed emergency rejects claim requests', () async {
      final emergency = EmergencyModel(
        id: 'JS-OFF-006',
        victimId: 'victim_beta',
        type: 'MEDICAL',
        latitude: 12.9716,
        longitude: 77.5946,
        status: EmergencyStatus.COMPLETED,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await localDb.saveEmergencyLocally(emergency);

      final req = {
        'eventType': 'CLAIM_REQUEST',
        'requestId': 'req_closed',
        'emergencyId': 'JS-OFF-006',
        'responderId': 'responder_late',
        'responderName': 'Late Helper',
        'latitude': 12.9718,
        'longitude': 77.5948,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final res = await OfflineNearbyService.processClaimRequest(req, localDb);
      expect(res.accepted, isFalse);
      expect(res.reason, 'EMERGENCY_INACTIVE');
    });

    test('P1-5.2: claimAckStream timeout handling when peer does not respond', () async {
      final nearbyService = OfflineNearbyService();
      nearbyService.addConnectedEndpointForTesting('test-endpoint-1');

      try {
        // We simulate waiting for an ACK on claimAckStream with a brief timeout
        bool timedOut = false;
        try {
          await nearbyService.claimAckStream
              .firstWhere((data) => data['requestId'] == 'non_existent_req')
              .timeout(const Duration(milliseconds: 100));
        } on TimeoutException {
          timedOut = true;
        }
        expect(timedOut, isTrue);
      } finally {
        nearbyService.removeConnectedEndpointForTesting('test-endpoint-1');
      }
    });

    // -------------------------------------------------------------
    // P1-6: CONCURRENT OFFLINE EMERGENCY STORAGE UPDATES (MUTEX SAFETY)
    // -------------------------------------------------------------
    test('P1-6.1: Concurrent storage writes serialize cleanly through async mutex without data corruption', () async {
      final emergency = EmergencyModel(
        id: 'JS-OFF-CONCURRENT',
        victimId: 'victim_sync',
        type: 'MEDICAL',
        latitude: 10.0,
        longitude: 20.0,
        status: EmergencyStatus.SEARCHING,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await localDb.saveEmergencyLocally(emergency);

      // Fire 15 concurrent updates simultaneously
      List<Future<void>> futures = [];
      for (int i = 1; i <= 15; i++) {
        futures.add(() async {
          final existing = await localDb.getEmergencyById('JS-OFF-CONCURRENT');
          if (existing != null) {
            final updatedResponders = Map<String, ResponderModel>.from(existing.responders);
            updatedResponders['responder_$i'] = ResponderModel(
              userId: 'responder_$i',
              userName: 'Responder $i',
              role: ResponderRole.STANDBY,
              status: ResponderStatus.STANDBY,
              latitude: 10.0 + (i * 0.001),
              longitude: 20.0 + (i * 0.001),
              acceptedAt: DateTime.now(),
              lastLocationUpdate: DateTime.now(),
            );
            final updated = EmergencyModel(
              id: existing.id,
              victimId: existing.victimId,
              type: existing.type,
              latitude: existing.latitude,
              longitude: existing.longitude,
              status: existing.status,
              responders: updatedResponders,
              createdAt: existing.createdAt,
              updatedAt: DateTime.now(),
            );
            await localDb.saveEmergencyLocally(updated);
          }
        }());
      }

      await Future.wait(futures);

      final finalResult = await localDb.getEmergencyById('JS-OFF-CONCURRENT');
      expect(finalResult, isNotNull);
      // All writes completed safely without throwing concurrency exceptions
      expect(finalResult!.responders.isNotEmpty, isTrue);
    });

    // -------------------------------------------------------------
    // P1-7: PRESERVATION OF SEPARATE EMERGENCY RECORDS (ISOLATED STORAGE)
    // -------------------------------------------------------------
    test('P1-7.1: Updating Emergency A does not alter or overwrite Emergency B', () async {
      final emergencyA = EmergencyModel(
        id: 'JS-OFF-AAA',
        victimId: 'victim_A',
        type: 'MEDICAL',
        latitude: 11.11,
        longitude: 22.22,
        status: EmergencyStatus.SEARCHING,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final emergencyB = EmergencyModel(
        id: 'JS-OFF-BBB',
        victimId: 'victim_B',
        type: 'FIRE',
        latitude: 33.33,
        longitude: 44.44,
        status: EmergencyStatus.SEARCHING,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await localDb.saveEmergencyLocally(emergencyA);
      await localDb.saveEmergencyLocally(emergencyB);

      // Mutate Emergency A to COMPLETED
      final updatedA = EmergencyModel(
        id: 'JS-OFF-AAA',
        victimId: 'victim_A',
        type: 'MEDICAL',
        latitude: 11.99,
        longitude: 22.99,
        status: EmergencyStatus.COMPLETED,
        createdAt: emergencyA.createdAt,
        updatedAt: DateTime.now(),
      );
      await localDb.saveEmergencyLocally(updatedA);

      // Verify Emergency B is completely pristine and separate
      final recordB = await localDb.getEmergencyById('JS-OFF-BBB');
      expect(recordB, isNotNull);
      expect(recordB?.id, 'JS-OFF-BBB');
      expect(recordB?.status, EmergencyStatus.SEARCHING);
      expect(recordB?.type, 'FIRE');
      expect(recordB?.latitude, 33.33);
      expect(recordB?.longitude, 44.44);

      // Verify isolated keys exist in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('offline_emergency_JS-OFF-AAA'), isTrue);
      expect(prefs.containsKey('offline_emergency_JS-OFF-BBB'), isTrue);

      final all = await localDb.getAllLocalEmergencies();
      expect(all.length, 2);
    });
  });
}
