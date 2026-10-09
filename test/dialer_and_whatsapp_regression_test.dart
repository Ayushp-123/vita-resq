import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/link.dart';

import 'package:jan_sarthi/models/responder_model.dart';
import 'package:jan_sarthi/models/user_model.dart';
import 'package:jan_sarthi/services/emergency_service.dart';
import 'package:jan_sarthi/widgets/responder_profile_card.dart';

/// Test mock implementation of [UrlLauncherPlatform]
class MockUrlLauncherPlatform extends UrlLauncherPlatform {
  String? launchedUrl;
  LaunchOptions? launchedOptions;
  bool canLaunchResult = true;
  bool launchResult = true;
  int launchCallCount = 0;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => canLaunchResult;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrl = url;
    launchedOptions = options;
    launchCallCount++;
    return launchResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockUrlLauncherPlatform mockUrlLauncher;
  UrlLauncherPlatform? originalPlatform;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    originalPlatform = UrlLauncherPlatform.instance;
    mockUrlLauncher = MockUrlLauncherPlatform();
    UrlLauncherPlatform.instance = mockUrlLauncher;
  });

  tearDown(() {
    if (originalPlatform != null) {
      UrlLauncherPlatform.instance = originalPlatform!;
    }
  });

  // =========================================================================
  // GROUP 1: BUG 1 — PHONE DIALER NORMALIZATION & SAFETY TESTS
  // =========================================================================
  group('BUG 1 — Phone Dialer Normalization & Intent Construction', () {
    test('normalizes Indian phone number with leading +91 correctly', () {
      final normalized = EmergencyContactsService.normalizeDialerNumber('+91 (987) 654-3210');
      expect(normalized, '+919876543210');
      expect(normalized, isNot(contains('112')));
    });

    test('preserves national 10-digit number without corrupting it', () {
      final normalized = EmergencyContactsService.normalizeDialerNumber('9876543210');
      expect(normalized, '9876543210');
      expect(normalized, isNot(startsWith('+')));
    });

    test('preserves international country code with + intact', () {
      expect(EmergencyContactsService.normalizeDialerNumber('+1 (555) 123-4567'), '+15551234567');
      expect(EmergencyContactsService.normalizeDialerNumber('+44 20 7946 0958'), '+442079460958');
      expect(EmergencyContactsService.normalizeDialerNumber('+61 412 345 678'), '+61412345678');
    });

    test('rejects numbers shorter than 7 digits (including emergency numbers)', () {
      expect(EmergencyContactsService.normalizeDialerNumber('112'), '');
      expect(EmergencyContactsService.normalizeDialerNumber('911'), '');
      expect(EmergencyContactsService.normalizeDialerNumber('108'), '');
      expect(EmergencyContactsService.normalizeDialerNumber('100'), '');
      expect(EmergencyContactsService.normalizeDialerNumber('101'), '');
      expect(EmergencyContactsService.normalizeDialerNumber('12345'), '');
      expect(EmergencyContactsService.normalizeDialerNumber(''), '');
      expect(EmergencyContactsService.normalizeDialerNumber('   '), '');
      expect(EmergencyContactsService.normalizeDialerNumber('---'), '');
    });

    test('never constructs tel:112 or emergency helpline URI', () {
      final clean = EmergencyContactsService.normalizeDialerNumber('112');
      expect(clean, isEmpty);

      final cleanWithPlus = EmergencyContactsService.normalizeDialerNumber('+112');
      expect(cleanWithPlus, isEmpty);
    });

    test('launchDialer constructs correct tel: URI and invokes system dialer', () async {
      final result = await EmergencyContactsService.launchDialer('+91 98765 43210');

      expect(result, isTrue);
      expect(mockUrlLauncher.launchedUrl, 'tel:+919876543210');
      expect(mockUrlLauncher.launchedOptions?.mode, PreferredLaunchMode.externalApplication);
      expect(mockUrlLauncher.launchCallCount, 1);
    });

    test('launchDialer returns false and does not launch URI for invalid numbers', () async {
      final result1 = await EmergencyContactsService.launchDialer('112');
      expect(result1, isFalse);
      expect(mockUrlLauncher.launchCallCount, 0);

      final result2 = await EmergencyContactsService.launchDialer('');
      expect(result2, isFalse);
      expect(mockUrlLauncher.launchCallCount, 0);

      final result3 = await EmergencyContactsService.launchDialer('invalid-phone');
      expect(result3, isFalse);
      expect(mockUrlLauncher.launchCallCount, 0);
    });

    test('launchDialer returns false when system dialer cannot be opened', () async {
      mockUrlLauncher.canLaunchResult = false;
      mockUrlLauncher.launchResult = false;

      final result = await EmergencyContactsService.launchDialer('+91 98765 43210');
      expect(result, isFalse);
    });
  });

  // =========================================================================
  // GROUP 2: BUG 1 — COUNTERPART RESOLUTION & PROFILE CARD FALLBACK
  // =========================================================================
  group('BUG 1 — Counterpart Contact Resolution & UI Fallback', () {
    test('victim profile resolution resolves UserModel.phoneNumber', () {
      final victim = UserModel(
        id: 'victim_test_01',
        name: 'Anita Verma',
        email: 'anita@test.org',
        phoneNumber: '+919876501234',
        bloodGroup: 'B+',
        userRole: 'CITIZEN',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(victim.phoneNumber, '+919876501234');
      final dialerNumber = EmergencyContactsService.normalizeDialerNumber(victim.phoneNumber!);
      expect(dialerNumber, '+919876501234');
      expect('tel:$dialerNumber', 'tel:+919876501234');
    });

    test('responder model resolves stored phone number', () {
      final responder = ResponderModel(
        userId: 'resp_test_01',
        userName: 'Officer Kumar',
        phoneNumber: '+919876599999',
        userRole: 'POLICE_PCR',
        role: ResponderRole.PRIMARY,
        status: ResponderStatus.RESPONDING,
        latitude: 21.2253,
        longitude: 81.3107,
        acceptedAt: DateTime.now(),
        lastLocationUpdate: DateTime.now(),
      );

      expect(responder.phoneNumber, '+919876599999');
      final dialerNumber = EmergencyContactsService.normalizeDialerNumber(responder.phoneNumber!);
      expect(dialerNumber, '+919876599999');
      expect('tel:$dialerNumber', 'tel:+919876599999');
    });

    testWidgets('ResponderProfileCard tap opens dialer with counterpart number', (tester) async {
      final responder = ResponderModel(
        userId: 'resp_test_02',
        userName: 'Dr. Sameer',
        phoneNumber: '+919811122233',
        userRole: 'AMBULANCE_DRIVER',
        role: ResponderRole.PRIMARY,
        status: ResponderStatus.RESPONDING,
        latitude: 21.2253,
        longitude: 81.3107,
        acceptedAt: DateTime.now(),
        lastLocationUpdate: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponderProfileCard(responder: responder),
          ),
        ),
      );

      // Tap phone call button
      final callButton = find.byIcon(Icons.phone_rounded);
      expect(callButton, findsOneWidget);
      await tester.tap(callButton);
      await tester.pumpAndSettle();

      expect(mockUrlLauncher.launchedUrl, 'tel:+919811122233');
      expect(mockUrlLauncher.launchCallCount, 1);
    });

    testWidgets('ResponderProfileCard displays COPY NUMBER fallback when dialer fails', (tester) async {
      mockUrlLauncher.canLaunchResult = false;
      mockUrlLauncher.launchResult = false;

      final responder = ResponderModel(
        userId: 'resp_test_03',
        userName: 'Officer Sharma',
        phoneNumber: '+919899988877',
        userRole: 'POLICE_PCR',
        role: ResponderRole.PRIMARY,
        status: ResponderStatus.RESPONDING,
        latitude: 21.2253,
        longitude: 81.3107,
        acceptedAt: DateTime.now(),
        lastLocationUpdate: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponderProfileCard(responder: responder),
          ),
        ),
      );

      final callButton = find.byIcon(Icons.phone_rounded);
      await tester.tap(callButton);
      await tester.pumpAndSettle();

      // Fallback dialog must show Officer Sharma (in card & dialog), the phone number, and a COPY NUMBER button
      expect(find.text('Officer Sharma'), findsNWidgets(2));
      expect(find.text('+919899988877'), findsOneWidget);
      expect(find.text('COPY NUMBER'), findsOneWidget);
      expect(find.text('CLOSE'), findsOneWidget);
    });
  });

  // =========================================================================
  // GROUP 3: BUG 2 — WHATSAPP NUMBER NORMALIZATION & INTERNATIONAL SUPPORT
  // =========================================================================
  group('BUG 2 — WhatsApp Number Normalization & International Format', () {
    test('10-digit Indian national number is prefixed with 91 without plus or zeroes', () {
      final formatted = EmergencyContactsService.formatWhatsAppNumber('9876543210');
      expect(formatted, '919876543210');
      expect(formatted, isNot(startsWith('+')));
      expect(formatted, isNot(startsWith('0')));
    });

    test('already formatted +91 number does not duplicate country code', () {
      final formatted = EmergencyContactsService.formatWhatsAppNumber('+91 98765 43210');
      expect(formatted, '919876543210');
      expect(formatted, isNot(startsWith('9191')));
    });

    test('strips trunk 0 after +91 country code (+91 09876543210)', () {
      final formatted = EmergencyContactsService.formatWhatsAppNumber('+91 09876543210');
      expect(formatted, '919876543210');
      expect(formatted.length, 12);
    });

    test('strips single leading national trunk 0 (09876543210)', () {
      final formatted = EmergencyContactsService.formatWhatsAppNumber('09876543210');
      expect(formatted, '919876543210');
      expect(formatted, isNot(startsWith('0')));
    });

    test('strips international prefix 00 (0091 98765 43210)', () {
      final formatted = EmergencyContactsService.formatWhatsAppNumber('0091 98765 43210');
      expect(formatted, '919876543210');
      expect(formatted, isNot(startsWith('00')));
    });

    test('preserves valid international numbers without corrupting them with 91', () {
      // US (+1)
      expect(EmergencyContactsService.formatWhatsAppNumber('+1 (555) 123-4567'), '15551234567');

      // UK (+44)
      expect(EmergencyContactsService.formatWhatsAppNumber('+44 7911 123456'), '447911123456');

      // UK with trunk 0 (+44 (0) 7911 123456)
      expect(EmergencyContactsService.formatWhatsAppNumber('+44 (0) 7911 123456'), '447911123456');

      // Australia (+61)
      expect(EmergencyContactsService.formatWhatsAppNumber('+61 412 345 678'), '61412345678');

      // UAE (+971)
      expect(EmergencyContactsService.formatWhatsAppNumber('+971 50 123 4567'), '971501234567');
    });

    test('rejects invalid or too-short numbers by returning empty string', () {
      expect(EmergencyContactsService.formatWhatsAppNumber('12345'), '');
      expect(EmergencyContactsService.formatWhatsAppNumber(''), '');
      expect(EmergencyContactsService.formatWhatsAppNumber('   '), '');
      expect(EmergencyContactsService.formatWhatsAppNumber('abc'), '');
      expect(EmergencyContactsService.formatWhatsAppNumber('!@#\$%^&*()'), '');
    });
  });

  // =========================================================================
  // GROUP 4: BUG 2 — WHATSAPP DEEP LINK GENERATION & LAUNCH
  // =========================================================================
  group('BUG 2 — WhatsApp Deep Link Generation & Launch Strategy', () {
    test('sendEmergencyWhatsApp generates wa.me universal link as primary target', () async {
      final service = EmergencyContactsService();
      await service.saveContacts([
        EmergencyContact(name: 'Rahul', phoneNumber: '+919876543210', relationship: 'Brother'),
      ]);

      final success = await service.sendEmergencyWhatsApp(
        latitude: 28.6139,
        longitude: 77.2090,
        type: 'MEDICAL',
      );

      expect(success, isTrue);
      expect(mockUrlLauncher.launchedUrl, startsWith('https://wa.me/919876543210?text='));
      expect(mockUrlLauncher.launchedUrl, contains('maps.google.com'));
      expect(mockUrlLauncher.launchedOptions?.mode, PreferredLaunchMode.externalApplication);
    });

    test('sendEmergencyWhatsApp handles specific phone number parameter', () async {
      final service = EmergencyContactsService();
      await service.saveContacts([
        EmergencyContact(name: 'Mom', phoneNumber: '+919876500001', relationship: 'Mother'),
        EmergencyContact(name: 'Dad', phoneNumber: '+919876500002', relationship: 'Father'),
      ]);

      final success = await service.sendEmergencyWhatsApp(
        latitude: 28.6139,
        longitude: 77.2090,
        type: 'ACCIDENT',
        specificPhoneNumber: '+919876500002',
      );

      expect(success, isTrue);
      expect(mockUrlLauncher.launchedUrl, startsWith('https://wa.me/919876500002?text='));
    });

    test('sendEmergencyWhatsApp fails gracefully if target number is invalid', () async {
      final service = EmergencyContactsService();
      await service.saveContacts([
        EmergencyContact(name: 'Bad Contact', phoneNumber: '123', relationship: 'Unknown'),
      ]);

      final success = await service.sendEmergencyWhatsApp(
        latitude: 28.6139,
        longitude: 77.2090,
        specificPhoneNumber: '123',
      );

      expect(success, isFalse);
      expect(mockUrlLauncher.launchCallCount, 0);
    });

    test('sendEmergencyWhatsApp returns false if WhatsApp is not installed on device', () async {
      mockUrlLauncher.canLaunchResult = false;
      mockUrlLauncher.launchResult = false;

      final service = EmergencyContactsService();
      await service.saveContacts([
        EmergencyContact(name: 'Rahul', phoneNumber: '+919876543210', relationship: 'Brother'),
      ]);

      final success = await service.sendEmergencyWhatsApp(
        latitude: 28.6139,
        longitude: 77.2090,
      );

      expect(success, isFalse);
    });
  });

  // =========================================================================
  // GROUP 5: BUG 2 — SMS FALLBACK INTEGRITY & ZERO PAID DEPENDENCIES
  // =========================================================================
  group('BUG 2 — SMS Fallback Integrity & Zero Paid Dependencies', () {
    test('SMS URI uses standard intent-based scheme without requiring dangerous permissions', () {
      final uri = EmergencyContactsService.buildSmsUri(
        phoneNumbers: ['919876543210'],
        message: 'TEST ALERT',
        isIOS: false,
      );

      expect(uri.scheme, 'sms');
      expect(uri.path, '919876543210');
      expect(uri.queryParameters['body'], 'TEST ALERT');
      // Proves no paid API gateway is being invoked
      expect(uri.host, isEmpty);
    });

    test('sendEmergencySMS opens system SMS composer with pre-filled coordinates', () async {
      final service = EmergencyContactsService();
      await service.saveContacts([
        EmergencyContact(name: 'Aunt', phoneNumber: '+919876543210', relationship: 'Family'),
      ]);

      final result = await service.sendEmergencySMS(
        latitude: 21.2253,
        longitude: 81.3107,
        type: 'SOS',
      );

      expect(result, isTrue);
      expect(mockUrlLauncher.launchedUrl, startsWith('sms:'));
      expect(mockUrlLauncher.launchedUrl, contains('maps.google.com'));
      expect(mockUrlLauncher.launchedOptions?.mode, PreferredLaunchMode.externalApplication);
    });
  });
}
