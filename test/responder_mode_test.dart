import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

import 'package:jan_sarthi/models/emergency_model.dart';
import 'package:jan_sarthi/services/notification_service.dart';
import 'package:jan_sarthi/services/responder_mode_service.dart';
import 'package:jan_sarthi/screens/home/home_screen.dart';
import 'package:jan_sarthi/screens/emergency/emergency_details_screen.dart';
import 'package:jan_sarthi/core/theme/app_theme.dart';

EmergencyModel createMockEmergency({
  String id = 'EM-TEST-100',
  String victimId = 'victim_999',
  EmergencyStatus status = EmergencyStatus.SEARCHING,
  String type = 'MEDICAL',
  double latitude = 28.6139,
  double longitude = 77.2090,
  DateTime? createdAt,
}) {
  return EmergencyModel(
    id: id,
    victimId: victimId,
    type: type,
    latitude: latitude,
    longitude: longitude,
    status: status,
    createdAt: createdAt ?? DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> notificationMethodCalls = [];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    notificationMethodCalls.clear();
    NotificationService.resetProcessedNotifications();
    ResponderModeService.instance.resetProcessedEmergencyIds();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.example.jan_sarthi/notifications'),
      (MethodCall methodCall) async {
        notificationMethodCalls.add(methodCall);
        if (methodCall.method == 'isResponderForegroundServiceRunning') {
          return ResponderModeService.instance.isAvailable;
        }
        return true;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (MethodCall methodCall) async {
        return <int, int>{};
      },
    );
  });

  tearDown(() async {
    await ResponderModeService.instance.stopResponderMode();
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

  group('Vita ResQ — Responder Availability & Background Mode Tests', () {
    // ------------------------------------------------------------------------
    // 1. Responder mode starts
    // ------------------------------------------------------------------------
    test('1: Responder mode starts and invokes native foreground service', () async {
      final service = ResponderModeService.instance;
      expect(service.isAvailable, isFalse);

      bool started = await service.startResponderMode(
        latitude: 28.6139,
        longitude: 77.2090,
        userId: 'resp_user_001',
      );

      expect(started, isTrue);
      expect(service.isAvailable, isTrue);

      final startCall = notificationMethodCalls.firstWhere(
        (c) => c.method == 'startResponderForegroundService',
      );
      expect(startCall, isNotNull);
    });

    // ------------------------------------------------------------------------
    // 2. Responder mode stops
    // ------------------------------------------------------------------------
    test('2: Responder mode stops and cleans up native foreground service', () async {
      final service = ResponderModeService.instance;
      await service.startResponderMode(
        latitude: 28.6139,
        longitude: 77.2090,
        userId: 'resp_user_001',
      );
      expect(service.isAvailable, isTrue);

      await service.stopResponderMode();
      expect(service.isAvailable, isFalse);

      final stopCall = notificationMethodCalls.firstWhere(
        (c) => c.method == 'stopResponderForegroundService',
      );
      expect(stopCall, isNotNull);
    });

    // ------------------------------------------------------------------------
    // 3. Background emergency listener remains active while process is alive
    // ------------------------------------------------------------------------
    test('3: Availability stream broadcasts reactive state transitions', () async {
      final service = ResponderModeService.instance;
      final states = <bool>[];
      final sub = service.availabilityStream.listen((state) => states.add(state));

      await service.startResponderMode();
      await service.stopResponderMode();

      await sub.cancel();
      expect(states, [true, false]);
    });

    // ------------------------------------------------------------------------
    // 4. Emergency generates local notification
    // ------------------------------------------------------------------------
    test('4: Nearby emergency generates high-importance local notification', () async {
      final service = ResponderModeService.instance;
      await service.startResponderMode(userId: 'resp_user_001');

      final emergency = createMockEmergency(
        id: 'EM-ALERT-001',
        victimId: 'victim_123',
        status: EmergencyStatus.SEARCHING,
        type: 'ACCIDENT',
      );

      await service.handleEmergencyAlert(
        emergency,
        userLat: 28.6139,
        userLon: 77.2090,
        currentUserId: 'resp_user_001',
      );

      final alertCall = notificationMethodCalls.firstWhere(
        (c) => c.method == 'showEmergencyNotification',
      );
      expect(alertCall, isNotNull);
      expect(alertCall.arguments['emergencyId'], equals('EM-ALERT-001'));
      expect(alertCall.arguments['body'], contains('ACCIDENT'));
    });

    // ------------------------------------------------------------------------
    // 5. Notification contains correct emergencyId
    // ------------------------------------------------------------------------
    test('5: Local notification contains exact emergencyId in arguments', () async {
      final service = ResponderModeService.instance;
      await service.startResponderMode(userId: 'resp_user_001');

      final emergency = createMockEmergency(id: 'EM-EXACT-999');
      await service.handleEmergencyAlert(
        emergency,
        userLat: 28.6139,
        userLon: 77.2090,
        currentUserId: 'resp_user_001',
      );

      final alertCalls = notificationMethodCalls.where(
        (c) => c.method == 'showEmergencyNotification',
      );
      expect(alertCalls.length, equals(1));
      expect(alertCalls.first.arguments['emergencyId'], equals('EM-EXACT-999'));
    });

    // ------------------------------------------------------------------------
    // 6. Notification tap opens correct emergency
    // ------------------------------------------------------------------------
    testWidgets('6: Notification tap routes directly to EmergencyDetailsScreen with target emergencyId', (tester) async {
      final GlobalKey<NavigatorState> navKey = NotificationService.navigatorKey;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: Text('Home Base')),
        ),
      );
      await tester.pump();

      // Trigger navigation router directly
      final routed = NotificationService.navigateToEmergency('JS-OFF-NAV-777');
      expect(routed, isTrue);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(EmergencyDetailsScreen), findsOneWidget);
      final detailsWidget = tester.widget<EmergencyDetailsScreen>(find.byType(EmergencyDetailsScreen));
      expect(detailsWidget.emergencyId, equals('JS-OFF-NAV-777'));
    });

    // ------------------------------------------------------------------------
    // 7. Duplicate notification prevention
    // ------------------------------------------------------------------------
    test('7: Duplicate notifications for the same emergency are suppressed', () async {
      final service = ResponderModeService.instance;
      await service.startResponderMode(userId: 'resp_user_001');

      final emergency = createMockEmergency(id: 'EM-DUP-001');

      // First alert dispatch
      await service.handleEmergencyAlert(
        emergency,
        userLat: 28.6139,
        userLon: 77.2090,
        currentUserId: 'resp_user_001',
      );

      // Second alert dispatch for same emergency
      await service.handleEmergencyAlert(
        emergency,
        userLat: 28.6139,
        userLon: 77.2090,
        currentUserId: 'resp_user_001',
      );

      final alertCalls = notificationMethodCalls.where(
        (c) => c.method == 'showEmergencyNotification',
      );
      expect(alertCalls.length, equals(1)); // Strictly deduplicated to 1 call
    });

    // ------------------------------------------------------------------------
    // 8. Completed/cancelled emergency does not trigger new alert
    // ------------------------------------------------------------------------
    test('8: Completed and cancelled emergencies do not trigger actionable alerts', () async {
      final service = ResponderModeService.instance;
      await service.startResponderMode(userId: 'resp_user_001');

      final completedAlert = createMockEmergency(
        id: 'EM-COMPLETED-001',
        status: EmergencyStatus.COMPLETED,
      );
      final cancelledAlert = createMockEmergency(
        id: 'EM-CANCELLED-001',
        status: EmergencyStatus.CANCELLED,
      );

      await service.handleEmergencyAlert(
        completedAlert,
        userLat: 28.6139,
        userLon: 77.2090,
        currentUserId: 'resp_user_001',
      );

      await service.handleEmergencyAlert(
        cancelledAlert,
        userLat: 28.6139,
        userLon: 77.2090,
        currentUserId: 'resp_user_001',
      );

      final alertCalls = notificationMethodCalls.where(
        (c) => c.method == 'showEmergencyNotification',
      );
      expect(alertCalls.isEmpty, isTrue); // Zero alerts generated
    });

    // ------------------------------------------------------------------------
    // 9. Offline P2P emergency generates local notification
    // ------------------------------------------------------------------------
    test('9: Offline P2P emergency generates local notification with offline tag', () async {
      final service = ResponderModeService.instance;
      await service.startResponderMode(userId: 'resp_user_001');

      final offlineEmergency = createMockEmergency(
        id: 'JS-OFF-P2P-12345',
        type: 'MEDICAL',
      );

      await service.handleEmergencyAlert(
        offlineEmergency,
        userLat: 28.6139,
        userLon: 77.2090,
        currentUserId: 'resp_user_001',
      );

      final alertCall = notificationMethodCalls.firstWhere(
        (c) => c.method == 'showEmergencyNotification',
      );
      expect(alertCall, isNotNull);
      expect(alertCall.arguments['emergencyId'], equals('JS-OFF-P2P-12345'));
      expect(alertCall.arguments['title'], contains('Offline P2P'));
    });

    // ------------------------------------------------------------------------
    // 10. Responder-mode shutdown cleans up listeners correctly
    // ------------------------------------------------------------------------
    test('10: Responder-mode shutdown cleans up listeners and resets availability state', () async {
      final service = ResponderModeService.instance;
      await service.startResponderMode(userId: 'resp_user_001');
      expect(service.isAvailable, isTrue);

      await service.stopResponderMode();
      expect(service.isAvailable, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('key_responder_mode_active'), isFalse);
    });

    // ------------------------------------------------------------------------
    // Bonus UI: HomeScreen renders Responder Availability card and handles toggle
    // ------------------------------------------------------------------------
    testWidgets('Bonus: HomeScreen renders Responder Availability card and toggles mode', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testPosition = Position(
        latitude: 28.6139,
        longitude: 77.2090,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(initialPosition: testPosition),
        ),
      );
      await tester.pump();

      // Verify inactive card state
      expect(find.text('Responder Available'), findsOneWidget);
      expect(find.text('Go Available'), findsOneWidget);
      expect(find.text('Uses foreground service • Android 15 limits background dataSync to 6h per 24h'), findsOneWidget);

      // Tap Go Available
      await tester.ensureVisible(find.text('Go Available'));
      await tester.tap(find.text('Go Available'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify active card state
      expect(find.text('Responder mode active'), findsOneWidget);
      expect(find.text('Stop responding'), findsOneWidget);

      // Tap Stop responding
      await tester.ensureVisible(find.text('Stop responding'));
      await tester.tap(find.text('Stop responding'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Reverts to Go Available
      expect(find.text('Go Available'), findsOneWidget);
    });

    // ------------------------------------------------------------------------
    // 12. Android 15 timeout cleanly stops responder mode and resets state
    // ------------------------------------------------------------------------
    test('12: Android 15 timeout cleanly stops responder mode and resets state', () async {
      final service = ResponderModeService.instance;
      await service.startResponderMode(userId: 'resp_user_timeout');
      expect(service.isAvailable, isTrue);

      final states = <bool>[];
      final sub = service.availabilityStream.listen((state) => states.add(state));

      notificationMethodCalls.clear();
      await service.stopResponderMode(fromTimeout: true);

      expect(service.isAvailable, isFalse);
      expect(states, contains(false));

      // fromTimeout skips redundant stop call to native channel since Android stopped it
      final stopCalls = notificationMethodCalls.where(
        (c) => c.method == 'stopResponderForegroundService',
      );
      expect(stopCalls.isEmpty, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('key_responder_mode_active'), isFalse);
      await sub.cancel();
    });

    // ------------------------------------------------------------------------
    // 13. initialize() does not start foreground service if native service is inactive
    // ------------------------------------------------------------------------
    test('13: initialize() does not start foreground service if native service is inactive', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('key_responder_mode_active', true);

      final service = ResponderModeService.instance;
      notificationMethodCalls.clear();

      await service.initialize();

      expect(service.isAvailable, isFalse);
      expect(prefs.getBool('key_responder_mode_active'), isFalse);

      final startCalls = notificationMethodCalls.where(
        (c) => c.method == 'startResponderForegroundService',
      );
      expect(startCalls.isEmpty, isTrue);
    });
  });
}
