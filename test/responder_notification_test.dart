import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jan_sarthi/models/emergency_model.dart';
import 'package:jan_sarthi/services/notification_service.dart';
import 'package:jan_sarthi/services/offline_communication_service.dart';
import 'package:jan_sarthi/services/offline_nearby_service.dart';
import 'package:jan_sarthi/screens/emergency/emergency_details_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> methodChannelCalls = [];

  setUp(() {
    methodChannelCalls.clear();
    NotificationService.resetProcessedNotifications();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.example.jan_sarthi/notifications'),
      (MethodCall methodCall) async {
        methodChannelCalls.add(methodCall);
        if (methodCall.method == 'getLaunchEmergencyId') {
          return null;
        }
        return null;
      },
    );

    // Mock permissions channel to avoid hanging during test
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (MethodCall methodCall) async {
        return <int, int>{};
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.example.jan_sarthi/notifications'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      null,
    );
  });

  group('Responder Emergency Notifications — Online Alert Path', () {
    test('Creates online emergency notification with correct title, type and distance (<1000m)', () async {
      await NotificationService.showEmergencyAlertNotification(
        emergencyId: 'EM-ONLINE-001',
        type: 'CAR_ACCIDENT',
        distanceMeters: 450,
        isOffline: false,
      );

      expect(methodChannelCalls.length, 1);
      final call = methodChannelCalls.first;
      expect(call.method, 'showEmergencyNotification');
      expect(call.arguments['title'], 'Vita ResQ — Emergency Nearby');
      expect(call.arguments['body'], contains('CAR_ACCIDENT'));
      expect(call.arguments['body'], contains('450 m away'));
      expect(call.arguments['emergencyId'], 'EM-ONLINE-001');
      expect(call.arguments['id'], isA<int>());
    });

    test('Creates online emergency notification with distance in kilometers (>=1000m)', () async {
      await NotificationService.showEmergencyAlertNotification(
        emergencyId: 'EM-ONLINE-002',
        type: 'MEDICAL',
        distanceMeters: 2350,
        isOffline: false,
      );

      expect(methodChannelCalls.length, 1);
      final call = methodChannelCalls.first;
      expect(call.method, 'showEmergencyNotification');
      expect(call.arguments['title'], 'Vita ResQ — Emergency Nearby');
      expect(call.arguments['body'], contains('2.4 km away'));
      expect(call.arguments['emergencyId'], 'EM-ONLINE-002');
    });

    test('Deduplication prevents duplicate notification invocations for the same emergency', () async {
      await NotificationService.showEmergencyAlertNotification(
        emergencyId: 'EM-DUP-001',
        type: 'FIRE',
        distanceMeters: 300,
      );
      expect(methodChannelCalls.length, 1);

      // Second attempt with same ID should be suppressed
      await NotificationService.showEmergencyAlertNotification(
        emergencyId: 'EM-DUP-001',
        type: 'FIRE',
        distanceMeters: 300,
      );
      expect(methodChannelCalls.length, 1);
    });

    test('Closed and cancelled emergencies are rejected without triggering notification', () async {
      await NotificationService.showEmergencyAlertNotification(
        emergencyId: 'EM-CLOSED-001',
        type: 'MEDICAL',
        status: EmergencyStatus.COMPLETED,
      );
      expect(methodChannelCalls, isEmpty);

      await NotificationService.showEmergencyAlertNotification(
        emergencyId: 'EM-CLOSED-002',
        type: 'MEDICAL',
        status: EmergencyStatus.CANCELLED,
      );
      expect(methodChannelCalls, isEmpty);
    });

    test('Empty emergency ID is rejected without triggering notification', () async {
      await NotificationService.showEmergencyAlertNotification(
        emergencyId: '',
        type: 'MEDICAL',
      );
      expect(methodChannelCalls, isEmpty);
    });

    test('cancelEmergencyNotification invokes native cancel method with hashed ID', () async {
      await NotificationService.cancelEmergencyNotification('EM-CANCEL-001');

      expect(methodChannelCalls.length, 1);
      expect(methodChannelCalls.first.method, 'cancelEmergencyNotification');
      expect(methodChannelCalls.first.arguments['id'], 'EM-CANCEL-001'.hashCode & 0x7FFFFFFF);
    });
  });

  group('Responder Emergency Notifications — Offline P2P Alert Path', () {
    test('Creates offline P2P notification with distinctive offline badge in title', () async {
      await NotificationService.showEmergencyAlertNotification(
        emergencyId: 'JS-OFF-P2P-101',
        type: 'TRAUMA',
        distanceMeters: 120,
        isOffline: true,
      );

      expect(methodChannelCalls.length, 1);
      final call = methodChannelCalls.first;
      expect(call.method, 'showEmergencyNotification');
      expect(call.arguments['title'], 'Vita ResQ — Emergency Nearby (Offline P2P)');
      expect(call.arguments['body'], contains('TRAUMA'));
      expect(call.arguments['body'], contains('120 m away'));
      expect(call.arguments['emergencyId'], 'JS-OFF-P2P-101');
    });

    test('OfflineCommunicationService triggers notification when nearby SOS is discovered', () async {
      SharedPreferences.setMockInitialValues({});
      final offlineService = OfflineCommunicationService();

      final stream = offlineService.listenForAlerts(
        userLat: 28.6139,
        userLon: 77.2090,
        currentUserId: 'responder_user_1',
      );

      final subscription = stream.listen((_) {});

      // Trigger simulated SOS discovery via OfflineNearbyService testing hook
      OfflineNearbyService().triggerSOSDiscoveredForTesting({
        'emergencyId': 'JS-OFF-999',
        'victimId': 'victim_user_99',
        'type': 'MEDICAL',
        'latitude': 28.6145,
        'longitude': 77.2095,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await Future.delayed(const Duration(milliseconds: 50));

      expect(methodChannelCalls.isNotEmpty, isTrue);
      final call = methodChannelCalls.firstWhere(
        (c) => c.method == 'showEmergencyNotification' && c.arguments['emergencyId'] == 'JS-OFF-999',
      );
      expect(call.arguments['title'], contains('(Offline P2P)'));
      expect(call.arguments['body'], contains('MEDICAL'));

      await subscription.cancel();
    });

    test('OfflineCommunicationService ignores SOS if discovered event is from current user', () async {
      SharedPreferences.setMockInitialValues({});
      final offlineService = OfflineCommunicationService();

      final stream = offlineService.listenForAlerts(
        userLat: 28.6139,
        userLon: 77.2090,
        currentUserId: 'victim_self',
      );

      final subscription = stream.listen((_) {});

      // Simulate self SOS discovery
      OfflineNearbyService().triggerSOSDiscoveredForTesting({
        'emergencyId': 'JS-OFF-SELF-1',
        'victimId': 'victim_self',
        'type': 'MEDICAL',
        'latitude': 28.6140,
        'longitude': 77.2090,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await Future.delayed(const Duration(milliseconds: 50));

      final calls = methodChannelCalls.where(
        (c) => c.method == 'showEmergencyNotification' && c.arguments['emergencyId'] == 'JS-OFF-SELF-1',
      );
      expect(calls, isEmpty);

      await subscription.cancel();
    });
  });

  group('Responder Emergency Notifications — Navigation & Tap Routing', () {
    test('navigateToEmergency stores pendingEmergencyId when navigator is not yet mounted (cold-start)', () {
      NotificationService.pendingEmergencyId = null;
      final result = NotificationService.navigateToEmergency('EM-COLD-START-101');

      expect(result, isFalse);
      expect(NotificationService.pendingEmergencyId, 'EM-COLD-START-101');
    });

    test('navigateToEmergency gracefully handles empty or null input without crashing', () {
      NotificationService.pendingEmergencyId = null;
      final result = NotificationService.navigateToEmergency('');

      expect(result, isFalse);
      expect(NotificationService.pendingEmergencyId, isNull);
    });

    testWidgets('navigateToEmergency routes directly to EmergencyDetailsScreen when navigatorKey is mounted', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: NotificationService.navigatorKey,
          home: const Scaffold(body: Text('Home Screen')),
        ),
      );

      expect(find.text('Home Screen'), findsOneWidget);

      final navigated = NotificationService.navigateToEmergency('JS-OFF-MOUNTED-001');
      expect(navigated, isTrue);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // EmergencyDetailsScreen should now be on screen
      expect(find.byType(EmergencyDetailsScreen), findsOneWidget);
    });
  });

  group('Responder Emergency Notifications — EmergencyAlertPresentation Jargon-Free Formatting', () {
    test('Formats title calmly for SEARCHING, ASSIGNED, ARRIVED states', () {
      expect(
        EmergencyAlertPresentation.formatTitle(role: 'RESPONDER', status: EmergencyStatus.SEARCHING),
        'New emergency nearby',
      );
      expect(
        EmergencyAlertPresentation.formatTitle(role: 'RESPONDER', status: EmergencyStatus.ASSIGNED),
        "You're responding",
      );
      expect(
        EmergencyAlertPresentation.formatTitle(role: 'RESPONDER', status: EmergencyStatus.ARRIVED),
        "You've arrived",
      );
      expect(
        EmergencyAlertPresentation.formatTitle(role: 'VICTIM', status: EmergencyStatus.ASSIGNED),
        'Responder on the way',
      );
    });

    test('Formats body calmly without internal jargon', () {
      final body = EmergencyAlertPresentation.formatBody(
        role: 'RESPONDER',
        status: EmergencyStatus.SEARCHING,
      );
      expect(body, 'Someone nearby needs emergency assistance.');

      final completedBody = EmergencyAlertPresentation.formatBody(
        role: 'RESPONDER',
        status: EmergencyStatus.COMPLETED,
      );
      expect(completedBody, 'The emergency has been resolved safely.');
    });
  });
}
