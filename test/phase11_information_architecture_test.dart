import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jan_sarthi/core/theme/app_theme.dart';
import 'package:jan_sarthi/models/user_model.dart';
import 'package:jan_sarthi/models/impact_model.dart';
import 'package:jan_sarthi/screens/profile/profile_screen.dart';
import 'package:jan_sarthi/widgets/app_drawer.dart';
import 'package:jan_sarthi/screens/emergency_contacts/emergency_contacts_screen.dart';
import 'package:jan_sarthi/screens/safety/crash_detection_screen.dart';
import 'package:jan_sarthi/screens/impact/impact_rewards_screen.dart';
import 'package:jan_sarthi/screens/impact/certificates_screen.dart';
import 'package:jan_sarthi/screens/demo/accident_detection_demo_screen.dart';

void main() {
  group('Vita ResQ Phase 11 — Information Architecture Tests', () {
    final testUser = UserModel(
      id: 'usr_alpha_99',
      name: 'Marcus Vance',
      email: 'marcus.vance@example.com',
      phoneNumber: '+91 98765 43210',
      bloodGroup: 'O+',
      userRole: 'CITIZEN',
      vehicleNumber: 'DL-01-AB-1234',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      impactProfile: const UserImpactProfile(
        impactPoints: 320,
        verifiedAssists: 8,
        victimsReached: 8,
        totalAccepted: 10,
        unlockedBadgeIds: ['first_response', 'reliable_shield'],
      ),
    );

    testWidgets('11.1: Profile contains personal/account information only', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ProfileScreen(
            initialUserProfile: testUser,
          ),
        ),
      );
      await tester.pump();

      // Identity Header
      expect(find.text('Marcus Vance'), findsOneWidget);
      expect(find.text('marcus.vance@example.com'), findsOneWidget);
      expect(find.text('Citizen Volunteer'), findsOneWidget);

      // Account Information
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('+91 98765 43210'), findsWidgets);
      expect(find.text('Blood Group'), findsOneWidget);
      expect(find.text('Edit Profile & Role'), findsOneWidget);

      // Account Action
      expect(find.text('ACCOUNT ACTIONS'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('11.2: Profile does not contain Impact & Rewards', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ProfileScreen(
            initialUserProfile: testUser,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Impact & Rewards'), findsNothing);
      expect(find.text('CIVIC BADGES & HONORS'), findsNothing);
      expect(find.text('Reliability Score'), findsNothing);
      expect(find.textContaining('Impact Pts'), findsNothing);
      expect(find.textContaining('XP'), findsNothing);
      expect(find.textContaining('Verified Assists'), findsNothing);
    });

    testWidgets('11.3: Profile does not contain Crash Detection', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ProfileScreen(
            initialUserProfile: testUser,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Crash Detection'), findsNothing);
      expect(find.text('Automatic Crash Detection'), findsNothing);
      expect(find.textContaining('Accident Detection'), findsNothing);
      expect(find.textContaining('Crash Sensitivity'), findsNothing);
      expect(find.text('SAFETY'), findsNothing);
    });

    testWidgets('11.4: Profile does not contain Emergency Contacts', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ProfileScreen(
            initialUserProfile: testUser,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Emergency Contacts'), findsNothing);
      expect(find.text('Add Emergency Contact'), findsNothing);
      expect(find.text('Dispatch Test SMS'), findsNothing);
      expect(find.text('EMERGENCY'), findsNothing);
    });

    Widget buildDrawerApp({UserModel? user}) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          drawer: AppDrawer(
            currentIndex: 0,
            userProfile: user ?? testUser,
          ),
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              child: const Text('Open Drawer'),
            ),
          ),
        ),
      );
    }

    testWidgets('11.5: Drawer contains Emergency Contacts', (tester) async {
      await tester.pumpWidget(buildDrawerApp());
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      expect(find.text('EMERGENCY'), findsOneWidget);
      expect(find.text('Emergency Contacts'), findsOneWidget);
    });

    testWidgets('11.6: Drawer contains Crash Detection', (tester) async {
      await tester.pumpWidget(buildDrawerApp());
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      expect(find.text('SAFETY'), findsOneWidget);
      expect(find.text('Crash Detection'), findsOneWidget);
    });

    testWidgets('11.7: Drawer contains Impact & Rewards', (tester) async {
      await tester.pumpWidget(buildDrawerApp());
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      expect(find.text('IMPACT'), findsOneWidget);
      expect(find.text('Impact & Rewards'), findsOneWidget);
    });

    testWidgets('11.8: Drawer contains Certificates', (tester) async {
      await tester.pumpWidget(buildDrawerApp());
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      expect(find.text('Certificates'), findsOneWidget);
    });

    testWidgets('11.9: Drawer contains Accident Detection Demo', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildDrawerApp());
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Accident Detection Demo'), 100);
      expect(find.text('DEMO / JUDGE'), findsOneWidget);
      expect(find.text('Accident Detection Demo'), findsOneWidget);
    });

    testWidgets('11.10: Drawer does not duplicate Home/History/Profile', (tester) async {
      await tester.pumpWidget(buildDrawerApp());
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      expect(find.text('MAIN'), findsNothing);
      expect(find.text('Home'), findsNothing);
      expect(find.text('Home & Emergency Radar'), findsNothing);
      expect(find.text('History'), findsNothing);
      expect(find.text('Emergency History'), findsNothing);
      expect(find.text('Profile'), findsNothing);
    });

    testWidgets('11.11: Each drawer feature navigates to its dedicated page', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildDrawerApp());

      // 1. Emergency Contacts navigation
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Emergency Contacts'));
      await tester.pumpAndSettle();
      expect(find.byType(EmergencyContactsScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(EmergencyContactsScreen))).pop();
      await tester.pumpAndSettle();

      // 2. Crash Detection navigation
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crash Detection'));
      await tester.pumpAndSettle();
      expect(find.byType(CrashDetectionScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(CrashDetectionScreen))).pop();
      await tester.pumpAndSettle();

      // 3. Impact & Rewards navigation
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Impact & Rewards'));
      await tester.pumpAndSettle();
      expect(find.byType(ImpactRewardsScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(ImpactRewardsScreen))).pop();
      await tester.pumpAndSettle();

      // 4. Certificates navigation
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Certificates'));
      await tester.pumpAndSettle();
      expect(find.byType(CertificatesScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(CertificatesScreen))).pop();
      await tester.pumpAndSettle();

      // 5. Accident Detection Demo navigation
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Accident Detection Demo'), 100);
      await tester.tap(find.text('Accident Detection Demo'));
      await tester.pumpAndSettle();
      expect(find.byType(AccidentDetectionDemoScreen), findsOneWidget);
    });

    testWidgets('11.12: Compact viewport has zero overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 1. Profile on compact viewport
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ProfileScreen(initialUserProfile: testUser),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 2. Drawer on compact viewport
      await tester.pumpWidget(buildDrawerApp());
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 3. Emergency Contacts on compact viewport
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const EmergencyContactsScreen(initialContacts: []),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 4. Crash Detection on compact viewport
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CrashDetectionScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 5. Impact & Rewards on compact viewport
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ImpactRewardsScreen(initialImpactProfile: testUser.impactProfile),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 6. Certificates on compact viewport
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: CertificatesScreen(
            initialImpactProfile: testUser.impactProfile,
            initialUserName: 'Marcus Vance',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 7. Accident Demo on compact viewport
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AccidentDetectionDemoScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
