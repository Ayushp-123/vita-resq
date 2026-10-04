import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jan_sarthi/services/p2p_payload_integrity.dart';
import 'package:jan_sarthi/services/offline_nearby_service.dart';
import 'package:jan_sarthi/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P3 — Security & P2P Payload Integrity Hardening Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('P3-1.1: Valid payload signed by P2PPayloadIntegrity is accepted', () {
      final payload = {
        'eventType': 'SOS_BROADCAST',
        'emergencyId': 'JS-OFF-P3-001',
        'victimId': 'victim_user_01',
        'latitude': 12.9716,
        'longitude': 77.5946,
        'type': 'MEDICAL',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final signed = P2PPayloadIntegrity.signPayload(payload);

      expect(signed.containsKey(P2PPayloadIntegrity.integrityField), isTrue);
      expect(signed[P2PPayloadIntegrity.integrityField], isNotEmpty);
      expect(signed[P2PPayloadIntegrity.versionField], 1);

      final isValid = P2PPayloadIntegrity.verifyPayload(signed);
      expect(isValid, isTrue);

      final verifiedViaNearby = OfflineNearbyService.verifyPayloadIntegrity(signed);
      expect(verifiedViaNearby, isTrue);
    });

    test('P3-1.2: Tampered payload is rejected', () {
      final payload = {
        'eventType': 'CLAIM_REQUEST',
        'requestId': 'req_p3_101',
        'emergencyId': 'JS-OFF-P3-002',
        'responderId': 'responder_alpha',
        'responderName': 'Alpha Responder',
        'latitude': 12.9716,
        'longitude': 77.5946,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final signed = P2PPayloadIntegrity.signPayload(payload);
      expect(P2PPayloadIntegrity.verifyPayload(signed), isTrue);

      // Tamper with latitude (GPS coordinate spoofing)
      final tamperedCoordinates = Map<String, dynamic>.from(signed);
      tamperedCoordinates['latitude'] = 19.0760;
      expect(P2PPayloadIntegrity.verifyPayload(tamperedCoordinates), isFalse);

      // Tamper with responderId (identity spoofing)
      final tamperedResponder = Map<String, dynamic>.from(signed);
      tamperedResponder['responderId'] = 'attacker_responder';
      expect(P2PPayloadIntegrity.verifyPayload(tamperedResponder), isFalse);

      // Tamper with emergencyId (target redirection)
      final tamperedEmergency = Map<String, dynamic>.from(signed);
      tamperedEmergency['emergencyId'] = 'JS-OFF-OTHER-999';
      expect(P2PPayloadIntegrity.verifyPayload(tamperedEmergency), isFalse);
    });

    test('P3-1.3: Missing integrity field is rejected safely without crashing', () {
      final rawUnsigned = {
        'eventType': 'SOS_BROADCAST',
        'emergencyId': 'JS-OFF-P3-003',
        'victimId': 'victim_test',
        'latitude': 12.9716,
        'longitude': 77.5946,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      expect(P2PPayloadIntegrity.verifyPayload(rawUnsigned), isFalse);
      expect(OfflineNearbyService.verifyPayloadIntegrity(rawUnsigned), isFalse);

      // Empty token is also rejected
      final emptyTokenPayload = Map<String, dynamic>.from(rawUnsigned);
      emptyTokenPayload[P2PPayloadIntegrity.integrityField] = '';
      expect(P2PPayloadIntegrity.verifyPayload(emptyTokenPayload), isFalse);
    });

    test('P3-1.4: Malformed payloads are handled safely', () {
      // 1. Non-map input
      expect(P2PPayloadIntegrity.verifyPayload('not_a_map'), isFalse);
      expect(P2PPayloadIntegrity.verifyPayload([1, 2, 3]), isFalse);
      expect(P2PPayloadIntegrity.verifyPayload(null), isFalse);

      // 2. Corrupt / invalid JSON string
      expect(P2PPayloadIntegrity.parseAndVerifyString('{invalid_json:'), isNull);
      expect(P2PPayloadIntegrity.parseAndVerifyString(''), isNull);
      expect(P2PPayloadIntegrity.parseAndVerifyString('[{"a":1}]'), isNull);

      // 3. Corrupt byte stream
      expect(P2PPayloadIntegrity.parseAndVerifyBytes(null), isNull);
      expect(P2PPayloadIntegrity.parseAndVerifyBytes(Uint8List(0)), isNull);
      expect(P2PPayloadIntegrity.parseAndVerifyBytes(Uint8List.fromList([0xFF, 0xFE, 0xFD])), isNull);

      // 4. Missing required structural fields
      final missingEventType = {
        'emergencyId': 'JS-OFF-001',
        'timestamp': 12345678,
      };
      final signedMissingEventType = P2PPayloadIntegrity.signPayload(missingEventType);
      expect(P2PPayloadIntegrity.verifyPayload(signedMissingEventType), isFalse);

      final missingEmergencyId = {
        'eventType': 'SOS_BROADCAST',
        'timestamp': 12345678,
      };
      final signedMissingEmergencyId = P2PPayloadIntegrity.signPayload(missingEmergencyId);
      expect(P2PPayloadIntegrity.verifyPayload(signedMissingEmergencyId), isFalse);

      final invalidTimestamp = {
        'eventType': 'SOS_BROADCAST',
        'emergencyId': 'JS-OFF-001',
        'timestamp': -100,
      };
      final signedInvalidTimestamp = P2PPayloadIntegrity.signPayload(invalidTimestamp);
      expect(P2PPayloadIntegrity.verifyPayload(signedInvalidTimestamp), isFalse);
    });

    test('P3-1.5: End-to-end byte serialization and verification across Nearby layer', () {
      final payload = {
        'eventType': 'RESPONDER_ACCEPTANCE',
        'emergencyId': 'JS-OFF-P3-005',
        'responderId': 'responder_verified',
        'responderName': 'Verified Medic',
        'role': 'PRIMARY',
        'status': 'RESPONDING',
        'latitude': 28.6139,
        'longitude': 77.2090,
        'timestamp': 1700000000000,
      };

      final signed = P2PPayloadIntegrity.signPayload(payload);
      final jsonStr = jsonEncode(signed);
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));

      // Receiver verifies bytes directly from Nearby transport
      final verified = OfflineNearbyService.parseAndVerifyRawBytes(bytes);
      expect(verified, isNotNull);
      expect(verified!['emergencyId'], 'JS-OFF-P3-005');
      expect(verified['responderId'], 'responder_verified');
      expect(verified['role'], 'PRIMARY');

      // Now tamper one byte in the JSON string
      final tamperedJson = jsonStr.replaceAll('28.6139', '28.9999');
      final tamperedBytes = Uint8List.fromList(utf8.encode(tamperedJson));
      final rejected = OfflineNearbyService.parseAndVerifyRawBytes(tamperedBytes);
      expect(rejected, isNull);
    });

    test('P3-1.6: handleIncomingPayload with requireIntegrity guards against untrusted payloads', () async {
      final nearbyService = OfflineNearbyService();

      final untrustedPayload = {
        'eventType': 'STATUS_UPDATE',
        'emergencyId': 'JS-OFF-UNTRUSTED',
        'status': 'CANCELLED',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final rejected = await nearbyService.handleIncomingPayload(untrustedPayload, requireIntegrity: true);
      expect(rejected, isFalse);

      final trustedPayload = P2PPayloadIntegrity.signPayload(untrustedPayload);
      final accepted = await nearbyService.handleIncomingPayload(trustedPayload, requireIntegrity: true);
      expect(accepted, isTrue);
    });

    test('P3-2.1: Local profile cache isolation regression test (cannot hijack another UID)', () async {
      final prefs = await SharedPreferences.getInstance();

      // Seed local storage with Device Owner's profile (Alice)
      final localProfile = {
        'id': 'device_owner_alice',
        'name': 'Alice Device Owner',
        'email': 'alice@vita-resq.org',
        'phoneNumber': '+919999999999',
        'bloodGroup': 'A+',
        'userRole': 'CITIZEN',
      };
      await prefs.setString('local_user_profile_v2', jsonEncode(localProfile));

      final authService = AuthService();

      // Querying Bob's UID must NEVER return Alice's local profile
      final bobProfile = await authService.getUserProfile('victim_bob');
      expect(bobProfile, isNull);

      // Querying Alice's own UID correctly returns Alice's profile
      final aliceProfile = await authService.getUserProfile('device_owner_alice');
      expect(aliceProfile, isNotNull);
      expect(aliceProfile!.id, 'device_owner_alice');
      expect(aliceProfile.name, 'Alice Device Owner');
    });

    test('P3-3.1: SHA-256 standard test vector verification', () {
      // Known standard test vector: "abc"
      final hash = AppSha256.hashString('abc');
      expect(hash, 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');

      // Empty string standard vector
      final emptyHash = AppSha256.hashString('');
      expect(emptyHash, 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    });
  });
}
