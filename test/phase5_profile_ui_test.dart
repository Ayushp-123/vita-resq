import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jan_sarthi/core/theme/app_theme.dart';
import 'package:jan_sarthi/models/user_model.dart';
import 'package:jan_sarthi/models/impact_model.dart';
import 'package:jan_sarthi/services/emergency_service.dart';
import 'package:jan_sarthi/screens/profile/profile_screen.dart';
import 'package:jan_sarthi/screens/emergency_contacts/emergency_contacts_screen.dart';
import 'package:jan_sarthi/screens/impact/impact_rewards_screen.dart';
import 'package:jan_sarthi/screens/impact/certificates_screen.dart';
import 'package:jan_sarthi/widgets/common/app_bottom_nav_bar.dart';
import 'package:jan_sarthi/widgets/community_certificate_dialog.dart';

void main() {
  group('Vita ResQ Phase 5 — Profile Screen Redesign Tests', () {
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

    final testContacts = [
      EmergencyContact(name: 'Sarah Connor', phoneNumber: '+91 98765 00001', relationship: 'Family'),
      EmergencyContact(name: 'John Connor', phoneNumber: '+91 98765 00002', relationship: 'Friend'),
    ];

    testWidgets('5.1: Profile header displays calm personal identity without metric hero clutter', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ProfileScreen(
            initialUserProfile: testUser,
            initialImpactProfile: testUser.impactProfile,
            initialContacts: testContacts,
          ),
        ),
      );
      await tester.pump();

      // Personal details
      expect(find.text('Marcus Vance'), findsOneWidget);
      expect(find.text('marcus.vance@example.com'), findsOneWidget);
      expect(find.text('Citizen Volunteer'), findsOneWidget);

      // Avatar circle
      expect(find.byType(CircleAvatar), findsWidgets);

      // Strict omission of metric/gaming hero clutter in the header
      expect(find.textContaining('Rank #'), findsNothing);
      expect(find.textContaining('GPS:'), findsNothing);
      expect(find.textContaining('Telemetry'), findsNothing);
      expect(find.textContaining('Active SOS'), findsNothing);
    });

    testWidgets('5.2: Account section displays personal info rows and triggers Edit Profile dialog', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ProfileScreen(
            initialUserProfile: testUser,
            initialImpactProfile: testUser.impactProfile,
            initialContacts: testContacts,
          ),
        ),
      );
      await tester.pump();

      // Account info rows
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('+91 98765 43210'), findsOneWidget);
      expect(find.text('Blood Group'), findsOneWidget);
      expect(find.text('O+ (Universal Donor)'), findsOneWidget);
      expect(find.text('Vehicle Number'), findsOneWidget);
      expect(find.text('DL-01-AB-1234'), findsOneWidget);

      // Edit Profile & Role row
      final editRow = find.text('Edit Profile & Role');
      await tester.scrollUntilVisible(editRow, 100, scrollable: find.byType(Scrollable).first);
      expect(editRow, findsOneWidget);

      await tester.tap(editRow);
      await tester.pumpAndSettle();

      // Edit dialog opened
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Edit Profile & Role'), findsNWidgets(2)); // row + dialog title
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('5.3: Emergency contacts dedicated screen displays contacts and test SMS button', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyContactsScreen(
            initialContacts: testContacts,
          ),
        ),
      );
      await tester.pump();

      // Screen is visible
      expect(find.text('Emergency Contacts'), findsOneWidget);
      expect(find.text('Sarah Connor'), findsOneWidget);
      expect(find.text('John Connor'), findsOneWidget);
      expect(find.text('Test Emergency SMS to Contacts'), findsOneWidget);
    });

    testWidgets('5.4: Civic recognition dedicated screen prioritizes contribution over game mechanics', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ImpactRewardsScreen(
            initialImpactProfile: testUser.impactProfile,
          ),
        ),
      );
      await tester.pump();

      // Recognition level & contribution stats
      final level = testUser.impactProfile.currentLevel;
      final levelText = find.text(level.title);
      expect(levelText, findsOneWidget);
      expect(find.text('8'), findsOneWidget); // verified assists count
      expect(find.text('80%'), findsOneWidget); // reliability score

      // Impact points pill
      expect(find.text('320 Impact Pts'), findsOneWidget);

      // Badges summary
      expect(find.textContaining('CIVIC BADGES'), findsOneWidget);
    });

    testWidgets('5.5: Certificates dedicated screen opens official credential dialog', (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: CertificatesScreen(
            initialImpactProfile: testUser.impactProfile,
            initialUserName: 'Marcus Vance',
          ),
        ),
      );
      await tester.pump();

      // View full certificate button
      final certButton = find.text('View Full Certificate');
      expect(certButton, findsOneWidget);

      await tester.tap(certButton);
      await tester.pumpAndSettle();

      // CommunityCertificateDialog is shown
      expect(find.byType(CommunityCertificateDialog), findsOneWidget);
      expect(find.text('COMMUNITY RESPONDER CERTIFICATE'), findsOneWidget);
    });

    testWidgets('5.6: Bottom navigation has Profile selected at index 2', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ProfileScreen(
            initialUserProfile: testUser,
            initialImpactProfile: testUser.impactProfile,
            initialContacts: testContacts,
          ),
        ),
      );
      await tester.pump();

      final navBarFinder = find.byType(AppBottomNavBar);
      expect(navBarFinder, findsOneWidget);
      final navBar = tester.widget<AppBottomNavBar>(navBarFinder);
      expect(navBar.currentIndex, 2);

      expect(find.descendant(of: navBarFinder, matching: find.text('Home')), findsOneWidget);
      expect(find.descendant(of: navBarFinder, matching: find.text('History')), findsOneWidget);
      expect(find.descendant(of: navBarFinder, matching: find.text('Profile')), findsOneWidget);
    });

    testWidgets('5.7: Compact Android viewport (360x640) renders without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ProfileScreen(
            initialUserProfile: testUser,
            initialImpactProfile: testUser.impactProfile,
            initialContacts: testContacts,
          ),
        ),
      );
      await tester.pump();

      // Verify no RenderFlex errors occur during scroll
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
