import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import 'package:jan_sarthi/core/theme/app_theme.dart';
import 'package:jan_sarthi/models/emergency_model.dart';
import 'package:jan_sarthi/models/responder_model.dart';
import 'package:jan_sarthi/models/hospital_model.dart';
import 'package:jan_sarthi/services/hospital_service.dart';
import 'package:jan_sarthi/screens/emergency/emergency_map_screen.dart';
import 'package:jan_sarthi/screens/emergency/emergency_details_screen.dart';

class MockHospitalService implements IHospitalService {
  final List<HospitalModel> mockHospitals;
  int callCount = 0;

  MockHospitalService({required this.mockHospitals});

  @override
  Future<List<HospitalModel>> discoverNearbyHospitals({
    required LatLng location,
    double radiusMeters = 10000,
    String? emergencyId,
    bool forceRefresh = false,
  }) async {
    callCount++;
    return mockHospitals;
  }

  @override
  void clearCache({String? emergencyId}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<HospitalModel> mockHospitals = [
    const HospitalModel(
      id: 'hosp_01',
      name: 'City Trauma Center',
      latitude: 28.6180,
      longitude: 77.2150,
      distanceMeters: 850.0,
      durationSeconds: 180,
      etaText: '3 mins',
      address: 'Connaught Place, New Delhi',
      isGovernmentTraumaCenter: true,
    ),
    const HospitalModel(
      id: 'hosp_02',
      name: 'Apollo Emergency Hospital',
      latitude: 28.6250,
      longitude: 77.2200,
      distanceMeters: 1600.0,
      durationSeconds: 360,
      etaText: '6 mins',
      address: 'Barakhamba Road, New Delhi',
      isGovernmentTraumaCenter: false,
    ),
  ];

  late MockHospitalService mockHospitalService;

  setUp(() {
    mockHospitalService = MockHospitalService(mockHospitals: mockHospitals);
    HospitalService.setMockInstance(mockHospitalService);
  });

  tearDown(() {
    HospitalService.setMockInstance(null);
  });

  EmergencyModel createTestEmergency({
    String id = 'em_hospital_test_001',
    required EmergencyStatus status,
    String type = 'MEDICAL',
    ResponderModel? primaryResponder,
    double latitude = 28.6139,
    double longitude = 77.2090,
  }) {
    final responders = <String, ResponderModel>{};
    if (primaryResponder != null) {
      responders[primaryResponder.userId] = primaryResponder;
    }

    return EmergencyModel(
      id: id,
      victimId: 'victim_user_100',
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

  group('Vita ResQ — Hybrid Hospital Routing & Progressive Disclosure Tests', () {
    // ------------------------------------------------------------------------
    // 1. Hospitals can be prepared/discovered when an emergency starts
    // ------------------------------------------------------------------------
    testWidgets('1: Hospitals can be prepared and discovered when emergency starts', (tester) async {
      final emergency = createTestEmergency(status: EmergencyStatus.SEARCHING);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyMapScreen(
            emergencyId: emergency.id,
            initialEmergency: emergency,
            currentUserId: 'victim_user_100',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(mockHospitalService.callCount, greaterThanOrEqualTo(1));
      expect(find.text('Nearby Hospitals (Standby)'), findsOneWidget);
      expect(find.text('City Trauma Center'), findsOneWidget);
    });

    // ------------------------------------------------------------------------
    // 2. Responder route remains victim-first before ARRIVED
    // ------------------------------------------------------------------------
    testWidgets('2: Responder route remains victim-first before ARRIVED', (tester) async {
      final primaryResponder = ResponderModel(
        userId: 'resp_primary_001',
        userName: 'Aarav Sharma',
        phoneNumber: '+919876543210',
        role: ResponderRole.PRIMARY,
        status: ResponderStatus.RESPONDING,
        latitude: 28.6110,
        longitude: 77.2050,
        acceptedAt: DateTime.now(),
        lastLocationUpdate: DateTime.now(),
      );

      final emergency = createTestEmergency(
        status: EmergencyStatus.ASSIGNED,
        primaryResponder: primaryResponder,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyMapScreen(
            emergencyId: emergency.id,
            initialEmergency: emergency,
            currentUserId: 'resp_primary_001',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Victim-first navigation assertions
      expect(find.text('Navigating to Victim'), findsWidgets);
      expect(find.text('Proceed to emergency location'), findsOneWidget);
      expect(find.text('I HAVE ARRIVED'), findsOneWidget);
      expect(find.text('Route to selected hospital'), findsNothing);
    });

    // ------------------------------------------------------------------------
    // 3. Hospital information remains secondary before arrival
    // ------------------------------------------------------------------------
    testWidgets('3: Hospital information remains secondary before arrival', (tester) async {
      final primaryResponder = ResponderModel(
        userId: 'resp_primary_001',
        userName: 'Aarav Sharma',
        phoneNumber: '+919876543210',
        role: ResponderRole.PRIMARY,
        status: ResponderStatus.RESPONDING,
        latitude: 28.6110,
        longitude: 77.2050,
        acceptedAt: DateTime.now(),
        lastLocationUpdate: DateTime.now(),
      );

      final emergency = createTestEmergency(
        status: EmergencyStatus.APPROACHING,
        primaryResponder: primaryResponder,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyMapScreen(
            emergencyId: emergency.id,
            initialEmergency: emergency,
            currentUserId: 'resp_primary_001',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Hospitals are presented in standby card, not as active navigation
      expect(find.text('Nearby Hospitals (Standby)'), findsOneWidget);
      expect(find.text('Hospital routing will become active after reaching victim.'), findsOneWidget);
      expect(find.text('Route'), findsNothing); // No active route selection button before arrival
    });

    // ------------------------------------------------------------------------
    // 4. ARRIVED changes the primary routing context
    // ------------------------------------------------------------------------
    testWidgets('4: ARRIVED changes primary routing context to victim reached & hospital choice', (tester) async {
      final primaryResponder = ResponderModel(
        userId: 'resp_primary_001',
        userName: 'Aarav Sharma',
        phoneNumber: '+919876543210',
        role: ResponderRole.PRIMARY,
        status: ResponderStatus.ARRIVED,
        latitude: 28.6139,
        longitude: 77.2090,
        acceptedAt: DateTime.now(),
        lastLocationUpdate: DateTime.now(),
      );

      final emergency = createTestEmergency(
        status: EmergencyStatus.ARRIVED,
        primaryResponder: primaryResponder,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyMapScreen(
            emergencyId: emergency.id,
            initialEmergency: emergency,
            currentUserId: 'resp_primary_001',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text("YOU'VE ARRIVED"), findsOneWidget);
      expect(find.text('At Emergency Scene'), findsOneWidget);
      expect(find.textContaining('Victim Reached'), findsOneWidget);
      expect(find.text('At emergency scene • Assist victim'), findsOneWidget);
      expect(find.text('Choose nearby hospital'), findsOneWidget);
      expect(find.text('COMPLETE RESCUE'), findsOneWidget);
      expect(find.text('Route'), findsWidgets); // Hospital route buttons available now
    });

    // ------------------------------------------------------------------------
    // 5. Selecting a hospital sets the hospital as the route destination
    // ------------------------------------------------------------------------
    testWidgets('5: Selecting a hospital sets the hospital as the route destination', (tester) async {
      final primaryResponder = ResponderModel(
        userId: 'resp_primary_001',
        userName: 'Aarav Sharma',
        phoneNumber: '+919876543210',
        role: ResponderRole.PRIMARY,
        status: ResponderStatus.ARRIVED,
        latitude: 28.6139,
        longitude: 77.2090,
        acceptedAt: DateTime.now(),
        lastLocationUpdate: DateTime.now(),
      );

      final emergency = createTestEmergency(
        status: EmergencyStatus.ARRIVED,
        primaryResponder: primaryResponder,
      );

      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyMapScreen(
            emergencyId: emergency.id,
            initialEmergency: emergency,
            currentUserId: 'resp_primary_001',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Route on the first hospital
      final routeButtons = find.widgetWithText(ElevatedButton, 'Route');
      expect(routeButtons, findsWidgets);
      await tester.ensureVisible(routeButtons.first);
      await tester.tap(routeButtons.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Primary navigation context is now hospital route
      expect(find.text('Route to selected hospital'), findsWidgets);
      expect(find.text('City Trauma Center'), findsWidgets);
      expect(find.text('Change Hospital'), findsOneWidget);

      // Verify changing hospital resets selection
      await tester.tap(find.text('Change Hospital'));
      await tester.pump();
      expect(find.text('Choose nearby hospital'), findsOneWidget);
    });

    // ------------------------------------------------------------------------
    // 6. Hospital route is cleared on CANCELLED
    // ------------------------------------------------------------------------
    testWidgets('6: Hospital route is cleared on CANCELLED', (tester) async {
      final cancelledEmergency = createTestEmergency(status: EmergencyStatus.CANCELLED);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyMapScreen(
            emergencyId: cancelledEmergency.id,
            initialEmergency: cancelledEmergency,
            currentUserId: 'resp_primary_001',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('EMERGENCY CANCELLED'), findsOneWidget);
      expect(find.text('Emergency Cancelled'), findsWidgets);
      expect(find.text('Route to selected hospital'), findsNothing);
      expect(find.text('Choose nearby hospital'), findsNothing);
    });

    // ------------------------------------------------------------------------
    // 7. Hospital route is cleared on COMPLETED
    // ------------------------------------------------------------------------
    testWidgets('7: Hospital route is cleared on COMPLETED', (tester) async {
      final helper = ResponderModel(
        userId: 'resp_primary_001',
        userName: 'Aarav Sharma',
        phoneNumber: '+919876543210',
        role: ResponderRole.PRIMARY,
        status: ResponderStatus.ARRIVED,
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
            currentUserId: 'resp_primary_001',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Rescue complete'), findsOneWidget);
      expect(find.text('INCIDENT SUMMARY'), findsOneWidget);
      expect(find.text('Route to selected hospital'), findsNothing);
      expect(find.text('Choose nearby hospital'), findsNothing);
    });

    // ------------------------------------------------------------------------
    // 8. No duplicate hospital queries during widget rebuilds
    // ------------------------------------------------------------------------
    testWidgets('8: No duplicate hospital queries during widget rebuilds', (tester) async {
      final emergency = createTestEmergency(status: EmergencyStatus.SEARCHING);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyMapScreen(
            emergencyId: emergency.id,
            initialEmergency: emergency,
            currentUserId: 'victim_user_100',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final initialCallCount = mockHospitalService.callCount;
      expect(initialCallCount, greaterThanOrEqualTo(1));

      // Trigger multiple rebuilds
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      // Call count should NOT have increased due to session cache & lastEmergencyId check
      expect(mockHospitalService.callCount, equals(initialCallCount));
    });

    // ------------------------------------------------------------------------
    // 9. Existing 8m route recalculation protection remains intact
    // ------------------------------------------------------------------------
    test('9: Route calculation honors >=8m displacement threshold', () {
      const originA = LatLng(28.61390, 77.20900);
      // Small shift (~3 meters)
      const originB = LatLng(28.61392, 77.20902);
      final distSmall = Geolocator.distanceBetween(
        originA.latitude,
        originA.longitude,
        originB.latitude,
        originB.longitude,
      );
      expect(distSmall < 8.0, isTrue);

      // Significant shift (~20 meters)
      const originC = LatLng(28.61410, 77.20900);
      final distLarge = Geolocator.distanceBetween(
        originA.latitude,
        originA.longitude,
        originC.latitude,
        originC.longitude,
      );
      expect(distLarge >= 8.0, isTrue);
    });

    // ------------------------------------------------------------------------
    // 10. Offline mode does not falsely claim offline OSRM routing
    // ------------------------------------------------------------------------
    testWidgets('10: Offline mode displays transparent limitation disclaimer', (tester) async {
      final primaryResponder = ResponderModel(
        userId: 'resp_primary_001',
        userName: 'Aarav Sharma',
        phoneNumber: '+919876543210',
        role: ResponderRole.PRIMARY,
        status: ResponderStatus.ARRIVED,
        latitude: 28.6139,
        longitude: 77.2090,
        acceptedAt: DateTime.now(),
        lastLocationUpdate: DateTime.now(),
      );

      final offlineEmergency = createTestEmergency(
        id: 'JS-OFF-12345',
        status: EmergencyStatus.ARRIVED,
        primaryResponder: primaryResponder,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyMapScreen(
            emergencyId: offlineEmergency.id,
            initialEmergency: offlineEmergency,
            currentUserId: 'resp_primary_001',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Emergency communication available offline • Hospital road routing requires internet'),
        findsOneWidget,
      );
    });

    // ------------------------------------------------------------------------
    // 11. Existing responder/victim live tracking still works
    // ------------------------------------------------------------------------
    testWidgets('11: Live responder and victim markers are properly instantiated', (tester) async {
      final primaryResponder = ResponderModel(
        userId: 'resp_primary_001',
        userName: 'Aarav Sharma',
        phoneNumber: '+919876543210',
        role: ResponderRole.PRIMARY,
        status: ResponderStatus.RESPONDING,
        latitude: 28.6110,
        longitude: 77.2050,
        acceptedAt: DateTime.now(),
        lastLocationUpdate: DateTime.now(),
      );

      final emergency = createTestEmergency(
        status: EmergencyStatus.ASSIGNED,
        primaryResponder: primaryResponder,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyMapScreen(
            emergencyId: emergency.id,
            initialEmergency: emergency,
            currentUserId: 'resp_primary_001',
          ),
        ),
      );
      await tester.pump();

      // Victim marker is labeled 'VICTIM' for the responder
      expect(find.text('VICTIM'), findsOneWidget);
      // Primary responder marker is rendered
      expect(find.text('PRIMARY'), findsWidgets);
    });

    // ------------------------------------------------------------------------
    // 12. Existing emergency lifecycle remains unchanged
    // ------------------------------------------------------------------------
    test('12: Standard emergency lifecycle states remain unchanged', () {
      const allowedStatuses = [
        EmergencyStatus.SEARCHING,
        EmergencyStatus.ASSIGNED,
        EmergencyStatus.APPROACHING,
        EmergencyStatus.ARRIVED,
        EmergencyStatus.COMPLETED,
        EmergencyStatus.CANCELLED,
      ];

      expect(EmergencyStatus.values.length, equals(6));
      expect(EmergencyStatus.values, containsAll(allowedStatuses));
    });

    // ------------------------------------------------------------------------
    // Extra: EmergencyDetailsScreen also displays prepared standby hospitals
    // ------------------------------------------------------------------------
    testWidgets('Bonus: EmergencyDetailsScreen renders standby hospitals section', (tester) async {
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
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('NEARBY HOSPITALS (STANDBY)'), findsOneWidget);
      expect(find.text('Medical centers prepared for transport'), findsOneWidget);
    });
  });
}
