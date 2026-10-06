import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jan_sarthi/core/theme/app_theme.dart';
import 'package:jan_sarthi/models/emergency_model.dart';
import 'package:jan_sarthi/models/responder_model.dart';
import 'package:jan_sarthi/screens/history/emergency_history_screen.dart';
import 'package:jan_sarthi/screens/emergency/emergency_details_screen.dart';
import 'package:jan_sarthi/widgets/common/app_bottom_nav_bar.dart';
import 'package:jan_sarthi/widgets/common/app_status_badge.dart';

void main() {
  group('Vita ResQ Phase 4 — Emergency History Screen Redesign Tests', () {
    const testUserId = 'user_alpha';

    final testEmergencies = [
      EmergencyModel(
        id: 'EMG-SOS-1',
        victimId: testUserId,
        type: 'Medical',
        latitude: 28.6139,
        longitude: 77.2090,
        status: EmergencyStatus.COMPLETED,
        createdAt: DateTime(2026, 10, 5, 14, 30),
        updatedAt: DateTime(2026, 10, 5, 15, 0),
      ),
      EmergencyModel(
        id: 'JS-OFF-SOS-2',
        victimId: 'user_bravo',
        helperId: testUserId,
        type: 'Trauma',
        latitude: 28.5355,
        longitude: 77.3910,
        status: EmergencyStatus.ARRIVED,
        createdAt: DateTime(2026, 10, 6, 9, 15),
        updatedAt: DateTime(2026, 10, 6, 9, 45),
        responders: {
          testUserId: ResponderModel(
            userId: testUserId,
            userName: 'Alpha Volunteer',
            role: ResponderRole.PRIMARY,
            status: ResponderStatus.ARRIVED,
            latitude: 28.5355,
            longitude: 77.3910,
            acceptedAt: DateTime(2026, 10, 6, 9, 20),
            lastLocationUpdate: DateTime(2026, 10, 6, 9, 40),
          ),
        },
      ),
    ];

    testWidgets('4.1: Renders page header, two tabs, and AppBottomNavBar with History selected', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const EmergencyHistoryScreen(
            initialUserId: testUserId,
            initialEmergencies: [],
          ),
        ),
      );
      await tester.pump();

      // Header
      expect(find.text('Emergency History'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      // Two Views / Tabs
      expect(find.text('Help Asked'), findsOneWidget);
      expect(find.text('Victims Helped'), findsOneWidget);

      // Bottom Navigation locked with History selected (index 1)
      final bottomNavBarFinder = find.byType(AppBottomNavBar);
      expect(bottomNavBarFinder, findsOneWidget);
      final navBar = tester.widget<AppBottomNavBar>(bottomNavBarFinder);
      expect(navBar.currentIndex, 1);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('4.2: Empty states render human and useful messages for both tabs', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const EmergencyHistoryScreen(
            initialUserId: testUserId,
            initialEmergencies: [],
          ),
        ),
      );
      await tester.pump();

      // Help Asked Empty State
      expect(find.text('No SOS requests yet'), findsOneWidget);
      expect(find.text('Any emergency alerts you trigger will appear in this log.'), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsWidgets);

      // Switch to Victims Helped Tab
      await tester.tap(find.text('Victims Helped'));
      await tester.pumpAndSettle();

      // Victims Helped Empty State
      expect(find.text('No rescues yet'), findsOneWidget);
      expect(find.text('Emergencies where you respond and assist will appear here.'), findsOneWidget);
      expect(find.byIcon(Icons.volunteer_activism_outlined), findsWidgets);
    });

    testWidgets('4.3: Help Asked tab renders emergency cards with status badge, coordinates, and transport channel', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyHistoryScreen(
            initialUserId: testUserId,
            initialEmergencies: testEmergencies,
          ),
        ),
      );
      await tester.pump();

      // Card Content
      expect(find.text('Medical Emergency SOS'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.byType(AppStatusBadge), findsOneWidget);
      expect(find.textContaining('28.6139, 77.2090'), findsOneWidget);
      expect(find.text('Cloud Network'), findsOneWidget);
      expect(find.text('View Details'), findsOneWidget);
    });

    testWidgets('4.4: Victims Helped tab renders emergency cards with responder role and offline transport channel', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyHistoryScreen(
            initialUserId: testUserId,
            initialTabIndex: 1, // Start on Victims Helped
            initialEmergencies: testEmergencies,
          ),
        ),
      );
      await tester.pump();

      // Card Content in Victims Helped
      expect(find.text('Assisted in Trauma Emergency'), findsOneWidget);
      expect(find.text('Role: PRIMARY'), findsOneWidget);
      expect(find.text('ARRIVED'), findsOneWidget);
      expect(find.byType(AppStatusBadge), findsOneWidget);
      expect(find.textContaining('28.5355, 77.3910'), findsOneWidget);
      expect(find.text('Offline P2P'), findsOneWidget);
      expect(find.text('View Details'), findsOneWidget);
    });

    testWidgets('4.5: Tapping emergency item triggers navigation to emergency details flow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyHistoryScreen(
            initialUserId: testUserId,
            initialTabIndex: 1,
            initialEmergencies: testEmergencies,
          ),
        ),
      );
      await tester.pump();

      // Tap on the offline emergency card to navigate without remote Firebase dependency
      await tester.tap(find.text('Assisted in Trauma Emergency'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verifies navigation occurred to EmergencyDetailsScreen
      expect(find.byType(EmergencyDetailsScreen), findsOneWidget);
    });

    testWidgets('4.6: Compact Android viewport (360x640) renders without RenderFlex overflow in both tabs', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyHistoryScreen(
            initialUserId: testUserId,
            initialEmergencies: testEmergencies,
          ),
        ),
      );
      await tester.pump();

      // Verify no overflow in Tab 1
      expect(tester.takeException(), isNull);
      expect(find.text('Medical Emergency SOS'), findsOneWidget);

      // Switch to Tab 2
      await tester.tap(find.text('Victims Helped'));
      await tester.pumpAndSettle();

      // Verify no overflow in Tab 2
      expect(tester.takeException(), isNull);
      expect(find.text('Assisted in Trauma Emergency'), findsOneWidget);
    });
  });
}
