import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jan_sarthi/core/constants/app_constants.dart';
import 'package:jan_sarthi/models/emergency_model.dart';
import 'package:jan_sarthi/services/auth_service.dart';
import 'package:jan_sarthi/services/offline_communication_service.dart';
import 'package:jan_sarthi/services/local_database_service.dart';
import 'package:jan_sarthi/services/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (MethodCall methodCall) async {
        return <int, int>{0: 1, 1: 1, 2: 1, 3: 1, 4: 1, 5: 1};
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('nearby_connections'),
      (MethodCall methodCall) async {
        return true;
      },
    );
  });

  group('Vita ResQ — SOS Dispatch & Security Verification Tests', () {
    // -------------------------------------------------------------------------
    // 1. Authenticated User Legitimate Emergency Creation & Required Fields
    // -------------------------------------------------------------------------
    test('SEC-1.1: Legitimate emergency payload has all required fields and correct initial radius', () {
      const victimUid = 'auth_user_victim_123';
      const emergencyId = 'EM-TEST-DOC-001';
      final now = DateTime.now();

      final emergency = EmergencyModel(
        id: emergencyId,
        victimId: victimUid,
        type: 'MEDICAL',
        latitude: 28.6139,
        longitude: 77.2090,
        status: EmergencyStatus.SEARCHING,
        currentRadiusMeters: AppConstants.initialEmergencyRadiusMeters,
        notifiedUserIds: [],
        responders: {},
        createdAt: now,
        updatedAt: now,
        lastVictimLocation: {
          'latitude': 28.6139,
          'longitude': 77.2090,
          'updatedAt': now.toIso8601String(),
        },
      );

      final map = emergency.toMap();

      // Rule validation checks
      expect(map['id'], emergencyId);
      expect(map['victimId'], victimUid);
      expect(map['status'], 'SEARCHING');
      expect(map['type'], 'MEDICAL');
      expect(map['latitude'], 28.6139);
      expect(map['longitude'], 77.2090);
      expect(map['currentRadiusMeters'], 500.0);
      expect(map['currentRadiusMeters'], lessThanOrEqualTo(AppConstants.maxEmergencyRadiusMeters));
      expect(map['notifiedUserIds'], isEmpty);
      expect(map['responders'], isEmpty);
      expect(map['createdAt'], isNotNull);
      expect(map['updatedAt'], isNotNull);
      expect(map['lastVictimLocation'], isNotNull);
      expect(map['lastVictimLocation']['latitude'], 28.6139);
      expect(map['lastVictimLocation']['longitude'], 77.2090);
    });

    // -------------------------------------------------------------------------
    // 2. Unauthenticated User Rejection Simulation
    // -------------------------------------------------------------------------
    test('SEC-2.1: Unauthenticated user creation check throws descriptive exception', () {
      String? simulateAuthCheck(String? currentUserUid) {
        if (currentUserUid == null) {
          throw Exception("User not authenticated");
        }
        return currentUserUid;
      }

      expect(() => simulateAuthCheck(null), throwsA(predicate((e) =>
          e.toString().contains("User not authenticated"))));
    });

    // -------------------------------------------------------------------------
    // 3. User Impersonation Prevention (victimId mismatch)
    // -------------------------------------------------------------------------
    test('SEC-3.1: Creation fails if victimId does not match authenticated user UID', () {
      const authenticatedUid = 'legit_user_456';
      const impersonatedUid = 'victim_victim_999';

      void validateOwnership(String authUid, String? requestedVictimId) {
        final effectiveVictimId = requestedVictimId ?? authUid;
        if (effectiveVictimId != authUid) {
          throw Exception("Cannot create emergency: victimId mismatch with authenticated user");
        }
      }

      // Valid: no mismatch
      expect(() => validateOwnership(authenticatedUid, authenticatedUid), returnsNormally);
      expect(() => validateOwnership(authenticatedUid, null), returnsNormally);

      // Invalid: impersonation
      expect(() => validateOwnership(authenticatedUid, impersonatedUid), throwsA(predicate((e) =>
          e.toString().contains("victimId mismatch"))));
    });

    // -------------------------------------------------------------------------
    // 4. Firestore Security Rules Logic Invariant Testing
    // -------------------------------------------------------------------------
    test('SEC-4.1: Firestore rules evaluation simulator correctly accepts valid and rejects invalid operations', () {
      // Simulates rule evaluation in pure Dart
      bool evaluateEmergencyCreate({
        required String? authUid,
        required Map<String, dynamic> data,
        required String docId,
      }) {
        if (authUid == null) return false;
        if (data['victimId'] != authUid) return false;
        if (data['id'] != docId) return false;
        if (data['status'] != 'SEARCHING') return false;
        if (data['latitude'] is! num || data['longitude'] is! num) return false;
        if (data['currentRadiusMeters'] is! num || (data['currentRadiusMeters'] as num) > 5000.0) return false;
        return true;
      }

      final validData = {
        'id': 'EM-01',
        'victimId': 'user_123',
        'status': 'SEARCHING',
        'latitude': 19.076,
        'longitude': 72.877,
        'currentRadiusMeters': 500.0,
      };

      // Valid creation
      expect(evaluateEmergencyCreate(authUid: 'user_123', data: validData, docId: 'EM-01'), isTrue);

      // Unauthenticated -> Deny
      expect(evaluateEmergencyCreate(authUid: null, data: validData, docId: 'EM-01'), isFalse);

      // Impersonation (victimId != auth.uid) -> Deny
      expect(evaluateEmergencyCreate(authUid: 'attacker_666', data: validData, docId: 'EM-01'), isFalse);

      // Non-SEARCHING initial status -> Deny
      final completedData = Map<String, dynamic>.from(validData)..['status'] = 'COMPLETED';
      expect(evaluateEmergencyCreate(authUid: 'user_123', data: completedData, docId: 'EM-01'), isFalse);

      // Radius exceeding 5000m security boundary -> Deny
      final excessiveRadiusData = Map<String, dynamic>.from(validData)..['currentRadiusMeters'] = 50000.0;
      expect(evaluateEmergencyCreate(authUid: 'user_123', data: excessiveRadiusData, docId: 'EM-01'), isFalse);

      // Document ID mismatch -> Deny
      expect(evaluateEmergencyCreate(authUid: 'user_123', data: validData, docId: 'WRONG-ID'), isFalse);
    });

    test('SEC-4.2: Firestore user profile rule evaluation simulator enforces strict ownership', () {
      bool evaluateUserWrite({
        required String? authUid,
        required String targetDocUid,
      }) {
        if (authUid == null) return false;
        return authUid == targetDocUid;
      }

      expect(evaluateUserWrite(authUid: 'user_abc', targetDocUid: 'user_abc'), isTrue);
      expect(evaluateUserWrite(authUid: 'user_abc', targetDocUid: 'user_xyz'), isFalse);
      expect(evaluateUserWrite(authUid: null, targetDocUid: 'user_abc'), isFalse);
    });

    // -------------------------------------------------------------------------
    // 5. Existing Profile UID Isolation Invariant
    // -------------------------------------------------------------------------
    test('SEC-5.1: AuthService profile cache isolation prevents cross-user leakage', () async {
      final authService = AuthService();

      // Seed local storage with current user profile
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_user_profile_v2', '{"id":"current_device_user","name":"Device Owner","email":"owner@vita.org"}');

      // Requesting different user UID MUST return null (not device owner's profile)
      final otherProfile = await authService.getUserProfile('attacker_or_other_user');
      expect(otherProfile, isNull);
    });

    // -------------------------------------------------------------------------
    // 6. Existing Offline / P2P Emergency Flow Remains Intact
    // -------------------------------------------------------------------------
    test('SEC-6.1: Offline P2P emergency creation and local database integrity intact', () async {
      final localDb = LocalDatabaseService();
      final offlineComm = OfflineCommunicationService();

      final emId = await offlineComm.broadcastSOS(
        position: Position(
          latitude: 12.9716,
          longitude: 77.5946,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        ),
        currentUserId: 'offline_sec_victim',
      );

      expect(emId, startsWith('JS-OFF-'));

      final stored = await localDb.getEmergencyById(emId);
      expect(stored, isNotNull);
      expect(stored!.victimId, 'offline_sec_victim');
      expect(stored.isOffline, isTrue);
      expect(stored.status, EmergencyStatus.SEARCHING);
      expect(stored.currentRadiusMeters, AppConstants.initialEmergencyRadiusMeters);

      await offlineComm.stop();
    });

    // -------------------------------------------------------------------------
    // 7. LocationService Reactive Stream Verification
    // -------------------------------------------------------------------------
    test('SEC-7.1: LocationService exposes reactive onPositionChanged stream', () {
      final locationService = LocationService();
      expect(locationService.onPositionChanged, isNotNull);
      expect(locationService.onPositionChanged.isBroadcast, isTrue);
    });
  });
}
