import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jan_sarthi/core/theme/app_theme.dart';
import 'package:jan_sarthi/models/user_model.dart';
import 'package:jan_sarthi/widgets/app_drawer.dart';
import 'package:jan_sarthi/screens/safety/crash_detection_screen.dart';

void main() {
  group('Vita ResQ Phase 3 — Navigation Drawer Final Cleanup Tests', () {
    final mockUser = UserModel(
      id: 'test_uid_123',
      name: 'Aayon Patnaik',
      email: 'aayon@vita-resq.org',
      phoneNumber: '+919876543210',
      bloodGroup: 'O+',
      userRole: 'CITIZEN',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    testWidgets('4.1: Drawer renders compact identity header strictly omitting points, telemetry, and coords', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            drawer: AppDrawer(
              currentIndex: 0,
              userProfile: mockUser,
            ),
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open drawer
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Identity Header
      expect(find.text('Aayon Patnaik'), findsOneWidget);
      expect(find.text('Citizen Volunteer'), findsOneWidget);
      expect(find.text('AP'), findsOneWidget); // User initials in avatar

      // 2. Strict omission of stats, points, coordinates, and telemetry from header
      expect(find.textContaining('GPS:'), findsNothing);
      expect(find.textContaining('Coordinates'), findsNothing);
      expect(find.textContaining('±3m'), findsNothing);
      expect(find.textContaining('LVL'), findsNothing);
      expect(find.textContaining('Points'), findsNothing);
    });

    testWidgets('4.2: Drawer matches final minimal structure (omits bottom-nav tabs, Helplines, and Permissions)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            drawer: AppDrawer(
              currentIndex: 0,
              userProfile: mockUser,
            ),
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open drawer
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Bottom nav duplicates strictly REMOVED
      expect(find.text('MAIN'), findsNothing);
      expect(find.text('Home'), findsNothing);
      expect(find.text('Home & Emergency Radar'), findsNothing);
      expect(find.text('History'), findsNothing);
      expect(find.text('Emergency History'), findsNothing);
      expect(find.text('Profile'), findsNothing);

      // Cleaned up items strictly REMOVED
      expect(find.text('Emergency Helplines'), findsNothing);
      expect(find.text('Permissions'), findsNothing);

      // Exact Final Secondary Groups Present
      expect(find.text('EMERGENCY'), findsOneWidget);
      expect(find.text('Emergency Contacts'), findsOneWidget);

      expect(find.text('SAFETY'), findsOneWidget);
      expect(find.text('Crash Detection'), findsOneWidget);

      expect(find.text('IMPACT'), findsOneWidget);
      expect(find.text('Impact & Rewards'), findsOneWidget);
      expect(find.text('Certificates'), findsOneWidget);

      // Destructive Sign Out
      expect(find.text('Sign Out'), findsOneWidget);
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
    });

    testWidgets('4.3: Secondary drawer items trigger feature navigation cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            drawer: AppDrawer(
              currentIndex: 0,
              userProfile: mockUser,
            ),
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open drawer
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Crash Detection (navigates to dedicated CrashDetectionScreen)
      await tester.tap(find.text('Crash Detection'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CrashDetectionScreen), findsOneWidget);
    });

    testWidgets('4.4: Destructive Sign Out opens confirmation dialog before execution', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            drawer: AppDrawer(
              currentIndex: 0,
              userProfile: mockUser,
            ),
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open drawer
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Sign Out
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      // Verify confirmation dialog appeared
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Are you sure you want to sign out of Vita ResQ?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });
}
