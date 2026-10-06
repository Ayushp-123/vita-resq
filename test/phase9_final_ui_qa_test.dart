import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:jan_sarthi/core/theme/app_theme.dart';
import 'package:jan_sarthi/models/emergency_model.dart';
import 'package:jan_sarthi/screens/home/home_screen.dart';
import 'package:jan_sarthi/screens/history/emergency_history_screen.dart';
import 'package:jan_sarthi/screens/profile/profile_screen.dart';
import 'package:jan_sarthi/screens/impact/impact_rewards_screen.dart';
import 'package:jan_sarthi/screens/auth/login_screen.dart';
import 'package:jan_sarthi/screens/auth/register_screen.dart';
import 'package:jan_sarthi/widgets/common/common.dart';
import 'package:jan_sarthi/widgets/emergency_type_sheet.dart';
import 'package:jan_sarthi/widgets/incoming_emergency_card.dart';
import 'package:jan_sarthi/widgets/app_dialogs.dart';
import 'package:jan_sarthi/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testPosition = Position(
    latitude: 21.2253,
    longitude: 81.3107,
    timestamp: DateTime.now(),
    accuracy: 4.0,
    altitude: 280.0,
    altitudeAccuracy: 1.0,
    heading: 0.0,
    headingAccuracy: 0.0,
    speed: 0.0,
    speedAccuracy: 0.0,
  );

  final testEmergency = EmergencyModel(
    id: 'emg-phase9-01',
    victimId: 'victim-qa-01',
    latitude: 21.2253,
    longitude: 81.3107,
    status: EmergencyStatus.SEARCHING,
    createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
    updatedAt: DateTime.now(),
    type: 'Medical',
    currentRadiusMeters: 1000.0,
  );

  group('Vita ResQ Phase 9 — Final Full-App Polish, Consistency & QA', () {
    // -------------------------------------------------------------
    // 9.1 Global Navigation Consistency
    // -------------------------------------------------------------
    testWidgets('9.1: AppBottomNavBar provides canonical 3-tab navigation with >=48dp touch targets', (tester) async {
      int selectedTab = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            bottomNavigationBar: AppBottomNavBar(
              currentIndex: selectedTab,
              onTap: (index) => selectedTab = index,
            ),
          ),
        ),
      );
      await tester.pump();

      // Exactly 3 locked canonical tabs
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Impact'), findsNothing);
      expect(find.text('Responder'), findsNothing);

      // Verify touch target >= 48dp on tab tap areas
      final homeTab = find.ancestor(of: find.text('Home'), matching: find.byType(InkResponse));
      expect(homeTab, findsOneWidget);
      final homeRect = tester.getRect(homeTab);
      expect(homeRect.height, greaterThanOrEqualTo(48.0));

      // Tap History tab
      await tester.tap(find.text('History'));
      expect(selectedTab, 1);
    });

    // -------------------------------------------------------------
    // 9.2 Design-System Component Consistency
    // -------------------------------------------------------------
    test('9.2: Design system status tokens and badges map to unified visual language', () {
      // Phase 1 semantic status mapping
      expect(AppStatusConfig.resolve(AppStatusType.normal).color, AppColors.navy700);
      expect(AppStatusConfig.resolve(AppStatusType.online).color, AppColors.emeraldGreen);
      expect(AppStatusConfig.resolve(AppStatusType.warning).color, AppColors.warningAmber);
      expect(AppStatusConfig.resolve(AppStatusType.emergency).color, AppColors.emergencyRed);
      expect(AppStatusConfig.resolve(AppStatusType.success).color, AppColors.emeraldGreen);

      // Shared shapes
      expect(AppShapes.radiusSm, 10.0);
      expect(AppShapes.radiusMd, 16.0);
      expect(AppShapes.radiusLg, 24.0);
      expect(AppShapes.radiusXl, 32.0);
    });

    // -------------------------------------------------------------
    // 9.3 Home Hierarchy
    // -------------------------------------------------------------
    testWidgets('9.3: Home hierarchy remains strictly intact with GPS Active badge', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(initialPosition: testPosition),
        ),
      );
      await tester.pump();

      // 1. Header
      expect(find.text('Vita ResQ'), findsOneWidget);
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);

      // 2. Status / Context
      expect(find.textContaining('112'), findsWidgets);

      // 3. Map with humanized GPS badge
      expect(find.text('GPS Active'), findsWidgets);
      expect(find.byIcon(Icons.gps_fixed_rounded), findsOneWidget);

      // 4. Emergency prompt & SOS
      expect(find.text('Need emergency help?'), findsOneWidget);
      expect(find.text('SOS'), findsOneWidget);
      expect(find.text('Hold for help'), findsOneWidget);

      // 5. Bottom Navigation
      expect(find.byType(AppBottomNavBar), findsOneWidget);
    });

    // -------------------------------------------------------------
    // 9.4 History Structure
    // -------------------------------------------------------------
    testWidgets('9.4: History screen maintains dual views, human empty states, and no reward clutter', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const EmergencyHistoryScreen(
            initialUserId: 'user_qa',
            initialEmergencies: [],
          ),
        ),
      );
      await tester.pump();

      // Two Views
      expect(find.text('Help Asked'), findsOneWidget);
      expect(find.text('Victims Helped'), findsOneWidget);

      // Clean empty state without game XP
      expect(find.text('No SOS requests yet'), findsOneWidget);
      expect(find.textContaining('Any emergency alerts you trigger'), findsOneWidget);
      expect(find.textContaining('XP'), findsNothing);
      expect(find.textContaining('Points'), findsNothing);
    });

    // -------------------------------------------------------------
    // 9.5 Profile Structure
    // -------------------------------------------------------------
    testWidgets('9.5: Profile screen maintains clear section groupings and civic recognition', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ProfileScreen(),
        ),
      );
      await tester.pump();

      // Profile Screen Section Headers (Profile = Me)
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('ACCOUNT ACTIONS'), findsOneWidget);

      // Reassuring Sign Out action
      expect(find.text('Sign Out'), findsOneWidget);

      // Civic recognition lives on dedicated screen
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ImpactRewardsScreen(),
        ),
      );
      await tester.pump();
      expect(find.text('Impact & Rewards'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // 9.6 SOS State Presentation
    // -------------------------------------------------------------
    testWidgets('9.6: SOS EmergencyTypeSheet provides >=48dp close button and 4 clear categories', (tester) async {
      String? selectedType;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: EmergencyTypeSheet(
              currentType: 'MEDICAL',
              onTypeSelected: (type) => selectedType = type,
            ),
          ),
        ),
      );
      await tester.pump();

      // Categories
      expect(find.text('Medical'), findsOneWidget);
      expect(find.text('Accident'), findsOneWidget);
      expect(find.text('Police'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);

      // Close button touch target >= 48dp
      final closeButton = find.ancestor(
        of: find.byIcon(Icons.close_rounded),
        matching: find.byType(IconButton),
      );
      expect(closeButton, findsOneWidget);
      final closeRect = tester.getRect(closeButton);
      expect(closeRect.height, greaterThanOrEqualTo(48.0));
      expect(closeRect.width, greaterThanOrEqualTo(48.0));

      // Tap Accident option
      await tester.tap(find.text('Accident'));
      expect(selectedType, 'ACCIDENT');
    });

    // -------------------------------------------------------------
    // 9.7 Responder State Presentation
    // -------------------------------------------------------------
    testWidgets('9.7: Responder card renders glanceable distance and prominent [ I CAN HELP ]', (tester) async {
      bool helpTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: IncomingEmergencyCard(
              emergency: testEmergency,
              distanceMeters: 450,
              onCanHelp: () => helpTapped = true,
              onViewDetails: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('450 m away'), findsOneWidget);
      expect(find.text('I CAN HELP'), findsOneWidget);

      // Prominent touch target >= 48dp
      final helpButton = find.ancestor(
        of: find.text('I CAN HELP'),
        matching: find.byType(ElevatedButton),
      );
      expect(helpButton, findsOneWidget);
      final rect = tester.getRect(helpButton);
      expect(rect.height, greaterThanOrEqualTo(48.0));

      await tester.tap(helpButton);
      expect(helpTapped, isTrue);
    });

    // -------------------------------------------------------------
    // 9.8 Global Feedback Components
    // -------------------------------------------------------------
    testWidgets('9.8: AppFeedbackBanner and AppLoadingState present clean human messages', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Column(
              children: [
                AppFeedbackBanner(
                  status: AppStatusType.online,
                  title: 'GPS Signal Calibrated',
                  message: 'Emergency response will share high-accuracy coordinates.',
                ),
                AppLoadingState(message: 'Finding nearby help…'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('GPS Signal Calibrated'), findsOneWidget);
      expect(find.text('Emergency response will share high-accuracy coordinates.'), findsOneWidget);
      expect(find.text('Finding nearby help…'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // 9.9 Compact Viewport Responsiveness (360x640, 390x844, 412x915)
    // -------------------------------------------------------------
    testWidgets('9.9: Major screens render without RenderFlex overflow on ultra-compact 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // 1. LoginScreen on 360x640
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const LoginScreen(),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      // 2. RegisterScreen on 360x640
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const RegisterScreen(),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      // 3. HomeScreen on 360x640
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(initialPosition: testPosition),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------
    // 9.10 Emergency-Critical Touch Targets (>= 48dp)
    // -------------------------------------------------------------
    testWidgets('9.10: Destructive confirmation dialog and crash warning meet >= 48dp standards', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    AppDialogs.showDestructiveConfirmDialog(
                      context: ctx,
                      title: 'Cancel Emergency?',
                      message: 'Are you sure you no longer need assistance?',
                      cancelLabel: 'Keep Emergency Active',
                      confirmLabel: 'Cancel Emergency',
                      isDangerous: true,
                    );
                  },
                  child: const Text('OPEN DIALOG'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Open dialog
      await tester.tap(find.text('OPEN DIALOG'));
      await tester.pumpAndSettle();

      // Safe action
      final keepButton = find.ancestor(
        of: find.text('Keep Emergency Active'),
        matching: find.byType(ElevatedButton),
      );
      expect(keepButton, findsOneWidget);
      expect(tester.getRect(keepButton).height, greaterThanOrEqualTo(48.0));

      // Destructive action
      final cancelButton = find.ancestor(
        of: find.text('Cancel Emergency'),
        matching: find.byType(OutlinedButton),
      );
      expect(cancelButton, findsOneWidget);
      expect(tester.getRect(cancelButton).height, greaterThanOrEqualTo(48.0));
    });

    // -------------------------------------------------------------
    // 9.11 Absence of Obvious Technical Copy in User UI
    // -------------------------------------------------------------
    test('9.11: Emergency notifications and user copy contain zero technical jargon', () {
      final victimSearching = EmergencyAlertPresentation.formatBody(
        role: 'VICTIM',
        status: EmergencyStatus.SEARCHING,
      );
      final victimAssigned = EmergencyAlertPresentation.formatBody(
        role: 'VICTIM',
        status: EmergencyStatus.ASSIGNED,
      );
      final responderNew = EmergencyAlertPresentation.formatBody(
        role: 'RESPONDER',
        status: EmergencyStatus.SEARCHING,
      );

      final combinedText = '$victimSearching $victimAssigned $responderNew';

      // Verify no internal tech jargon leaked
      expect(combinedText.contains('Firestore'), isFalse);
      expect(combinedText.contains('FCM'), isFalse);
      expect(combinedText.contains('P2P_STAR'), isFalse);
      expect(combinedText.contains('arbitration'), isFalse);
      expect(combinedText.contains('local storage'), isFalse);
      expect(combinedText.contains('UUID'), isFalse);
      expect(combinedText.contains('Exception'), isFalse);
    });

    // -------------------------------------------------------------
    // 9.12 Authentication Screen Consistency
    // -------------------------------------------------------------
    testWidgets('9.12: Auth screens feature fixed 52dp submit buttons and >=48dp links', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const LoginScreen(),
        ),
      );
      await tester.pump();

      // Brand Title
      expect(find.text('VITA RESQ'), findsOneWidget);
      expect(find.text('Community Emergency Response Network'), findsOneWidget);

      // Submit Button (52dp height)
      final loginBtn = find.ancestor(
        of: find.text('LOGIN'),
        matching: find.byType(ElevatedButton),
      );
      expect(loginBtn, findsOneWidget);
      expect(tester.getRect(loginBtn).height, greaterThanOrEqualTo(52.0));

      // Register link touch target >= 48dp
      final regLink = find.ancestor(
        of: find.text('REGISTER'),
        matching: find.byType(TextButton),
      );
      expect(regLink, findsOneWidget);
      expect(tester.getRect(regLink).height, greaterThanOrEqualTo(48.0));
    });
  });
}
