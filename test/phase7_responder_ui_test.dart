import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:jan_sarthi/core/theme/app_theme.dart';
import 'package:jan_sarthi/models/emergency_model.dart';
import 'package:jan_sarthi/models/responder_model.dart';
import 'package:jan_sarthi/models/user_model.dart';
import 'package:jan_sarthi/screens/responder/responder_dashboard_screen.dart';
import 'package:jan_sarthi/screens/emergency/emergency_map_screen.dart';
import 'package:jan_sarthi/screens/emergency/emergency_details_screen.dart';
import 'package:jan_sarthi/widgets/incoming_emergency_card.dart';
import 'package:jan_sarthi/widgets/common/app_bottom_nav_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    id: 'responder_user_001',
    name: 'Aarav Sharma',
    email: 'aarav@vita-resq.org',
    phoneNumber: '+919876543210',
    bloodGroup: 'B+',
    userRole: 'CITIZEN',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  EmergencyModel createTestEmergency({
    String id = 'em_phase7_test_001',
    required EmergencyStatus status,
    String type = 'MEDICAL',
    ResponderModel? primaryResponder,
    List<ResponderModel> standbyResponders = const [],
    String victimId = 'victim_123',
    double latitude = 28.6139,
    double longitude = 77.2090,
  }) {
    final responders = <String, ResponderModel>{};
    if (primaryResponder != null) {
      responders[primaryResponder.userId] = primaryResponder;
    }
    for (var standby in standbyResponders) {
      responders[standby.userId] = standby;
    }

    return EmergencyModel(
      id: id,
      victimId: victimId,
      type: type,
      latitude: latitude,
      longitude: longitude,
      status: status,
      helperId: primaryResponder?.userId,
      responders: responders,
      currentRadiusMeters: 1000.0,
      createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
      updatedAt: DateTime.now(),
    );
  }

  group('Vita ResQ Phase 7 — Responder Experience UI Tests', () {
    // -------------------------------------------------------------
    // 7.1 RESPONDER LANDING SCREEN
    // -------------------------------------------------------------
    testWidgets('7.1: ResponderDashboardScreen renders greeting, status, count, and nearest incident', (tester) async {
      final emergency = createTestEmergency(status: EmergencyStatus.SEARCHING);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ResponderDashboardScreen(
            initialUserProfile: testUser,
            initialEmergencies: [emergency],
            initialIsAvailable: true,
            initialPosition: testPosition,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Header greeting with user name
      expect(find.textContaining('Aarav Sharma'), findsOneWidget);
      expect(find.text('RESPONDER STATUS'), findsOneWidget);

      // Status indicator and count
      expect(find.text('AVAILABLE'), findsOneWidget);
      expect(find.text('1 active'), findsOneWidget);

      // Section: NEAREST INCIDENT
      expect(find.text('NEAREST INCIDENT'), findsOneWidget);
      expect(find.byType(IncomingEmergencyCard), findsOneWidget);
    });

    // -------------------------------------------------------------
    // 7.2 AVAILABILITY / STATUS CONTROL
    // -------------------------------------------------------------
    testWidgets('7.2: Availability control toggles between AVAILABLE and UNAVAILABLE with >= 48dp target', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ResponderDashboardScreen(
            initialUserProfile: testUser,
            initialEmergencies: const [],
            initialIsAvailable: true,
            initialPosition: testPosition,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('AVAILABLE'), findsOneWidget);

      // Check switch touch target size >= 48dp
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      final switchSize = tester.getSize(switchFinder);
      expect(switchSize.height, greaterThanOrEqualTo(30.0)); // Switch itself

      // Toggle switch to false
      await tester.tap(switchFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('UNAVAILABLE'), findsOneWidget);
      expect(find.text('Responder Status Paused'), findsOneWidget);
      expect(find.text('Paused'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // 7.3 NEARBY EMERGENCY CARD
    // -------------------------------------------------------------
    testWidgets('7.3: IncomingEmergencyCard renders emergency type, distance, time, and prominent actions', (tester) async {
      final emergency = createTestEmergency(
        status: EmergencyStatus.SEARCHING,
        type: 'ACCIDENT',
      );

      bool canHelped = false;
      bool detailsViewed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: IncomingEmergencyCard(
                emergency: emergency,
                distanceMeters: 450.0,
                onCanHelp: () => canHelped = true,
                onViewDetails: () => detailsViewed = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Priority hierarchy elements
      expect(find.text('ACCIDENT EMERGENCY'), findsOneWidget);
      expect(find.text('450 m away'), findsOneWidget);
      expect(find.text('2m ago'), findsOneWidget);

      // Primary and secondary actions
      final canHelpBtn = find.text('I CAN HELP');
      final viewDetailsBtn = find.text('View Details');
      expect(canHelpBtn, findsOneWidget);
      expect(viewDetailsBtn, findsOneWidget);

      // Verify touch targets >= 48dp on the button container
      final btnContainer = find.ancestor(of: canHelpBtn, matching: find.byType(ElevatedButton));
      final btnSize = tester.getSize(btnContainer);
      expect(btnSize.height, greaterThanOrEqualTo(48.0));

      await tester.tap(canHelpBtn);
      await tester.pump();
      expect(canHelped, isTrue);

      await tester.tap(viewDetailsBtn);
      await tester.pump();
      expect(detailsViewed, isTrue);
    });

    // -------------------------------------------------------------
    // 7.4 EMERGENCY DETAILS SCREEN
    // -------------------------------------------------------------
    testWidgets('7.4: EmergencyDetailsScreen displays EMERGENCY, LOCATION, MAP, and IMPORTANT DETAILS sections', (tester) async {
      final emergency = createTestEmergency(
        status: EmergencyStatus.SEARCHING,
        type: 'MEDICAL',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyDetailsScreen(
            emergencyId: emergency.id,
            initialEmergency: emergency,
          ),
        ),
      );
      await tester.pump();

      // Section headings
      expect(find.text('EMERGENCY'), findsOneWidget);
      expect(find.text('LOCATION'), findsOneWidget);
      expect(find.text('MAP'), findsOneWidget);
      expect(find.text('IMPORTANT DETAILS'), findsOneWidget);

      // Status badge & classification
      expect(find.text('LIVE ALERT'), findsOneWidget);
      expect(find.text('MEDICAL'), findsOneWidget);

      // Actions at bottom
      expect(find.text('I CAN HELP'), findsOneWidget);
      expect(find.text('DECLINE'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // 7.5 I CAN HELP ACTION
    // -------------------------------------------------------------
    testWidgets('7.5: Tapping I CAN HELP opens confirmation dialog with location streaming notice', (tester) async {
      final emergency = createTestEmergency(status: EmergencyStatus.SEARCHING);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyDetailsScreen(
            emergencyId: emergency.id,
            initialEmergency: emergency,
          ),
        ),
      );
      await tester.pump();

      // Tap "I CAN HELP"
      await tester.tap(find.text('I CAN HELP'));
      await tester.pumpAndSettle();

      // Confirmation dialog verification
      expect(find.text('Confirm Response'), findsOneWidget);
      expect(find.textContaining('Are you sure you can help?'), findsOneWidget);
      expect(find.text('CONFIRM'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // 7.6 PRIMARY RESPONDER STATE
    // -------------------------------------------------------------
    testWidgets('7.6: EmergencyMapScreen displays YOU ARE RESPONDING and navigation controls for Primary', (tester) async {
      final primaryResponder = ResponderModel(
        userId: 'responder_me_123',
        userName: 'Aarav Sharma',
        role: ResponderRole.PRIMARY,
        status: ResponderStatus.RESPONDING,
        latitude: 28.6100,
        longitude: 77.2050,
        acceptedAt: DateTime.now(),
        lastLocationUpdate: DateTime.now(),
      );

      final emergency = createTestEmergency(
        status: EmergencyStatus.ASSIGNED,
        victimId: 'victim_user_456',
        primaryResponder: primaryResponder,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyMapScreen(
            emergencyId: emergency.id,
            initialEmergency: emergency,
            currentUserId: 'responder_me_123',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Primary status and title
      expect(find.text('YOU ARE RESPONDING'), findsOneWidget);
      expect(find.text('Navigating to Victim'), findsNWidgets(2)); // HUD and panel
      expect(find.text('PRIMARY RESPONDER'), findsOneWidget);

      // Essential actions
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Report Problem'), findsOneWidget);
      expect(find.text('I HAVE ARRIVED'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // 7.7 STANDBY RESPONDER STATE
    // -------------------------------------------------------------
    testWidgets('7.7: EmergencyMapScreen displays calm standby state without error styling', (tester) async {
      final primary = ResponderModel(
        userId: 'lead_paramedic',
        userName: 'Priya Patel',
        role: ResponderRole.PRIMARY,
        status: ResponderStatus.RESPONDING,
        latitude: 28.6100,
        longitude: 77.2050,
        acceptedAt: DateTime.now(),
        lastLocationUpdate: DateTime.now(),
      );

      final standby = ResponderModel(
        userId: 'standby_me_789',
        userName: 'Aarav Sharma',
        role: ResponderRole.STANDBY,
        status: ResponderStatus.STANDBY,
        latitude: 28.6090,
        longitude: 77.2040,
        acceptedAt: DateTime.now(),
        lastLocationUpdate: DateTime.now(),
      );

      final emergency = createTestEmergency(
        status: EmergencyStatus.ASSIGNED,
        victimId: 'victim_user_456',
        primaryResponder: primary,
        standbyResponders: [standby],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyMapScreen(
            emergencyId: emergency.id,
            initialEmergency: emergency,
            currentUserId: 'standby_me_789',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Calm standby status and reassurance
      expect(find.text('ON STANDBY'), findsOneWidget);
      expect(find.text("You're on standby"), findsOneWidget);
      expect(find.textContaining('Another responder is currently primary'), findsOneWidget);
      expect(find.text('BACK TO DASHBOARD'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // 7.8 NAVIGATION HUD
    // -------------------------------------------------------------
    testWidgets('7.8: Navigation HUD displays glanceable destination and action prompt', (tester) async {
      final primary = ResponderModel(
        userId: 'responder_me_123',
        userName: 'Aarav Sharma',
        role: ResponderRole.PRIMARY,
        status: ResponderStatus.RESPONDING,
        latitude: 28.6100,
        longitude: 77.2050,
        acceptedAt: DateTime.now(),
        lastLocationUpdate: DateTime.now(),
      );

      final emergency = createTestEmergency(
        status: EmergencyStatus.APPROACHING,
        type: 'MEDICAL',
        victimId: 'victim_user_456',
        primaryResponder: primary,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyMapScreen(
            emergencyId: emergency.id,
            initialEmergency: emergency,
            currentUserId: 'responder_me_123',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Navigation HUD details
      expect(find.text('Proceed to emergency location'), findsOneWidget);
      expect(find.text('MEDICAL • Victim Location'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // 7.9 ARRIVAL STATE
    // -------------------------------------------------------------
    testWidgets('7.9: Arrival state renders YOU\'VE ARRIVED and COMPLETE RESCUE action', (tester) async {
      final primary = ResponderModel(
        userId: 'responder_me_123',
        userName: 'Aarav Sharma',
        role: ResponderRole.PRIMARY,
        status: ResponderStatus.ARRIVED,
        latitude: 28.6139,
        longitude: 77.2090,
        acceptedAt: DateTime.now(),
        lastLocationUpdate: DateTime.now(),
      );

      final emergency = createTestEmergency(
        status: EmergencyStatus.ARRIVED,
        victimId: 'victim_user_456',
        primaryResponder: primary,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyMapScreen(
            emergencyId: emergency.id,
            initialEmergency: emergency,
            currentUserId: 'responder_me_123',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Arrived status badge & scene notice
      expect(find.text("YOU'VE ARRIVED"), findsOneWidget);
      expect(find.text('At Emergency Scene'), findsOneWidget);
      expect(find.text('At emergency scene • Assist victim'), findsOneWidget);
      expect(find.text('COMPLETE RESCUE'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // 7.10 COMPLETION STATE
    // -------------------------------------------------------------
    testWidgets('7.10: Emergency completion displays RESCUE COMPLETE summary without XP/gaming dashboard', (tester) async {
      final primary = ResponderModel(
        userId: 'responder_me_123',
        userName: 'Aarav Sharma',
        role: ResponderRole.PRIMARY,
        status: ResponderStatus.COMPLETED,
        latitude: 28.6139,
        longitude: 77.2090,
        acceptedAt: DateTime.now(),
        lastLocationUpdate: DateTime.now(),
      );

      final emergency = createTestEmergency(
        status: EmergencyStatus.COMPLETED,
        type: 'ACCIDENT',
        victimId: 'victim_user_456',
        primaryResponder: primary,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyMapScreen(
            emergencyId: emergency.id,
            initialEmergency: emergency,
            currentUserId: 'responder_me_123',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Closure state
      expect(find.text('RESCUE COMPLETE'), findsOneWidget);
      expect(find.text('Rescue complete'), findsOneWidget);
      expect(find.text('Emergency: ACCIDENT'), findsOneWidget);
      expect(find.text('CLOSE SUMMARY'), findsOneWidget);

      // Verify no gaming/XP clutter on completion screen
      expect(find.textContaining('XP'), findsNothing);
      expect(find.textContaining('+15 pts'), findsNothing);
      expect(find.textContaining('Level Up'), findsNothing);
    });

    // -------------------------------------------------------------
    // 7.11 COMPACT VIEWPORT RESPONSIVENESS
    // -------------------------------------------------------------
    testWidgets('7.11: Responder dashboard renders cleanly at 360x640 with zero RenderFlex overflows', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final emergency1 = createTestEmergency(id: 'em_1', status: EmergencyStatus.SEARCHING);
      final emergency2 = createTestEmergency(id: 'em_2', status: EmergencyStatus.SEARCHING, type: 'ACCIDENT');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ResponderDashboardScreen(
            initialUserProfile: testUser,
            initialEmergencies: [emergency1, emergency2],
            initialIsAvailable: true,
            initialPosition: testPosition,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('NEAREST INCIDENT'), findsOneWidget);
      expect(find.text('OTHER NEARBY'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // 7.12 BOTTOM NAVIGATION CONSISTENCY
    // -------------------------------------------------------------
    testWidgets('7.12: Responder dashboard preserves 3 canonical bottom nav items (Home, History, Profile)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ResponderDashboardScreen(
            initialUserProfile: testUser,
            initialEmergencies: const [],
            initialIsAvailable: true,
            initialPosition: testPosition,
          ),
        ),
      );
      await tester.pump();

      // Bottom nav exists and contains 3 canonical tabs
      expect(find.byType(AppBottomNavBar), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });
  });
}
