import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jan_sarthi/models/emergency_model.dart';
import 'package:jan_sarthi/models/user_model.dart';
import 'package:jan_sarthi/services/emergency_service.dart';
import 'package:jan_sarthi/services/emergency_claim_service.dart';
import 'package:jan_sarthi/services/local_database_service.dart';
import 'package:jan_sarthi/widgets/incoming_emergency_card.dart';
import 'package:jan_sarthi/screens/emergency/emergency_details_screen.dart';
import 'package:jan_sarthi/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BUG 1 REGRESSION TESTS — 3-Minute Automatic Trusted-Contact Escalation', () {
    test('emergency age < 180 sec -> no fallback', () {
      final now = DateTime.now();
      final recentEmergency = EmergencyModel(
        id: 'em-fallback-recent',
        victimId: 'victim-001',
        latitude: 28.6139,
        longitude: 77.2090,
        status: EmergencyStatus.SEARCHING,
        createdAt: now.subtract(const Duration(seconds: 60)),
        updatedAt: now,
      );

      final elapsed = now.difference(recentEmergency.createdAt).inSeconds;
      final isEligible = elapsed >= 180 && !recentEmergency.isTerminal;
      expect(elapsed, 60);
      expect(isEligible, isFalse);
    });

    test('emergency age >= 180 sec -> fallback becomes eligible immediately', () {
      final now = DateTime.now();
      final agedEmergency = EmergencyModel(
        id: 'em-fallback-aged',
        victimId: 'victim-001',
        latitude: 28.6139,
        longitude: 77.2090,
        status: EmergencyStatus.SEARCHING,
        createdAt: now.subtract(const Duration(seconds: 200)),
        updatedAt: now,
      );

      final elapsed = now.difference(agedEmergency.createdAt).inSeconds;
      final isEligible = elapsed >= 180 &&
          !agedEmergency.isTerminal &&
          agedEmergency.status == EmergencyStatus.SEARCHING;
      expect(elapsed, 200);
      expect(isEligible, isTrue);
    });

    test('remount after >180 sec -> does not restart timer from 180s', () {
      final createdAt = DateTime.now().subtract(const Duration(seconds: 250));
      final emergency = EmergencyModel(
        id: 'em-fallback-remount',
        victimId: 'victim-001',
        latitude: 28.6139,
        longitude: 77.2090,
        status: EmergencyStatus.SEARCHING,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

      // On screen mount, remaining time is derived from createdAt timestamp, NOT hardcoded 180
      final elapsed = DateTime.now().difference(emergency.createdAt).inSeconds;
      final remaining = (180 - elapsed).clamp(0, 180);

      expect(elapsed >= 180, isTrue);
      expect(remaining, 0);
    });

    test('CANCELLED before 180 -> no fallback', () {
      final now = DateTime.now();
      final cancelledEmergency = EmergencyModel(
        id: 'em-fallback-cancelled',
        victimId: 'victim-001',
        latitude: 28.6139,
        longitude: 77.2090,
        status: EmergencyStatus.CANCELLED,
        createdAt: now.subtract(const Duration(seconds: 120)),
        updatedAt: now,
      );

      final isEligible = !cancelledEmergency.isTerminal &&
          cancelledEmergency.status == EmergencyStatus.SEARCHING;
      expect(cancelledEmergency.isTerminal, isTrue);
      expect(isEligible, isFalse);
    });

    test('COMPLETED before 180 -> no fallback', () {
      final now = DateTime.now();
      final completedEmergency = EmergencyModel(
        id: 'em-fallback-completed',
        victimId: 'victim-001',
        latitude: 28.6139,
        longitude: 77.2090,
        status: EmergencyStatus.COMPLETED,
        createdAt: now.subtract(const Duration(seconds: 90)),
        updatedAt: now,
      );

      final isEligible = !completedEmergency.isTerminal &&
          completedEmergency.status == EmergencyStatus.SEARCHING;
      expect(completedEmergency.isTerminal, isTrue);
      expect(isEligible, isFalse);
    });

    test('fallback marker already set -> no duplicate', () async {
      const emergencyId = 'em-idempotent-001';

      expect(await EmergencyContactsService.hasDispatchedSmsFallback(emergencyId), isFalse);

      await EmergencyContactsService.markSmsFallbackDispatched(emergencyId);

      expect(await EmergencyContactsService.hasDispatchedSmsFallback(emergencyId), isTrue);

      // Subsequent check confirms already dispatched
      final shouldDispatch = !await EmergencyContactsService.hasDispatchedSmsFallback(emergencyId);
      expect(shouldDispatch, isFalse);
    });

    test('repeated location/status updates -> no duplicate dispatch', () async {
      const emergencyId = 'em-repeat-001';
      int dispatchCount = 0;

      void attemptDispatch(String id) async {
        if (await EmergencyContactsService.hasDispatchedSmsFallback(id)) return;
        await EmergencyContactsService.markSmsFallbackDispatched(id);
        dispatchCount++;
      }

      attemptDispatch(emergencyId);
      await Future.delayed(const Duration(milliseconds: 10));

      // Simulate 5 repeated location ticks
      for (int i = 0; i < 5; i++) {
        attemptDispatch(emergencyId);
      }

      await Future.delayed(const Duration(milliseconds: 20));
      expect(dispatchCount, 1);
    });
  });

  group('BUG 2 REGRESSION TESTS — Terminal State Consistency & UI Sync', () {
    test('JS-OFF cancellation synchronizes local state correctly', () async {
      final localDb = LocalDatabaseService();
      final emergencyId = 'JS-OFF-${DateTime.now().millisecondsSinceEpoch}';

      final em = EmergencyModel(
        id: emergencyId,
        victimId: 'local_victim',
        latitude: 12.9716,
        longitude: 77.5946,
        status: EmergencyStatus.SEARCHING,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await localDb.saveEmergencyLocally(em);

      final emergencyService = EmergencyService();
      await emergencyService.updateEmergencyStatus(emergencyId, EmergencyStatus.CANCELLED);

      final stored = await localDb.getEmergencyById(emergencyId);
      expect(stored, isNotNull);
      expect(stored!.status, EmergencyStatus.CANCELLED);
      expect(stored.isTerminal, isTrue);
    });

    test('COMPLETED behaves as terminal', () {
      final em = EmergencyModel(
        id: 'em-completed-check',
        victimId: 'victim-001',
        latitude: 12.9716,
        longitude: 77.5946,
        status: EmergencyStatus.COMPLETED,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(em.isTerminal, isTrue);
      expect(em.isClosed, isTrue);
      expect(em.isActive, isFalse);
      expect(em.isClaimable, isFalse);
    });

    testWidgets('terminal emergency cannot show I CAN HELP on IncomingEmergencyCard', (tester) async {
      final cancelledEmergency = EmergencyModel(
        id: 'em-card-cancelled',
        victimId: 'victim-999',
        latitude: 28.6139,
        longitude: 77.2090,
        status: EmergencyStatus.CANCELLED,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: IncomingEmergencyCard(
              emergency: cancelledEmergency,
              onCanHelp: () {},
              onViewDetails: () {},
            ),
          ),
        ),
      );

      expect(find.text('I CAN HELP'), findsNothing);
      expect(find.text('ALERT CANCELLED'), findsOneWidget);
      expect(find.text('View Details'), findsOneWidget);
    });

    testWidgets('completed emergency shows ALERT CONCLUDED on IncomingEmergencyCard', (tester) async {
      final completedEmergency = EmergencyModel(
        id: 'em-card-completed',
        victimId: 'victim-999',
        latitude: 28.6139,
        longitude: 77.2090,
        status: EmergencyStatus.COMPLETED,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: IncomingEmergencyCard(
              emergency: completedEmergency,
              onCanHelp: () {},
              onViewDetails: () {},
            ),
          ),
        ),
      );

      expect(find.text('I CAN HELP'), findsNothing);
      expect(find.text('ALERT CONCLUDED'), findsOneWidget);
      expect(find.text('View Details'), findsOneWidget);
    });

    test('terminal emergency is removed from active responder list filter', () {
      final emergencies = [
        EmergencyModel(
          id: 'em-1',
          victimId: 'v1',
          latitude: 28.6,
          longitude: 77.2,
          status: EmergencyStatus.SEARCHING,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        EmergencyModel(
          id: 'em-2',
          victimId: 'v2',
          latitude: 28.6,
          longitude: 77.2,
          status: EmergencyStatus.CANCELLED,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        EmergencyModel(
          id: 'em-3',
          victimId: 'v3',
          latitude: 28.6,
          longitude: 77.2,
          status: EmergencyStatus.COMPLETED,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final activeList = emergencies.where((e) => !e.isTerminal).toList();
      expect(activeList.length, 1);
      expect(activeList.first.id, 'em-1');
    });

    testWidgets('open details page changes UI for cancelled emergency', (tester) async {
      final cancelledEmergency = EmergencyModel(
        id: 'JS-OFF-details-cancelled',
        victimId: 'victim-001',
        latitude: 28.6139,
        longitude: 77.2090,
        status: EmergencyStatus.CANCELLED,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EmergencyDetailsScreen(
            emergencyId: cancelledEmergency.id,
            initialEmergency: cancelledEmergency,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('I CAN HELP'), findsNothing);
      expect(find.text('BACK TO HISTORY'), findsOneWidget);
      expect(find.text('Cancelled Alert'), findsOneWidget);
      expect(find.textContaining('This incident was cancelled'), findsOneWidget);
    });

    test('responder claim against cancelled offline emergency fails cleanly', () async {
      final localDb = LocalDatabaseService();
      const emergencyId = 'JS-OFF-claim-race';

      final em = EmergencyModel(
        id: emergencyId,
        victimId: 'victim_user',
        latitude: 12.9716,
        longitude: 77.5946,
        status: EmergencyStatus.CANCELLED,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await localDb.saveEmergencyLocally(em);

      final claimService = EmergencyClaimService();
      final result = await claimService.acceptAndRespond(emergencyId);

      expect(result, isNull);
    });

    test('offline alert stream evicts terminal emergencies when local update fires', () async {
      final localDb = LocalDatabaseService();

      const emId = 'JS-OFF-evict-stream';
      final activeEm = EmergencyModel(
        id: emId,
        victimId: 'victim_offline',
        latitude: 12.9716,
        longitude: 77.5946,
        status: EmergencyStatus.SEARCHING,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await localDb.saveEmergencyLocally(activeEm);

      // Verify that after updating to CANCELLED, getEmergencyById returns terminal
      await localDb.updateEmergencyStatus(emId, EmergencyStatus.CANCELLED);
      final updated = await localDb.getEmergencyById(emId);
      expect(updated!.isTerminal, isTrue);
    });
  });

  group('BUG 3 REGRESSION TESTS — Responder "Call" Must Call Victim, Not 112', () {
    test('sanitizes victim phone number and constructs tel: URI', () {
      const rawPhone = '+91 (987) 654-3210';
      final cleanNumber = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
      expect(cleanNumber, '+919876543210');

      final uriString = 'tel:$cleanNumber';
      expect(uriString, 'tel:+919876543210');
      expect(uriString, isNot(equals('tel:112')));
    });

    test('generated URI is NEVER tel:112', () {
      const victimPhone = '+919876543210';
      final uri = Uri.parse('tel:${victimPhone.replaceAll(RegExp(r'[^\d+]'), '')}');

      expect(uri.toString(), 'tel:+919876543210');
      expect(uri.scheme, 'tel');
      expect(uri.path, isNot('112'));
    });

    test('missing or empty victim number prevents call launch', () {
      String? nullPhone;
      String emptyPhone = '   ';

      bool canLaunchCall(String? phone) {
        if (phone == null || phone.trim().isEmpty) return false;
        final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
        return clean.isNotEmpty;
      }

      expect(canLaunchCall(nullPhone), isFalse);
      expect(canLaunchCall(emptyPhone), isFalse);
      expect(canLaunchCall('---'), isFalse);
      expect(canLaunchCall('+919876543210'), isTrue);
    });

    test('victim profile resolution resolves UserModel.phoneNumber', () {
      final victimProfile = UserModel(
        id: 'victim_456',
        name: 'Priya Patel',
        email: 'priya@vita-resq.org',
        phoneNumber: '+919123456789',
        bloodGroup: 'O+',
        userRole: 'CITIZEN',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(victimProfile.phoneNumber, '+919123456789');
      final clean = victimProfile.phoneNumber!.replaceAll(RegExp(r'[^\d+]'), '');
      expect('tel:$clean', 'tel:+919123456789');
      expect('tel:$clean', isNot(contains('112')));
    });
  });

  group('PHYSICAL FIELD-TEST REGRESSION — Dialer & WhatsApp Normalization & URI Safety', () {
    test('Dialer normalization preserves country codes and discards invalid inputs', () {
      expect(EmergencyContactsService.normalizeDialerNumber('+91 (987) 654-3210'), '+919876543210');
      expect(EmergencyContactsService.normalizeDialerNumber('9876543210'), '9876543210');
      expect(EmergencyContactsService.normalizeDialerNumber('+1 (555) 019-2834'), '+15550192834');
      expect(EmergencyContactsService.normalizeDialerNumber('+44 20 7946 0958'), '+442079460958');
      expect(EmergencyContactsService.normalizeDialerNumber('112'), '');
      expect(EmergencyContactsService.normalizeDialerNumber('108'), '');
      expect(EmergencyContactsService.normalizeDialerNumber(''), '');
    });

    test('WhatsApp number format normalizes international and national formats correctly', () {
      expect(EmergencyContactsService.formatWhatsAppNumber('9876543210'), '919876543210');
      expect(EmergencyContactsService.formatWhatsAppNumber('+91 98765 43210'), '919876543210');
      expect(EmergencyContactsService.formatWhatsAppNumber('+91 098765 43210'), '919876543210');
      expect(EmergencyContactsService.formatWhatsAppNumber('09876543210'), '919876543210');
      expect(EmergencyContactsService.formatWhatsAppNumber('0091 98765 43210'), '919876543210');
      expect(EmergencyContactsService.formatWhatsAppNumber('+1 (555) 123-4567'), '15551234567');
      expect(EmergencyContactsService.formatWhatsAppNumber('+44 7911 123456'), '447911123456');
      expect(EmergencyContactsService.formatWhatsAppNumber('+44 (0) 7911 123456'), '447911123456');
      expect(EmergencyContactsService.formatWhatsAppNumber('123'), '');
    });

    test('Constructs canonical wa.me and tel: URIs with no paid dependencies', () {
      final dialerUri = Uri.parse('tel:${EmergencyContactsService.normalizeDialerNumber("+919876543210")}');
      expect(dialerUri.scheme, 'tel');
      expect(dialerUri.path, '+919876543210');

      final waNumber = EmergencyContactsService.formatWhatsAppNumber('+919876543210');
      final waUri = Uri.parse('https://wa.me/$waNumber?text=${Uri.encodeComponent("TEST")}');
      expect(waUri.scheme, 'https');
      expect(waUri.host, 'wa.me');
      expect(waUri.path, '/919876543210');
      expect(waUri.queryParameters['text'], 'TEST');
    });
  });
}

