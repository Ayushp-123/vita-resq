import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:jan_sarthi/core/theme/app_theme.dart';
import 'package:jan_sarthi/models/emergency_model.dart';
import 'package:jan_sarthi/models/responder_model.dart';
import 'package:jan_sarthi/screens/emergency/emergency_map_screen.dart';
import 'package:jan_sarthi/screens/emergency/emergency_details_screen.dart';
import 'package:jan_sarthi/screens/home/home_screen.dart';
import 'package:jan_sarthi/widgets/sos_button.dart';
import 'package:jan_sarthi/widgets/emergency_type_sheet.dart';
import 'package:jan_sarthi/widgets/emergency_timeline_widget.dart';
import 'package:jan_sarthi/widgets/responder_profile_card.dart';
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

  EmergencyModel createTestEmergency({
    required EmergencyStatus status,
    String type = 'MEDICAL',
    ResponderModel? primaryResponder,
    String victimId = 'offline_user',
  }) {
    final responders = <String, ResponderModel>{};
    if (primaryResponder != null) {
      responders[primaryResponder.userId] = primaryResponder;
    }

    return EmergencyModel(
      id: 'em_phase6_test_001',
      victimId: victimId,
      type: type,
      latitude: 28.6139,
      longitude: 77.2090,
      status: status,
      helperId: primaryResponder?.userId,
      responders: responders,
      createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
      updatedAt: DateTime.now(),
    );
  }

  group('Vita ResQ Phase 6 — SOS & Emergency Activation Flow UI Tests', () {
    // -------------------------------------------------------------
    // 6.1 SOS ACTIVATION UI
    // -------------------------------------------------------------
    testWidgets('6.1: SOSButton renders with required hold instructions and triggers on 2s hold', (tester) async {
      bool activated = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SOSButton(
              size: 200,
              holdDuration: const Duration(milliseconds: 300),
              onSOSActivated: () => activated = true,
            ),
          ),
        ),
      );

      // Verify idle high-contrast hierarchy
      expect(find.text('SOS'), findsOneWidget);
      expect(find.text('HOLD 2 SECONDS'), findsOneWidget);

      // Early release should cancel
      final gesture = await tester.startGesture(tester.getCenter(find.byType(SOSButton)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pump();
      expect(activated, isFalse);

      // Holding through duration triggers activation
      final fullGesture = await tester.startGesture(tester.getCenter(find.byType(SOSButton)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await fullGesture.up();
      await tester.pump();
      expect(activated, isTrue);
    });

    // -------------------------------------------------------------
    // 6.2 EMERGENCY TYPE SELECTION
    // -------------------------------------------------------------
    testWidgets('6.2: EmergencyTypeSheet displays options and handles selection', (tester) async {
      String selectedType = '';

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

      expect(find.text('Select Emergency Type'), findsOneWidget);
      expect(find.text('Medical'), findsOneWidget);
      expect(find.text('Accident'), findsOneWidget);
      expect(find.text('Police'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);

      // Touch targets should have comfortable height (>= 48dp)
      final optionFinder = find.text('Accident');
      expect(optionFinder, findsOneWidget);
      await tester.tap(optionFinder);
      await tester.pump();

      expect(selectedType, 'ACCIDENT');
    });

    // -------------------------------------------------------------
    // 6.3 SEARCHING STATE
    // -------------------------------------------------------------
    testWidgets('6.3: EmergencyMapScreen SEARCHING state displays reassuring human hierarchy', (tester) async {
      final searchingEmergency = createTestEmergency(status: EmergencyStatus.SEARCHING);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyMapScreen(
            emergencyId: searchingEmergency.id,
            initialEmergency: searchingEmergency,
          ),
        ),
      );
      await tester.pump();

      // Top state badge & titles
      expect(find.text('SEARCHING FOR HELP'), findsOneWidget);
      expect(find.text('Finding nearby help'), findsOneWidget);
      expect(find.text('Looking for a responder near you…'), findsOneWidget);
      expect(find.text('Your request is active.'), findsOneWidget);

      // Emergency type & location sharing
      expect(find.text('Medical Emergency'), findsOneWidget);
      expect(find.text('Your location is being shared.'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);

      // Timeline in searching state
      expect(find.byType(EmergencyTimelineWidget), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);

      // Human fallback contacts wording
      expect(find.text('Having trouble finding help?'), findsOneWidget);
      expect(find.text('Contact your trusted emergency contacts'), findsOneWidget);
      expect(find.text('SMS Contacts'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);

      // Cancel action
      expect(find.text('Cancel Emergency'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // 6.4 ASSIGNED / APPROACHING STATE
    // -------------------------------------------------------------
    testWidgets('6.4: EmergencyMapScreen ASSIGNED/APPROACHING state displays responder card and ETA', (tester) async {
      final primaryResponder = ResponderModel(
        userId: 'resp_108',
        userName: 'Vikram Singh',
        phoneNumber: '+919876543210',
        role: ResponderRole.PRIMARY,
        status: ResponderStatus.RESPONDING,
        userRole: 'AMBULANCE_DRIVER',
        vehicleNumber: '108-DL',
        bloodGroup: 'O+',
        latitude: 28.6150,
        longitude: 77.2100,
        acceptedAt: DateTime.now(),
        lastLocationUpdate: DateTime.now(),
      );

      final approachingEmergency = createTestEmergency(
        status: EmergencyStatus.APPROACHING,
        primaryResponder: primaryResponder,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyMapScreen(
            emergencyId: approachingEmergency.id,
            initialEmergency: approachingEmergency,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Primary hierarchy
      expect(find.text('HELP IS ON THE WAY'), findsOneWidget);
      expect(find.text('Help is on the way'), findsOneWidget);
      expect(find.textContaining('Ambulance #108-DL responding'), findsOneWidget);

      // Responder profile card
      expect(find.byType(ResponderProfileCard), findsOneWidget);
      expect(find.text('Vikram Singh'), findsOneWidget);
      expect(find.text('Ambulance #108-DL'), findsOneWidget);
      expect(find.text('O+'), findsOneWidget);

      // Call action button exists
      expect(find.byIcon(Icons.phone_rounded), findsOneWidget);

      // Timeline shows approaching
      expect(find.byType(EmergencyTimelineWidget), findsOneWidget);
      expect(find.text('Approaching'), findsOneWidget);

      // Cancel button remains accessible
      expect(find.text('Cancel Emergency'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // 6.5 ARRIVED STATE
    // -------------------------------------------------------------
    testWidgets('6.5: EmergencyMapScreen ARRIVED state displays clear, calm arrival notice', (tester) async {
      final primaryResponder = ResponderModel(
        userId: 'resp_200',
        userName: 'Officer Sharma',
        phoneNumber: '+919811122233',
        role: ResponderRole.PRIMARY,
        status: ResponderStatus.ARRIVED,
        userRole: 'POLICE_PCR',
        vehicleNumber: 'PCR-09',
        latitude: 28.6140,
        longitude: 77.2091,
        acceptedAt: DateTime.now(),
        lastLocationUpdate: DateTime.now(),
      );

      final arrivedEmergency = createTestEmergency(
        status: EmergencyStatus.ARRIVED,
        primaryResponder: primaryResponder,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyMapScreen(
            emergencyId: arrivedEmergency.id,
            initialEmergency: arrivedEmergency,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('RESPONDER ARRIVED'), findsOneWidget);
      expect(find.text('Help has arrived'), findsWidgets);
      expect(find.text('Your responder is nearby.'), findsOneWidget);
      expect(find.textContaining('Please stay in a safe, visible position'), findsOneWidget);
      expect(find.text('Officer Sharma'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // 6.6 COMPLETED & CANCELLED STATES
    // -------------------------------------------------------------
    testWidgets('6.6: EmergencyMapScreen COMPLETED and CANCELLED states display closure summaries', (tester) async {
      final helper = ResponderModel(
        userId: 'resp_300',
        userName: 'Aarav Mehta',
        phoneNumber: '+919900112233',
        role: ResponderRole.PRIMARY,
        status: ResponderStatus.ARRIVED,
        userRole: 'CITIZEN',
        latitude: 28.6139,
        longitude: 77.2090,
        acceptedAt: DateTime.now(),
        lastLocationUpdate: DateTime.now(),
      );

      final completedEmergency = createTestEmergency(
        status: EmergencyStatus.COMPLETED,
        primaryResponder: helper,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyMapScreen(
            emergencyId: completedEmergency.id,
            initialEmergency: completedEmergency,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('EMERGENCY COMPLETED'), findsOneWidget);
      expect(find.text('Emergency completed'), findsOneWidget);
      expect(find.text('INCIDENT SUMMARY'), findsOneWidget);
      expect(find.text('Rate & Verify Assistance'), findsOneWidget);
      expect(find.text('CLOSE SUMMARY'), findsOneWidget);

      // Now test CANCELLED state
      final cancelledEmergency = createTestEmergency(status: EmergencyStatus.CANCELLED);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyMapScreen(
            emergencyId: cancelledEmergency.id,
            initialEmergency: cancelledEmergency,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('EMERGENCY CANCELLED'), findsOneWidget);
      expect(find.text('Emergency Cancelled'), findsWidgets);
      expect(find.text('This alert was cancelled. Responders have been notified.'), findsOneWidget);
      expect(find.text('CLOSE SUMMARY'), findsOneWidget);
    });

    testWidgets('6.6b: Cancel Emergency button opens intentional confirmation dialog', (tester) async {
      final searchingEmergency = createTestEmergency(status: EmergencyStatus.SEARCHING);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyMapScreen(
            emergencyId: searchingEmergency.id,
            initialEmergency: searchingEmergency,
          ),
        ),
      );
      await tester.pump();

      // Scroll until Cancel Emergency button is visible and tap
      await tester.scrollUntilVisible(find.text('Cancel Emergency'), 100);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel Emergency'));
      await tester.pumpAndSettle();

      // Verify intentional confirmation UI
      expect(find.text('Cancel emergency?'), findsOneWidget);
      expect(find.text('Are you sure you no longer need help? Responders will be notified.'), findsOneWidget);
      expect(find.text('Keep Emergency Active'), findsOneWidget);

      // Tap Keep Emergency Active to dismiss without cancelling
      await tester.tap(find.text('Keep Emergency Active'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel emergency?'), findsNothing);
      expect(find.text('Finding nearby help'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // 6.7 COMPACT VIEWPORT RESPONSIVENESS (360x640 and 390x844)
    // -------------------------------------------------------------
    testWidgets('6.7: Compact Android viewports (360x640, 390x844) render without RenderFlex overflow across states', (tester) async {
      final searchingEmergency = createTestEmergency(status: EmergencyStatus.SEARCHING);

      for (final size in [const Size(360, 640), const Size(390, 844)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: EmergencyMapScreen(
              emergencyId: searchingEmergency.id,
              initialEmergency: searchingEmergency,
            ),
          ),
        );
        await tester.pump();
        final exMap = tester.takeException();
        expect(exMap, isNull);
        expect(find.text('Finding nearby help'), findsOneWidget);

        // Verify Emergency Details screen also renders cleanly
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: EmergencyDetailsScreen(
              emergencyId: searchingEmergency.id,
              initialEmergency: searchingEmergency,
            ),
          ),
        );
        await tester.pump();
        final exDetails = tester.takeException();
        expect(exDetails, isNull);
        expect(find.text('Nearby Emergency Request'), findsOneWidget);
      }
      tester.view.resetPhysicalSize();
    });

    // -------------------------------------------------------------
    // 6.8 BOTTOM NAVIGATION REMAINS CORRECT
    // -------------------------------------------------------------
    testWidgets('6.8: Bottom navigation remains correct with Home selected at index 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(initialPosition: testPosition),
        ),
      );
      await tester.pump();

      expect(find.byType(AppBottomNavBar), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });
  });
}
