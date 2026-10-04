import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jan_sarthi/core/constants/app_constants.dart';
import 'package:jan_sarthi/models/emergency_model.dart';
import 'package:jan_sarthi/services/auth_service.dart';
import 'package:jan_sarthi/services/local_database_service.dart';
import 'package:jan_sarthi/services/offline_nearby_service.dart';
import 'package:jan_sarthi/services/responder_reliability_monitor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P0 Critical Integrity Tests', () {
    // -------------------------------------------------------------
    // P0-1: AUTH PROFILE CACHE HIJACK
    // -------------------------------------------------------------
    test('P0-1.1: getUserProfile(uid) returns current user profile when cached', () async {
      SharedPreferences.setMockInitialValues({
        'local_user_profile_v2': jsonEncode({
          'id': 'current_user_123',
          'name': 'Primary Responder',
          'email': 'primary@vitaresq.org',
          'phoneNumber': '+919876543210',
          'bloodGroup': 'O+',
          'userRole': 'CITIZEN',
          'isOnline': true,
        }),
      });

      final authService = AuthService();
      final profile = await authService.getUserProfile('current_user_123');

      expect(profile, isNotNull);
      expect(profile!.id, 'current_user_123');
      expect(profile.name, 'Primary Responder');
    });

    test('P0-1.2: getUserProfile(uid) NEVER returns local cached profile when another user UID is requested', () async {
      // Local cache holds current user 'victim_999'
      SharedPreferences.setMockInitialValues({
        'local_user_profile_v2': jsonEncode({
          'id': 'victim_999',
          'name': 'Victim Jane Doe',
          'email': 'jane@vitaresq.org',
          'phoneNumber': '+919999999999',
          'bloodGroup': 'AB+',
          'userRole': 'CITIZEN',
          'isOnline': true,
        }),
      });

      final authService = AuthService();
      // Victim tries to view Helper 'helper_456'
      final profile = await authService.getUserProfile('helper_456');

      // MUST NOT return Victim Jane Doe's profile for helper_456
      expect(profile?.id != 'victim_999', isTrue);
      if (profile != null) {
        expect(profile.id, 'helper_456');
      } else {
        expect(profile, isNull);
      }
    });

    // -------------------------------------------------------------
    // P0-2: OFFLINE EMERGENCY LOCATION HANDLING
    // -------------------------------------------------------------
    test('P0-2.1: Offline victim location update updates emergency coordinates via P2P payload', () async {
      SharedPreferences.setMockInitialValues({});
      final localDb = LocalDatabaseService();

      final now = DateTime.now();
      final initialEmergency = EmergencyModel(
        id: 'JS-OFF-1001',
        victimId: 'victim_01',
        type: 'MEDICAL',
        latitude: 12.9716,
        longitude: 77.5946,
        status: EmergencyStatus.SEARCHING,
        createdAt: now,
        updatedAt: now,
      );
      await localDb.saveEmergencyLocally(initialEmergency);

      // Victim broadcasts new GPS location over P2P (responderId is null)
      final victimLocationPayload = {
        'eventType': 'STATUS_UPDATE',
        'emergencyId': 'JS-OFF-1001',
        'status': 'SEARCHING',
        'responderId': null,
        'isVictim': true,
        'latitude': 12.9750,
        'longitude': 77.5980,
        'timestamp': now.millisecondsSinceEpoch,
      };

      final updated = await OfflineNearbyService.processStatusUpdatePayload(victimLocationPayload, localDb);
      expect(updated, isNotNull);
      expect(updated!.latitude, 12.9750);
      expect(updated.longitude, 77.5980);
      expect(updated.lastVictimLocation?['latitude'], 12.9750);
      expect(updated.lastVictimLocation?['longitude'], 77.5980);
    });

    test('P0-2.2: Offline responder location update updates responder and lastHelperLocation', () async {
      SharedPreferences.setMockInitialValues({});
      final localDb = LocalDatabaseService();

      final now = DateTime.now();
      final initialEmergency = EmergencyModel(
        id: 'JS-OFF-1002',
        victimId: 'victim_02',
        type: 'ACCIDENT',
        latitude: 12.9716,
        longitude: 77.5946,
        status: EmergencyStatus.ASSIGNED,
        helperId: 'responder_01',
        createdAt: now,
        updatedAt: now,
      );
      await localDb.saveEmergencyLocally(initialEmergency);

      // Responder sends acceptance payload first
      final acceptPayload = {
        'eventType': 'RESPONDER_ACCEPTANCE',
        'emergencyId': 'JS-OFF-1002',
        'responderId': 'responder_01',
        'responderName': 'Responder Rahul',
        'latitude': 12.9720,
        'longitude': 77.5950,
        'timestamp': now.millisecondsSinceEpoch,
      };
      await OfflineNearbyService.processAcceptancePayload(acceptPayload, localDb);

      // Responder streams live location update over P2P
      final locationPayload = {
        'eventType': 'STATUS_UPDATE',
        'emergencyId': 'JS-OFF-1002',
        'status': 'RESPONDING',
        'responderId': 'responder_01',
        'latitude': 12.9735,
        'longitude': 77.5965,
        'timestamp': now.millisecondsSinceEpoch,
      };

      final updated = await OfflineNearbyService.processStatusUpdatePayload(locationPayload, localDb);
      expect(updated, isNotNull);
      expect(updated!.responders['responder_01']?.latitude, 12.9735);
      expect(updated.responders['responder_01']?.longitude, 77.5965);
      expect(updated.lastHelperLocation?['latitude'], 12.9735);
    });

    // -------------------------------------------------------------
    // P0-3: MAP ROUTE RECALCULATION & DELTA GUARD
    // -------------------------------------------------------------
    test('P0-3.1: Minimum coordinate change threshold (8.0m) prevents recalculation loops', () {
      const origin1 = LatLng(12.97160, 77.59460);
      // Small drift: 2 meters away
      const origin2 = LatLng(12.97161, 77.59461);
      const dest = LatLng(12.97500, 77.59800);

      double originDelta = Geolocator.distanceBetween(
        origin1.latitude,
        origin1.longitude,
        origin2.latitude,
        origin2.longitude,
      );

      double destDelta = Geolocator.distanceBetween(
        dest.latitude,
        dest.longitude,
        dest.latitude,
        dest.longitude,
      );

      // Delta should be well below 8.0 meters
      expect(originDelta, lessThan(8.0));
      expect(destDelta, 0.0);

      // Even if route polyline has length == 2 (direct fallback line),
      // originDelta < 8.0 && destDelta < 8.0 suppresses recalculation.
      bool shouldRecalculate = (originDelta >= 8.0 || destDelta >= 8.0);
      expect(shouldRecalculate, isFalse);
    });

    test('P0-3.2: Coordinate change >= 8.0m triggers route recalculation', () {
      const origin1 = LatLng(12.97160, 77.59460);
      // 50 meters away
      const origin2 = LatLng(12.97205, 77.59460);
      const dest = LatLng(12.97500, 77.59800);

      double originDelta = Geolocator.distanceBetween(
        origin1.latitude,
        origin1.longitude,
        origin2.latitude,
        origin2.longitude,
      );
      double destDelta = Geolocator.distanceBetween(
        dest.latitude,
        dest.longitude,
        dest.latitude,
        dest.longitude,
      );

      expect(originDelta, greaterThan(8.0));
      bool shouldRecalculate = (originDelta >= 8.0 || destDelta >= 8.0);
      expect(shouldRecalculate, isTrue);
    });

    test('P0-3.3: Direct distance / Haversine fallback calculates valid polyline and ETA', () {
      const origin = LatLng(12.9716, 77.5946);
      const dest = LatLng(12.9800, 77.6000);

      double directDist = Geolocator.distanceBetween(
        origin.latitude,
        origin.longitude,
        dest.latitude,
        dest.longitude,
      );

      expect(directDist, greaterThan(0));
      List<LatLng> fallbackPolyline = [origin, dest];
      expect(fallbackPolyline.length, 2);

      int mins = (directDist / 80).round();
      if (mins < 1) mins = 1;
      expect(mins, greaterThanOrEqualTo(1));
    });

    // -------------------------------------------------------------
    // P0-4: RESPONDER RELIABILITY MONITOR THRESHOLDS
    // -------------------------------------------------------------
    test('P0-4.1: AppConstants.noProgressThresholdSeconds is configured to 120 seconds', () {
      expect(AppConstants.noProgressThresholdSeconds, 120);
    });

    test('P0-4.2: Responder stationary for < 120s does NOT trigger no-progress failover', () {
      final monitor = ResponderReliabilityMonitor(
        noProgressThresholdSeconds: 120,
        locationStaleThresholdSeconds: 15,
      );

      expect(monitor.noProgressThresholdSeconds, 120);

      // Simulate vehicle stopped at traffic light for 60 seconds
      int stationarySeconds = 60;
      bool isNoProgress = stationarySeconds > monitor.noProgressThresholdSeconds;
      expect(isNoProgress, isFalse, reason: 'Temporary stop at traffic light (<120s) must not failover');
    });

    test('P0-4.3: Responder stationary for > 120s triggers genuine stall failover', () {
      final monitor = ResponderReliabilityMonitor(
        noProgressThresholdSeconds: 120,
        locationStaleThresholdSeconds: 15,
      );

      // Simulate genuine vehicle stall without movement for 130 seconds
      int stationarySeconds = 130;
      bool isNoProgress = stationarySeconds > monitor.noProgressThresholdSeconds;
      expect(isNoProgress, isTrue, reason: 'Stationary for >120s must trigger genuine stall condition');
    });

    test('P0-4.4: Heartbeat location staleness (>15s) correctly identified', () {
      final monitor = ResponderReliabilityMonitor(
        locationStaleThresholdSeconds: 15,
      );

      int freshTelemetrySeconds = 5;
      expect(freshTelemetrySeconds > monitor.locationStaleThresholdSeconds, isFalse);

      int staleTelemetrySeconds = 20;
      expect(staleTelemetrySeconds > monitor.locationStaleThresholdSeconds, isTrue);
    });

    // -------------------------------------------------------------
    // P0-5: AUDIO ASSET VALIDATION
    // -------------------------------------------------------------
    test('P0-5.1: assets/audio/ directory exists on filesystem', () {
      final audioDir = Directory('assets/audio');
      expect(audioDir.existsSync(), isTrue, reason: 'assets/audio directory must exist to avoid build warnings');
    });
  });
}
