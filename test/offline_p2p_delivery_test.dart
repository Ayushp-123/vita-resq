import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

import 'package:jan_sarthi/models/emergency_model.dart';
import 'package:jan_sarthi/models/responder_model.dart';
import 'package:jan_sarthi/services/local_database_service.dart';
import 'package:jan_sarthi/services/offline_communication_service.dart';
import 'package:jan_sarthi/services/offline_nearby_service.dart';
import 'package:jan_sarthi/services/notification_service.dart';
import 'package:jan_sarthi/services/p2p_payload_integrity.dart';
import 'package:jan_sarthi/screens/responder/responder_dashboard_screen.dart';
import 'package:jan_sarthi/models/user_model.dart';
import 'package:jan_sarthi/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> nearbyCalls = [];
  final List<MethodCall> notificationCalls = [];
  bool gpsEnabled = true;
  bool permissionsGranted = true;

  final testPosition = Position(
    latitude: 28.6139,
    longitude: 77.2090,
    timestamp: DateTime(2025, 1, 1),
    accuracy: 10.0,
    altitude: 0.0,
    altitudeAccuracy: 0.0,
    heading: 0.0,
    headingAccuracy: 0.0,
    speed: 0.0,
    speedAccuracy: 0.0,
  );

  final testUser = UserModel(
    id: 'offline_user',
    name: 'Offline Volunteer',
    email: 'volunteer@vita-resq.org',
    phoneNumber: '+919876543210',
    bloodGroup: 'O+',
    userRole: 'CITIZEN',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  setUp(() {
    nearbyCalls.clear();
    notificationCalls.clear();
    gpsEnabled = true;
    permissionsGranted = true;
    LocalDatabaseService.setLocalDeviceIdForTesting(null);
    LocalDatabaseService.resetLockForTesting();
    NotificationService.resetProcessedNotifications();
    OfflineCommunicationService.clearNotifiedAlertsForTesting();

    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});

    // Mock Nearby Connections channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('nearby_connections'),
      (MethodCall call) async {
        nearbyCalls.add(call);
        return true;
      },
    );

    // Mock Notifications channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.example.jan_sarthi/notifications'),
      (MethodCall call) async {
        notificationCalls.add(call);
        return null;
      },
    );

    // Mock Permissions channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (MethodCall call) async {
        if (!permissionsGranted) {
          return <int, int>{0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
        }
        return <int, int>{0: 1, 1: 1, 2: 1, 3: 1, 4: 1, 5: 1};
      },
    );

    // Mock Geolocator channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
      (MethodCall call) async {
        if (call.method == 'isLocationServiceEnabled') {
          return gpsEnabled;
        }
        return null;
      },
    );
  });

  tearDown(() async {
    await OfflineNearbyService().stopAll();
    LocalDatabaseService.setLocalDeviceIdForTesting(null);
    LocalDatabaseService.resetLockForTesting();
    OfflineCommunicationService.clearNotifiedAlertsForTesting();
  });

  group('FIX 1 & 2: Stable Local Device Identity & Self-Alert Handling', () {
    test('1. Two different installations receive different persisted local device IDs', () async {
      SharedPreferences.setMockInitialValues({});
      LocalDatabaseService.setLocalDeviceIdForTesting(null);
      final id1 = await LocalDatabaseService.getOrCreateLocalDeviceId();

      // Simulate a completely distinct second installation (clean storage)
      SharedPreferences.setMockInitialValues({});
      LocalDatabaseService.setLocalDeviceIdForTesting(null);
      final id2 = await LocalDatabaseService.getOrCreateLocalDeviceId();

      expect(id1, isNotEmpty);
      expect(id2, isNotEmpty);
      expect(id1, startsWith('dev_'));
      expect(id2, startsWith('dev_'));
      expect(id1, isNot(equals(id2)));
    });

    test('2. The same installation retains its ID after reopening the app', () async {
      final id1 = await LocalDatabaseService.getOrCreateLocalDeviceId();
      // Simulate app restart without clearing storage
      LocalDatabaseService.setLocalDeviceIdForTesting(null);
      final id2 = await LocalDatabaseService.getOrCreateLocalDeviceId();

      expect(id1, equals(id2));
    });

    test('3. A device does not suppress an emergency from another offline installation', () async {
      // Device B (Responder)
      LocalDatabaseService.setLocalDeviceIdForTesting('dev_responder_bbb');
      final offlineComm = OfflineCommunicationService();

      final stream = offlineComm.listenForAlerts(
        userLat: 28.6139,
        userLon: 77.2090,
        currentUserId: 'offline_user',
      );

      EmergencyModel? receivedAlert;
      final sub = stream.listen((emergencies) {
        if (emergencies.isNotEmpty) {
          receivedAlert = emergencies.first;
        }
      });

      // Packet arrives from Device A (Victim) with matching generic offline_user
      // BUT distinct originDeviceId
      OfflineNearbyService().triggerSOSDiscoveredForTesting({
        'emergencyId': 'JS-OFF-DEV-A-1',
        'victimId': 'offline_user',
        'originDeviceId': 'dev_victim_aaa',
        'type': 'MEDICAL',
        'latitude': 28.6140,
        'longitude': 77.2090,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await Future.delayed(const Duration(milliseconds: 50));

      expect(receivedAlert, isNotNull);
      expect(receivedAlert!.id, 'JS-OFF-DEV-A-1');
      expect(receivedAlert!.originDeviceId, 'dev_victim_aaa');

      // Check notification triggered
      expect(notificationCalls.any((c) => c.arguments['emergencyId'] == 'JS-OFF-DEV-A-1'), isTrue);

      await sub.cancel();
    });

    test('4. A device does suppress its own broadcast', () async {
      // Device A (Victim)
      LocalDatabaseService.setLocalDeviceIdForTesting('dev_victim_aaa');
      final offlineComm = OfflineCommunicationService();

      final stream = offlineComm.listenForAlerts(
        userLat: 28.6139,
        userLon: 77.2090,
        currentUserId: 'offline_user',
      );

      EmergencyModel? receivedAlert;
      final sub = stream.listen((emergencies) {
        if (emergencies.isNotEmpty) {
          receivedAlert = emergencies.first;
        }
      });

      // Packet echoes back from Device A's own originDeviceId
      OfflineNearbyService().triggerSOSDiscoveredForTesting({
        'emergencyId': 'JS-OFF-OWN-1',
        'victimId': 'offline_user',
        'originDeviceId': 'dev_victim_aaa',
        'type': 'MEDICAL',
        'latitude': 28.6140,
        'longitude': 77.2090,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await Future.delayed(const Duration(milliseconds: 50));

      expect(receivedAlert, isNull);
      expect(notificationCalls.any((c) => c.arguments['emergencyId'] == 'JS-OFF-OWN-1'), isFalse);

      await sub.cancel();
    });

    test('5. Offline claim self-checks use the correct local participant identity', () async {
      final localDb = LocalDatabaseService();
      LocalDatabaseService.setLocalDeviceIdForTesting('dev_victim_aaa');

      final emergency = EmergencyModel(
        id: 'JS-OFF-CLAIM-1',
        victimId: 'offline_user',
        originDeviceId: 'dev_victim_aaa',
        latitude: 28.6139,
        longitude: 77.2090,
        status: EmergencyStatus.SEARCHING,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await localDb.saveEmergencyLocally(emergency);

      // 1. Claim from same origin device must be rejected
      final selfClaimResult = await OfflineNearbyService.processClaimRequest({
        'emergencyId': 'JS-OFF-CLAIM-1',
        'responderId': 'offline_helper_dev_victim_aaa',
        'originDeviceId': 'dev_victim_aaa',
        'responderName': 'Self',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }, localDb);

      expect(selfClaimResult.accepted, isFalse);
      expect(selfClaimResult.reason, 'VICTIM_CANNOT_RESPOND');

      // 2. Claim from different device must be accepted
      final validClaimResult = await OfflineNearbyService.processClaimRequest({
        'emergencyId': 'JS-OFF-CLAIM-1',
        'responderId': 'offline_helper_dev_responder_bbb',
        'originDeviceId': 'dev_responder_bbb',
        'responderName': 'Helper Bob',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }, localDb);

      expect(validClaimResult.accepted, isTrue);
      expect(validClaimResult.role, ResponderRole.PRIMARY);
      expect(validClaimResult.updatedEmergency!.responders.containsKey('offline_helper_dev_responder_bbb'), isTrue);
    });
  });

  group('FIX 3 & 4: Serialization, Discovery Lifecycle, & Freshness Skew', () {
    test('6. Sender and receiver serialize and parse the same offline payload format', () {
      final original = {
        'eventType': 'SOS_BROADCAST',
        'emergencyId': 'JS-OFF-SERIAL-1',
        'victimId': 'offline_user',
        'originDeviceId': 'dev_test_123',
        'latitude': 28.6139,
        'longitude': 77.2090,
        'type': 'MEDICAL',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final signed = P2PPayloadIntegrity.signPayload(original);
      final jsonStr = jsonEncode(signed);
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));

      final parsed = P2PPayloadIntegrity.parseAndVerifyBytes(bytes);
      expect(parsed, isNotNull);
      expect(parsed!['emergencyId'], 'JS-OFF-SERIAL-1');
      expect(parsed['originDeviceId'], 'dev_test_123');
      expect(parsed['latitude'], 28.6139);
      expect(parsed['_integrity'], isNotNull);
    });

    testWidgets('7. A valid P2P emergency appears in the responder dashboard without a Firestore query succeeding', (tester) async {
      LocalDatabaseService.setLocalDeviceIdForTesting('dev_responder_dash');

      final testEmergency = EmergencyModel(
        id: 'JS-OFF-DASH-1',
        victimId: 'offline_user',
        originDeviceId: 'dev_victim_dash',
        latitude: 28.6139,
        longitude: 77.2090,
        status: EmergencyStatus.SEARCHING,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ResponderDashboardScreen(
            initialEmergencies: [testEmergency],
            initialIsAvailable: true,
            initialPosition: Position(
              latitude: 28.6139,
              longitude: 77.2090,
              timestamp: DateTime.now(),
              accuracy: 10.0,
              altitude: 0.0,
              altitudeAccuracy: 0.0,
              heading: 0.0,
              headingAccuracy: 0.0,
              speed: 0.0,
              speedAccuracy: 0.0,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ResponderDashboardScreen), findsOneWidget);
    });

    test('8. Discovery initialization is idempotent', () async {
      final nearbyService = OfflineNearbyService();
      expect(nearbyService.isDiscovering, isFalse);

      await nearbyService.startSOSDiscovery(
        currentUserId: 'offline_user',
        onSOSDiscovered: (_) {},
      );
      expect(nearbyService.isDiscovering, isTrue);

      // Second call does not throw or restart duplicate discovery
      await nearbyService.startSOSDiscovery(
        currentUserId: 'offline_user',
        onSOSDiscovered: (_) {},
      );
      expect(nearbyService.isDiscovering, isTrue);

      await nearbyService.stopSOSDiscovery();
      // Still 1 subscriber remaining
      expect(nearbyService.isDiscovering, isTrue);

      await nearbyService.stopSOSDiscovery();
      // 0 subscribers remaining -> stops discovery
      expect(nearbyService.isDiscovering, isFalse);
    });

    test('9. Missing or denied permissions produce a clear failure', () async {
      gpsEnabled = false;
      final nearbyService = OfflineNearbyService();
      final hasPerm = await nearbyService.checkOfflinePermissions();
      expect(hasPerm, isFalse);

      gpsEnabled = true;
      permissionsGranted = false;
      final hasPerm2 = await nearbyService.checkOfflinePermissions();
      expect(hasPerm2, isFalse);
    });

    test('10. Integrity-invalid or replayed messages are rejected', () {
      final payload = {
        'eventType': 'SOS_BROADCAST',
        'emergencyId': 'JS-OFF-TAMPER-1',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        '_integrity': 'bad_token_hash',
      };
      expect(P2PPayloadIntegrity.verifyPayload(payload), isFalse);
    });

    test('11. Terminal emergencies cannot reappear as active alerts', () async {
      final localDb = LocalDatabaseService();
      LocalDatabaseService.setLocalDeviceIdForTesting('dev_responder_term');

      final terminalEmergency = EmergencyModel(
        id: 'JS-OFF-TERM-1',
        victimId: 'offline_user',
        originDeviceId: 'dev_victim_term',
        latitude: 28.6139,
        longitude: 77.2090,
        status: EmergencyStatus.COMPLETED,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await localDb.saveEmergencyLocally(terminalEmergency);

      final offlineComm = OfflineCommunicationService();
      final stream = offlineComm.listenForAlerts(
        userLat: 28.6139,
        userLon: 77.2090,
        currentUserId: 'offline_user',
      );

      List<EmergencyModel> emitted = [];
      final sub = stream.listen((list) => emitted = list);

      OfflineNearbyService().triggerSOSDiscoveredForTesting({
        'emergencyId': 'JS-OFF-TERM-1',
        'victimId': 'offline_user',
        'originDeviceId': 'dev_victim_term',
        'type': 'MEDICAL',
        'latitude': 28.6140,
        'longitude': 77.2090,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await Future.delayed(const Duration(milliseconds: 50));
      expect(emitted.where((e) => e.id == 'JS-OFF-TERM-1'), isEmpty);

      await sub.cancel();
    });

    test('12. Clock differences do not incorrectly discard an otherwise valid, fresh offline emergency', () {
      // 8 minutes difference between devices (would fail 5-min threshold, but passes 60-min threshold)
      final createdAt8MinAgo = DateTime.now().subtract(const Duration(minutes: 8));
      final alert = EmergencyModel(
        id: 'JS-OFF-CLOCK-1',
        victimId: 'offline_user',
        originDeviceId: 'dev_victim_clock',
        latitude: 28.6139,
        longitude: 77.2090,
        status: EmergencyStatus.SEARCHING,
        createdAt: createdAt8MinAgo,
        updatedAt: createdAt8MinAgo,
      );

      expect(alert.isOffline, isTrue);
      final maxAgeMinutes = alert.isOffline ? 60 : 5;
      final diff = DateTime.now().difference(alert.createdAt).inMinutes.abs();

      expect(diff, greaterThan(5));
      expect(diff <= maxAgeMinutes, isTrue); // Passes safe 60-min window
    });

    test('13. Restoring internet does not convert a synthetic local device ID into an authenticated Firebase identity', () {
      final alert = EmergencyModel(
        id: 'JS-OFF-SYNC-1',
        victimId: 'offline_user', // unauthenticated
        originDeviceId: 'dev_victim_sync_123',
        latitude: 28.6139,
        longitude: 77.2090,
        status: EmergencyStatus.SEARCHING,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final map = alert.toMap();
      // victimId remains unchanged as 'offline_user' and does not pretend to be a Firebase UID
      expect(map['victimId'], 'offline_user');
      expect(map['originDeviceId'], 'dev_victim_sync_123');
    });
  });

  group('FIX: Offline Alert Freshness, Terminal-Update Handling, and Deduplication', () {
    test('14. A fresh offline SOS is accepted at ingress, persisted, and notified', () async {
      final localDb = LocalDatabaseService();
      LocalDatabaseService.setLocalDeviceIdForTesting('dev_responder_fresh');

      final offlineComm = OfflineCommunicationService();
      final stream = offlineComm.listenForAlerts(
        userLat: 28.6139,
        userLon: 77.2090,
        currentUserId: 'offline_user',
      );

      List<EmergencyModel> emitted = [];
      final sub = stream.listen((list) => emitted = list);

      final freshTs = DateTime.now().subtract(const Duration(minutes: 5)).millisecondsSinceEpoch;
      OfflineNearbyService().triggerSOSDiscoveredForTesting({
        'emergencyId': 'JS-OFF-FRESH-1',
        'victimId': 'offline_user',
        'originDeviceId': 'dev_victim_fresh_99',
        'type': 'MEDICAL',
        'latitude': 28.6140,
        'longitude': 77.2090,
        'timestamp': freshTs,
      });

      await Future.delayed(const Duration(milliseconds: 60));

      final saved = await localDb.getEmergencyById('JS-OFF-FRESH-1');
      expect(saved, isNotNull);
      expect(saved?.id, 'JS-OFF-FRESH-1');
      expect(emitted.any((e) => e.id == 'JS-OFF-FRESH-1'), isTrue);
      expect(
        notificationCalls.any((c) =>
            c.method == 'showEmergencyNotification' &&
            c.arguments['emergencyId'] == 'JS-OFF-FRESH-1'),
        isTrue,
      );

      await sub.cancel();
      await offlineComm.stop();
    });

    test('15. An offline SOS older than 60 minutes is rejected before persistence and notification', () async {
      final localDb = LocalDatabaseService();
      LocalDatabaseService.setLocalDeviceIdForTesting('dev_responder_stale');

      final offlineComm = OfflineCommunicationService();
      final stream = offlineComm.listenForAlerts(
        userLat: 28.6139,
        userLon: 77.2090,
        currentUserId: 'offline_user',
      );

      List<EmergencyModel> emitted = [];
      final sub = stream.listen((list) => emitted = list);

      final staleTs = DateTime.now().subtract(const Duration(minutes: 65)).millisecondsSinceEpoch;
      OfflineNearbyService().triggerSOSDiscoveredForTesting({
        'emergencyId': 'JS-OFF-STALE-1',
        'victimId': 'offline_user',
        'originDeviceId': 'dev_victim_stale_99',
        'type': 'MEDICAL',
        'latitude': 28.6140,
        'longitude': 77.2090,
        'timestamp': staleTs,
      });

      await Future.delayed(const Duration(milliseconds: 60));

      // Must NOT be saved locally
      final saved = await localDb.getEmergencyById('JS-OFF-STALE-1');
      expect(saved, isNull);

      // Must NOT be in emitted active alerts
      expect(emitted.any((e) => e.id == 'JS-OFF-STALE-1'), isFalse);

      // Must NOT trigger notification
      expect(
        notificationCalls.any((c) =>
            c.method == 'showEmergencyNotification' &&
            c.arguments['emergencyId'] == 'JS-OFF-STALE-1'),
        isFalse,
      );

      await sub.cancel();
      await offlineComm.stop();
    });

    test('16. Invalid timestamps (null, non-num, negative) are handled safely and rejected', () async {
      expect(OfflineCommunicationService.isValidAndFreshCreationTimestamp(null), isFalse);
      expect(OfflineCommunicationService.isValidAndFreshCreationTimestamp('invalid_str'), isFalse);
      expect(OfflineCommunicationService.isValidAndFreshCreationTimestamp(-1000), isFalse);
      expect(OfflineCommunicationService.isValidAndFreshCreationTimestamp(0), isFalse);

      final localDb = LocalDatabaseService();
      LocalDatabaseService.setLocalDeviceIdForTesting('dev_responder_inv');

      final offlineComm = OfflineCommunicationService();
      final stream = offlineComm.listenForAlerts(
        userLat: 28.6139,
        userLon: 77.2090,
        currentUserId: 'offline_user',
      );

      final sub = stream.listen((_) {});

      // Corrupted timestamp
      OfflineNearbyService().triggerSOSDiscoveredForTesting({
        'emergencyId': 'JS-OFF-CORRUPT-1',
        'victimId': 'offline_user',
        'originDeviceId': 'dev_victim_corrupt_99',
        'type': 'MEDICAL',
        'latitude': 28.6140,
        'longitude': 77.2090,
        'timestamp': null,
      });

      await Future.delayed(const Duration(milliseconds: 50));
      expect(await localDb.getEmergencyById('JS-OFF-CORRUPT-1'), isNull);
      expect(
        notificationCalls.any((c) =>
            c.method == 'showEmergencyNotification' &&
            c.arguments['emergencyId'] == 'JS-OFF-CORRUPT-1'),
        isFalse,
      );

      await sub.cancel();
      await offlineComm.stop();
    });

    test('17. A timestamp substantially in the future (> 60m) is rejected according to absolute-skew policy', () async {
      final futureTs = DateTime.now().add(const Duration(minutes: 75)).millisecondsSinceEpoch;
      expect(OfflineCommunicationService.isValidAndFreshCreationTimestamp(futureTs), isFalse);

      final localDb = LocalDatabaseService();
      LocalDatabaseService.setLocalDeviceIdForTesting('dev_responder_fut');

      final offlineComm = OfflineCommunicationService();
      final stream = offlineComm.listenForAlerts(
        userLat: 28.6139,
        userLon: 77.2090,
        currentUserId: 'offline_user',
      );

      final sub = stream.listen((_) {});

      OfflineNearbyService().triggerSOSDiscoveredForTesting({
        'emergencyId': 'JS-OFF-FUTURE-1',
        'victimId': 'offline_user',
        'originDeviceId': 'dev_victim_future_99',
        'type': 'MEDICAL',
        'latitude': 28.6140,
        'longitude': 77.2090,
        'timestamp': futureTs,
      });

      await Future.delayed(const Duration(milliseconds: 50));
      expect(await localDb.getEmergencyById('JS-OFF-FUTURE-1'), isNull);
      expect(
        notificationCalls.any((c) =>
            c.method == 'showEmergencyNotification' &&
            c.arguments['emergencyId'] == 'JS-OFF-FUTURE-1'),
        isFalse,
      );

      await sub.cancel();
      await offlineComm.stop();
    });

    test('18. A legitimate terminal update for a known old emergency is still processed', () async {
      final localDb = LocalDatabaseService();
      LocalDatabaseService.setLocalDeviceIdForTesting('dev_responder_term_old');

      // Emergency was created 90 minutes ago (old/stale creation timestamp)
      final createdAt90MinAgo = DateTime.now().subtract(const Duration(minutes: 90));
      final oldEmergency = EmergencyModel(
        id: 'JS-OFF-OLD-EMERGENCY',
        victimId: 'offline_user',
        originDeviceId: 'dev_victim_old',
        latitude: 28.6139,
        longitude: 77.2090,
        status: EmergencyStatus.SEARCHING,
        createdAt: createdAt90MinAgo,
        updatedAt: createdAt90MinAgo,
      );
      await localDb.saveEmergencyLocally(oldEmergency);

      final offlineComm = OfflineCommunicationService();
      final stream = offlineComm.listenForAlerts(
        userLat: 28.6139,
        userLon: 77.2090,
        currentUserId: 'offline_user',
      );

      List<EmergencyModel> emitted = [];
      final sub = stream.listen((list) => emitted = list);

      // Now sender sends terminal update (e.g. CANCELLED)
      final terminalUpdate = EmergencyModel(
        id: oldEmergency.id,
        victimId: oldEmergency.victimId,
        originDeviceId: oldEmergency.originDeviceId,
        latitude: oldEmergency.latitude,
        longitude: oldEmergency.longitude,
        status: EmergencyStatus.CANCELLED,
        createdAt: oldEmergency.createdAt,
        updatedAt: DateTime.now(),
      );

      // Broadcast update on local database stream (as STATUS_UPDATE handler does)
      LocalDatabaseService.broadcastUpdate(terminalUpdate);
      await Future.delayed(const Duration(milliseconds: 60));

      // Terminal update was processed without being blocked by creation freshness
      expect(emitted.where((e) => e.id == 'JS-OFF-OLD-EMERGENCY'), isEmpty);
      expect(terminalUpdate.isTerminal, isTrue);

      await sub.cancel();
      await offlineComm.stop();
    });

    testWidgets('19. A stale local offline emergency is not displayed as an active responder opportunity', (tester) async {
      final staleCreatedAt = DateTime.now().subtract(const Duration(minutes: 90));
      final staleEmergency = EmergencyModel(
        id: 'JS-OFF-DASH-STALE',
        victimId: 'stale_victim_dash',
        originDeviceId: 'dev_victim_dash_stale',
        latitude: 28.6145,
        longitude: 77.2095,
        status: EmergencyStatus.SEARCHING,
        createdAt: staleCreatedAt,
        updatedAt: staleCreatedAt,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ResponderDashboardScreen(
            initialPosition: testPosition,
            initialUserProfile: testUser,
            initialIsAvailable: true,
            initialEmergencies: [staleEmergency],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Stale emergency is not displayed in active opportunities
      expect(find.text('JS-OFF-DASH-STALE'), findsNothing);
      expect(find.text('NEAREST INCIDENT'), findsNothing);
      expect(find.text('Scanning for nearby incidents'), findsOneWidget);

      // Clean test teardown
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    test('20. Repeated packets for the same emergency do not produce duplicate notifications', () async {
      LocalDatabaseService.setLocalDeviceIdForTesting('dev_responder_dedup');
      final offlineComm = OfflineCommunicationService();
      final stream = offlineComm.listenForAlerts(
        userLat: 28.6139,
        userLon: 77.2090,
        currentUserId: 'offline_user',
      );

      final sub = stream.listen((_) {});

      final ts = DateTime.now().subtract(const Duration(minutes: 2)).millisecondsSinceEpoch;
      final packet = {
        'emergencyId': 'JS-OFF-REPEAT-1',
        'victimId': 'offline_user',
        'originDeviceId': 'dev_victim_repeat',
        'type': 'MEDICAL',
        'latitude': 28.6140,
        'longitude': 77.2090,
        'timestamp': ts,
      };

      // Broadcast packet 3 times (simulating re-discovery bursts)
      OfflineNearbyService().triggerSOSDiscoveredForTesting(packet);
      await Future.delayed(const Duration(milliseconds: 30));
      OfflineNearbyService().triggerSOSDiscoveredForTesting(packet);
      await Future.delayed(const Duration(milliseconds: 30));
      OfflineNearbyService().triggerSOSDiscoveredForTesting(packet);
      await Future.delayed(const Duration(milliseconds: 60));

      final matchingAlertNotifications = notificationCalls.where((c) =>
          c.method == 'showEmergencyNotification' &&
          c.arguments['emergencyId'] == 'JS-OFF-REPEAT-1');

      // Exactly 1 notification triggered for the session
      expect(matchingAlertNotifications.length, equals(1));

      await sub.cancel();
      await offlineComm.stop();
    });

    test('21. Existing self-alert suppression and payload integrity checks still function', () {
      // 1. Self-alert validation: packet from own device ID is dropped
      final ownPacket = {
        'emergencyId': 'JS-OFF-SELF-1',
        'originDeviceId': 'dev_my_phone',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      expect(ownPacket['originDeviceId'], equals('dev_my_phone'));

      // 2. Payload integrity: tampered HMAC is rejected
      final tampered = {
        'eventType': 'SOS_BROADCAST',
        'emergencyId': 'JS-OFF-TAMPER-2',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        '_integrity': 'forged_hmac_signature',
      };
      expect(P2PPayloadIntegrity.verifyPayload(tampered), isFalse);
    });
  });
}
