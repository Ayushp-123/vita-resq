import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jan_sarthi/core/constants/app_constants.dart';
import 'package:jan_sarthi/core/theme/app_theme.dart';
import 'package:jan_sarthi/models/emergency_model.dart';
import 'package:jan_sarthi/models/responder_model.dart';
import 'package:jan_sarthi/screens/history/emergency_history_screen.dart';
import 'package:jan_sarthi/widgets/offline_mode_bento_banner.dart';
import 'package:jan_sarthi/widgets/sos_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P2 Vita ResQ — UI/UX & Product Identity Tests', () {
    // -------------------------------------------------------------
    // 1. BRANDING & PRODUCT IDENTITY VERIFICATION
    // -------------------------------------------------------------
    test('P2-1.1: Official App Name is exactly "Vita ResQ"', () {
      expect(AppConstants.appName, 'Vita ResQ');
    });

    test('P2-1.2: Regulatory 112 disclaimer is defined and accurate', () {
      expect(AppConstants.disclaimer112, contains('Vita ResQ'));
      expect(AppConstants.disclaimer112, contains('112'));
      expect(AppConstants.disclaimer112, contains('NOT replace'));
    });

    test('P2-1.3: Deep Navy and Emergency Red theme tokens are properly established', () {
      expect(AppTheme.primaryNavy, const Color(0xFF0F172A));
      expect(AppTheme.brandBlue, const Color(0xFF2563EB));
      expect(AppTheme.emergencyRed, const Color(0xFFDC2626));
      expect(AppTheme.emeraldGreen, const Color(0xFF10B981));
      expect(AppTheme.surfaceLight, const Color(0xFFF8FAFC));
    });

    // -------------------------------------------------------------
    // 2. PRESS-AND-HOLD SOS INTERACTION
    // -------------------------------------------------------------
    testWidgets('P2-2.1: SOSButton renders in idle state with hold instructions', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SOSButton(),
          ),
        ),
      );

      expect(find.text('SOS'), findsOneWidget);
      expect(find.text('HOLD 2 SECONDS'), findsOneWidget);
    });

    testWidgets('P2-2.2: Quick tap does not trigger SOS activation', (WidgetTester tester) async {
      bool activated = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SOSButton(
              holdDuration: const Duration(milliseconds: 600),
              onSOSActivated: () => activated = true,
            ),
          ),
        ),
      );

      // Perform a quick tap
      await tester.tap(find.byType(SOSButton));
      await tester.pump(const Duration(milliseconds: 100));

      expect(activated, isFalse);
    });

    testWidgets('P2-2.3: Releasing early cancels hold safely without activation', (WidgetTester tester) async {
      bool activated = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SOSButton(
              holdDuration: const Duration(milliseconds: 600),
              onSOSActivated: () => activated = true,
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.byType(SOSButton)));
      await tester.pump();
      // Hold for 250ms (less than 600ms threshold)
      await tester.pump(const Duration(milliseconds: 250));
      // Release early
      await gesture.up();
      await tester.pump();

      expect(activated, isFalse);
    });

    testWidgets('P2-2.4: Holding past full duration triggers successful SOS activation', (WidgetTester tester) async {
      bool activated = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SOSButton(
              holdDuration: const Duration(milliseconds: 400),
              onSOSActivated: () => activated = true,
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.byType(SOSButton)));
      await tester.pump();
      // Hold for 500ms (exceeding 400ms duration)
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pump();

      expect(activated, isTrue);
    });

    // -------------------------------------------------------------
    // 3. USER-SCOPED EMERGENCY HISTORY
    // -------------------------------------------------------------
    test('P2-3.1: EmergencyHistoryFilter.filterHelpAsked only includes current user emergencies', () {
      final userEmergencies = [
        EmergencyModel(
          id: 'EMG-USER-1',
          victimId: 'user_alpha',
          type: 'MEDICAL',
          latitude: 28.6,
          longitude: 77.2,
          status: EmergencyStatus.COMPLETED,
          createdAt: DateTime(2026, 10, 1, 10, 0),
          updatedAt: DateTime(2026, 10, 1, 10, 30),
        ),
        EmergencyModel(
          id: 'EMG-OTHER-USER',
          victimId: 'user_bravo',
          type: 'FIRE',
          latitude: 28.7,
          longitude: 77.3,
          status: EmergencyStatus.COMPLETED,
          createdAt: DateTime(2026, 10, 1, 11, 0),
          updatedAt: DateTime(2026, 10, 1, 11, 30),
        ),
        EmergencyModel(
          id: 'EMG-USER-2',
          victimId: 'user_alpha',
          type: 'CRIME',
          latitude: 28.5,
          longitude: 77.1,
          status: EmergencyStatus.ARRIVED,
          createdAt: DateTime(2026, 10, 1, 12, 0),
          updatedAt: DateTime(2026, 10, 1, 12, 10),
        ),
      ];

      final filtered = EmergencyHistoryFilter.filterHelpAsked(userEmergencies, 'user_alpha');

      expect(filtered.length, 2);
      expect(filtered.every((e) => e.victimId == 'user_alpha'), isTrue);
      expect(filtered.any((e) => e.id == 'EMG-OTHER-USER'), isFalse);
      // Verify descending chronological order (newest first)
      expect(filtered.first.id, 'EMG-USER-2');
      expect(filtered.last.id, 'EMG-USER-1');
    });

    test('P2-3.2: Empty UID returns empty list to prevent global history leakage', () {
      final emergencies = [
        EmergencyModel(
          id: 'EMG-1',
          victimId: 'stranger_uid',
          type: 'MEDICAL',
          latitude: 28.6,
          longitude: 77.2,
          status: EmergencyStatus.COMPLETED,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final helpAsked = EmergencyHistoryFilter.filterHelpAsked(emergencies, '');
      final victimsHelped = EmergencyHistoryFilter.filterVictimsHelped(emergencies, '');

      expect(helpAsked, isEmpty);
      expect(victimsHelped, isEmpty);
    });

    test('P2-3.3: EmergencyHistoryFilter.filterVictimsHelped excludes own emergencies and includes assists', () {
      final emergencies = [
        // Emergency where user is victim (MUST NOT appear in victims helped)
        EmergencyModel(
          id: 'EMG-OWN',
          victimId: 'user_alpha',
          type: 'MEDICAL',
          latitude: 28.6,
          longitude: 77.2,
          status: EmergencyStatus.COMPLETED,
          createdAt: DateTime(2026, 10, 1, 9, 0),
          updatedAt: DateTime(2026, 10, 1, 9, 30),
        ),
        // Emergency where user is primary helper
        EmergencyModel(
          id: 'EMG-PRIMARY-HELP',
          victimId: 'victim_beta',
          helperId: 'user_alpha',
          type: 'ACCIDENT',
          latitude: 28.7,
          longitude: 77.3,
          status: EmergencyStatus.COMPLETED,
          createdAt: DateTime(2026, 10, 1, 14, 0),
          updatedAt: DateTime(2026, 10, 1, 14, 25),
        ),
        // Emergency where user is a registered standby responder
        EmergencyModel(
          id: 'EMG-STANDBY-HELP',
          victimId: 'victim_gamma',
          type: 'MEDICAL',
          latitude: 28.8,
          longitude: 77.4,
          status: EmergencyStatus.COMPLETED,
          responders: {
            'user_alpha': ResponderModel(
              userId: 'user_alpha',
              userName: 'Alpha Responder',
              role: ResponderRole.STANDBY,
              status: ResponderStatus.RESPONDING,
              latitude: 28.8,
              longitude: 77.4,
              acceptedAt: DateTime(2026, 10, 1, 15, 0),
              lastLocationUpdate: DateTime(2026, 10, 1, 15, 0),
            ),
          },
          createdAt: DateTime(2026, 10, 1, 15, 0),
          updatedAt: DateTime(2026, 10, 1, 15, 20),
        ),
        // Unrelated emergency
        EmergencyModel(
          id: 'EMG-UNRELATED',
          victimId: 'victim_delta',
          helperId: 'stranger_helper',
          type: 'FIRE',
          latitude: 28.9,
          longitude: 77.5,
          status: EmergencyStatus.COMPLETED,
          createdAt: DateTime(2026, 10, 1, 16, 0),
          updatedAt: DateTime(2026, 10, 1, 16, 30),
        ),
      ];

      final helped = EmergencyHistoryFilter.filterVictimsHelped(emergencies, 'user_alpha');

      expect(helped.length, 2);
      expect(helped.any((e) => e.id == 'EMG-PRIMARY-HELP'), isTrue);
      expect(helped.any((e) => e.id == 'EMG-STANDBY-HELP'), isTrue);
      expect(helped.any((e) => e.id == 'EMG-OWN'), isFalse);
      expect(helped.any((e) => e.id == 'EMG-UNRELATED'), isFalse);
    });

    // -------------------------------------------------------------
    // 4. CONNECTIVITY & OFFLINE P2P MESH VISUALIZATION
    // -------------------------------------------------------------
    testWidgets('P2-4.1: OfflineModeBentoBanner displays clear mesh details without false map claims', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OfflineModeBentoBanner(),
            ),
          ),
        ),
      );

      expect(find.text('OFFLINE P2P COMMUNICATION'), findsOneWidget);
      expect(find.text('Bluetooth Low Energy'), findsOneWidget);
      expect(find.text('Nearby P2P Discovery'), findsOneWidget);
      expect(find.text('Local Emergency Cache'), findsOneWidget);
      expect(find.textContaining('Online map tiles & road routing require internet'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // 5. ACCESSIBILITY & CONTRAST UNDER STRESS
    // -------------------------------------------------------------
    testWidgets('P2-5.1: SOSButton provides accessible Semantics label and action', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SOSButton(),
          ),
        ),
      );

      final semanticsFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label != null && w.properties.label!.contains('Emergency SOS Trigger'),
      );
      expect(semanticsFinder, findsOneWidget);
    });
  });
}
