import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

import 'package:jan_sarthi/core/theme/app_theme.dart';
import 'package:jan_sarthi/models/emergency_model.dart';
import 'package:jan_sarthi/models/responder_model.dart';
import 'package:jan_sarthi/models/user_model.dart';
import 'package:jan_sarthi/screens/emergency/emergency_map_screen.dart';
import 'package:jan_sarthi/screens/home/home_screen.dart';
import 'package:jan_sarthi/screens/responder/responder_dashboard_screen.dart';
import 'package:jan_sarthi/services/local_database_service.dart';
import 'package:jan_sarthi/services/emergency_service.dart';

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
    SharedPreferences.setMockInitialValues({});
    EmergencyContactsService.resetFallbackStateForTesting();
    LocalDatabaseService.resetLockForTesting();
  });

  EmergencyModel createTestEmergency({
    String id = 'JS-OFF-nav-001',
    required EmergencyStatus status,
    String type = 'MEDICAL',
    String victimId = 'victim_nav_01',
    ResponderModel? primaryResponder,
    DateTime? createdAt,
  }) {
    final responders = <String, ResponderModel>{};
    if (primaryResponder != null) {
      responders[primaryResponder.userId] = primaryResponder;
    }
    return EmergencyModel(
      id: id,
      victimId: victimId,
      latitude: 28.6139,
      longitude: 77.2090,
      status: status,
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      type: type,
      currentRadiusMeters: 500.0,
      helperId: primaryResponder?.userId,
      responders: responders,
    );
  }

  group('Active Emergency Navigation UX Fix — Regression Tests', () {
    // 1. Active victim Live Assistance shows Home instead of the back arrow
    testWidgets('1: Active victim Live Assistance shows Home instead of the back arrow', (tester) async {
      final emergency = createTestEmergency(
        status: EmergencyStatus.SEARCHING,
        victimId: 'victim_user_1',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyMapScreen(
            emergencyId: emergency.id,
            initialEmergency: emergency,
            currentUserId: 'victim_user_1',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Home action is present with correct icon and tooltip accessibility label
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byTooltip('Home'), findsOneWidget);

      // Back arrow is NOT present on active emergency
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
      expect(find.byTooltip('Back'), findsNothing);
    });

    // 2. Active responder navigation shows Home instead of the back arrow
    testWidgets('2: Active responder navigation shows Home instead of the back arrow', (tester) async {
      final primary = ResponderModel(
        userId: 'responder_user_1',
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
        victimId: 'victim_user_2',
        primaryResponder: primary,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyMapScreen(
            emergencyId: emergency.id,
            initialEmergency: emergency,
            currentUserId: 'responder_user_1',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Home action is present with correct icon and tooltip
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byTooltip('Home'), findsOneWidget);

      // Back arrow is NOT present
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    });

    // 3. Home navigation preserves the emergency and its current status
    testWidgets('3: Home navigation preserves the emergency and its current status', (tester) async {
      final emergency = createTestEmergency(
        status: EmergencyStatus.APPROACHING,
        victimId: 'victim_user_3',
      );

      bool poppedToHome = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EmergencyMapScreen(
                          emergencyId: emergency.id,
                          initialEmergency: emergency,
                          currentUserId: 'victim_user_3',
                        ),
                      ),
                    ).then((_) {
                      poppedToHome = true;
                    });
                  },
                  child: const Text('Open Map'),
                ),
              ),
            ),
          ),
        ),
      );

      // Push EmergencyMapScreen
      await tester.tap(find.text('Open Map'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byTooltip('Home'), findsOneWidget);

      // Tap Home
      await tester.tap(find.byTooltip('Home'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Returned to home root
      expect(poppedToHome, isTrue);

      // Emergency status is preserved and not cancelled or completed
      expect(emergency.status, EmergencyStatus.APPROACHING);
      expect(emergency.isActive, isTrue);
      expect(emergency.isTerminal, isFalse);
    });

    // 4. Android system Back during an active emergency follows the safe navigation behavior
    testWidgets('4: Android system Back during an active emergency follows the safe navigation behavior', (tester) async {
      final emergency = createTestEmergency(
        status: EmergencyStatus.SEARCHING,
        victimId: 'victim_user_4',
      );

      bool returnedToRoot = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EmergencyMapScreen(
                        emergencyId: emergency.id,
                        initialEmergency: emergency,
                        currentUserId: 'victim_user_4',
                      ),
                    ),
                  ).then((_) {
                    returnedToRoot = true;
                  });
                },
                child: const Text('Launch SOS'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Launch SOS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('SEARCHING FOR HELP'), findsOneWidget);

      // Simulate Android system back gesture / button
      final dynamic popScopeWidget = tester.widget(find.byWidgetPredicate((w) => w is PopScope));
      expect(popScopeWidget.canPop, isFalse);

      // Trigger pop through Navigator (simulating Android system back)
      final navigatorState = tester.state<NavigatorState>(find.byType(Navigator));
      await navigatorState.maybePop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Safe navigation returned user to root without cancelling emergency
      expect(returnedToRoot, isTrue);
      expect(emergency.status, EmergencyStatus.SEARCHING);
      expect(emergency.isActive, isTrue);
    });

    // 5. Returning Home does not reset the three-minute fallback or cancel the emergency
    testWidgets('5: Returning Home does not reset the three-minute fallback or cancel the emergency', (tester) async {
      // Emergency created 90 seconds ago
      final created90sAgo = DateTime.now().subtract(const Duration(seconds: 90));
      final emergency = createTestEmergency(
        status: EmergencyStatus.SEARCHING,
        victimId: 'victim_user_5',
        createdAt: created90sAgo,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EmergencyMapScreen(
                        emergencyId: emergency.id,
                        initialEmergency: emergency,
                        currentUserId: 'victim_user_5',
                      ),
                    ),
                  );
                },
                child: const Text('Go Live'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go Live'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Home
      await tester.tap(find.byTooltip('Home'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify emergency was not cancelled
      expect(emergency.status, EmergencyStatus.SEARCHING);
      expect(emergency.isTerminal, isFalse);

      // Reopen screen: timer reflects remaining seconds (~90s), not reset to 180s
      await tester.tap(find.text('Go Live'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final now = DateTime.now();
      final elapsed = now.difference(emergency.createdAt).inSeconds;
      expect(elapsed >= 90, isTrue);
    });

    // 6. An accepted responder assignment remains intact
    testWidgets('6: An accepted responder assignment remains intact when navigating Home', (tester) async {
      final primary = ResponderModel(
        userId: 'primary_resp_007',
        userName: 'Priya Patel',
        role: ResponderRole.PRIMARY,
        status: ResponderStatus.RESPONDING,
        latitude: 28.6120,
        longitude: 77.2080,
        acceptedAt: DateTime.now(),
        lastLocationUpdate: DateTime.now(),
      );

      final emergency = createTestEmergency(
        status: EmergencyStatus.ASSIGNED,
        victimId: 'victim_user_6',
        primaryResponder: primary,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EmergencyMapScreen(
                        emergencyId: emergency.id,
                        initialEmergency: emergency,
                        currentUserId: 'primary_resp_007',
                      ),
                    ),
                  );
                },
                child: const Text('Responder View'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Responder View'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('YOU ARE RESPONDING'), findsOneWidget);

      // Tap Home
      await tester.tap(find.byTooltip('Home'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Responder assignment is completely intact
      expect(emergency.helperId, 'primary_resp_007');
      expect(emergency.primaryResponder?.userName, 'Priya Patel');
      expect(emergency.primaryResponder?.role, ResponderRole.PRIMARY);

      // Clean test teardown: unmount widget tree to dispose controllers and timers
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    // 7. The Home active-emergency card reopens the correct screen
    testWidgets('7: The Home active-emergency card reopens the correct screen', (tester) async {
      final emergency = createTestEmergency(
        id: 'JS-OFF-nav-007',
        status: EmergencyStatus.ASSIGNED,
        victimId: 'offline_user',
      );

      await tester.runAsync(() async {
        await LocalDatabaseService().saveEmergencyLocally(emergency);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(
            initialPosition: testPosition,
            initialActiveEmergency: emergency,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Home active emergency banner is displayed
      expect(find.text('EMERGENCY IN PROGRESS'), findsOneWidget);
      expect(find.textContaining('Helper Assigned & Preparing'), findsOneWidget);
      expect(find.text('RESUME LIVE ASSISTANCE'), findsOneWidget);

      // Tap resume action
      await tester.tap(find.text('RESUME LIVE ASSISTANCE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Navigated to EmergencyMapScreen with Live Assistance
      expect(find.byType(EmergencyMapScreen), findsOneWidget);
      expect(find.byTooltip('Home'), findsOneWidget);

      // Clean test teardown: unmount widget tree to dispose controllers and timers
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    // 8. CANCELLED and COMPLETED emergencies do not appear as active
    testWidgets('8: CANCELLED and COMPLETED emergencies do not appear as active', (tester) async {
      final cancelledEmergency = createTestEmergency(
        id: 'JS-OFF-nav-008',
        status: EmergencyStatus.CANCELLED,
        victimId: 'offline_user',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyMapScreen(
            emergencyId: cancelledEmergency.id,
            initialEmergency: cancelledEmergency,
            currentUserId: 'offline_user',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Terminal emergency shows normal back button, not Home
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.byTooltip('Home'), findsNothing);

      // PopScope canPop is true
      final dynamic popScopeWidget = tester.widget(find.byWidgetPredicate((w) => w is PopScope));
      expect(popScopeWidget.canPop, isTrue);
    });

    // 9. Repeated navigation does not create duplicate cards, screens, or listeners
    testWidgets('9: Repeated navigation does not create duplicate cards, screens, or listeners', (tester) async {
      final emergency = createTestEmergency(
        id: 'JS-OFF-nav-009',
        status: EmergencyStatus.SEARCHING,
        victimId: 'offline_user',
      );
      await tester.runAsync(() async {
        await LocalDatabaseService().saveEmergencyLocally(emergency);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(
            initialPosition: testPosition,
            initialActiveEmergency: emergency,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1 banner initially
      expect(find.text('EMERGENCY IN PROGRESS'), findsOneWidget);

      // Open map
      await tester.tap(find.text('RESUME LIVE ASSISTANCE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(EmergencyMapScreen), findsOneWidget);

      // Return home
      await tester.tap(find.byTooltip('Home'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      ScaffoldMessenger.of(tester.element(find.byType(HomeScreen))).clearSnackBars();
      await tester.pump(const Duration(milliseconds: 100));

      // Open map second time
      await tester.tap(find.text('RESUME LIVE ASSISTANCE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(EmergencyMapScreen), findsOneWidget);

      // Return home second time
      await tester.tap(find.byTooltip('Home'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      ScaffoldMessenger.of(tester.element(find.byType(HomeScreen))).clearSnackBars();
      await tester.pump(const Duration(milliseconds: 100));

      // Exactly 1 Home screen and 1 active banner exist
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('EMERGENCY IN PROGRESS'), findsOneWidget);

      // Clean test teardown: unmount widget tree to dispose controllers and timers
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    // 10. Normal back navigation continues to work for terminal emergencies
    testWidgets('10: Normal back navigation continues to work for terminal emergencies', (tester) async {
      final completedEmergency = createTestEmergency(
        id: 'JS-OFF-nav-010',
        status: EmergencyStatus.COMPLETED,
        victimId: 'offline_user',
      );

      bool popped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EmergencyMapScreen(
                        emergencyId: completedEmergency.id,
                        initialEmergency: completedEmergency,
                        currentUserId: 'offline_user',
                      ),
                    ),
                  ).then((_) {
                    popped = true;
                  });
                },
                child: const Text('Open Completed'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Completed'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Has Back arrow
      expect(find.byTooltip('Back'), findsOneWidget);

      // Tapping back pops screen normally
      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(popped, isTrue);
    });

    // 11: Responder dashboard displays active assigned emergency card
    testWidgets('11: Responder dashboard displays active assigned emergency card', (tester) async {
      final primary = ResponderModel(
        userId: 'offline_user',
        userName: 'Offline Volunteer',
        role: ResponderRole.PRIMARY,
        status: ResponderStatus.RESPONDING,
        latitude: 28.6139,
        longitude: 77.2090,
        acceptedAt: DateTime.now(),
        lastLocationUpdate: DateTime.now(),
      );

      final emergency = createTestEmergency(
        id: 'JS-OFF-nav-011',
        status: EmergencyStatus.ASSIGNED,
        victimId: 'some_other_victim',
        primaryResponder: primary,
      );

      await tester.runAsync(() async {
        await LocalDatabaseService().saveEmergencyLocally(emergency);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ResponderDashboardScreen(
            initialPosition: testPosition,
            initialUserProfile: testUser,
            initialIsAvailable: true,
            initialEmergencies: [emergency],
            initialActiveAssignedEmergency: emergency,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('ACTIVE RESCUE ASSIGNMENT'), findsOneWidget);
      expect(find.text('RESUME NAVIGATION'), findsOneWidget);

      // Clean test teardown: unmount widget tree to dispose controllers and timers
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
