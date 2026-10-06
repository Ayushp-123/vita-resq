import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:jan_sarthi/core/theme/app_theme.dart';
import 'package:jan_sarthi/screens/home/home_screen.dart';
import 'package:jan_sarthi/models/communication_mode.dart';
import 'package:jan_sarthi/widgets/map_widget.dart';
import 'package:jan_sarthi/widgets/sos_button.dart';
import 'package:jan_sarthi/widgets/common/common.dart';

void main() {
  group('Vita ResQ Phase 2 — Home Screen Redesign Tests', () {
    final testPosition = Position(
      latitude: 28.6139,
      longitude: 77.2090,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

    testWidgets('3.1: HomeScreen renders locked structural order without overflow on compact 360dp phone', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
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
      // Ensure no clutter in header
      expect(find.byIcon(Icons.notifications_outlined), findsNothing);

      // 2. Status / Existing Context
      expect(find.textContaining('112'), findsWidgets);
      expect(find.textContaining('Citizen Responder'), findsOneWidget);

      // 3. Medium Live Map
      expect(find.byType(RealMapWidget), findsOneWidget);
      expect(find.byIcon(Icons.near_me_rounded), findsOneWidget); // Recenter button

      // 4. Emergency Help Prompt
      expect(find.text('Need emergency help?'), findsOneWidget);
      expect(find.textContaining('Hold the button below to dispatch an SOS'), findsOneWidget);

      // 5. Large Circular SOS
      expect(find.byType(SOSButton), findsOneWidget);
      expect(find.text('SOS'), findsOneWidget);
      expect(find.text('HOLD 2 SECONDS'), findsOneWidget);

      // 6. "Hold for help"
      expect(find.text('Hold for help'), findsOneWidget);
      expect(find.textContaining('Accidental taps ignored'), findsOneWidget);

      // 7. Bottom Navigation
      expect(find.byType(AppBottomNavBar), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Impact'), findsNothing);
    });

    testWidgets('3.2: Hamburger menu opens drawer correctly with helplines and controls', (tester) async {
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

      // Tap hamburger
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // Complete drawer slide animation

      // Verify drawer opened with branding and secondary navigation options
      expect(find.byType(Drawer), findsOneWidget);
      expect(find.text('EMERGENCY'), findsOneWidget);
      expect(find.text('Emergency Contacts'), findsOneWidget);
      expect(find.text('Crash Detection'), findsOneWidget);
    });

    testWidgets('3.3: Bottom navigation is locked to Home, History, Profile with full width', (tester) async {
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

      // Verify bottom nav is present and contains exactly the 3 locked tabs
      final bottomNavBarFinder = find.byType(AppBottomNavBar);
      expect(bottomNavBarFinder, findsOneWidget);

      final navBar = tester.widget<AppBottomNavBar>(bottomNavBarFinder);
      expect(navBar.currentIndex, 0); // Home selected

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Impact'), findsNothing);
    });

    testWidgets('3.4: Online collapsed state shows concise "Online" control without expanded technical details', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(
            initialPosition: testPosition,
            initialMode: CommunicationMode.online,
          ),
        ),
      );
      await tester.pump();

      // Collapsed Online status control is visible
      expect(find.text('Online'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);

      // Expanded details are NOT visible by default
      expect(find.text('Online Network'), findsNothing);
      expect(find.text('Emergency network connected.'), findsNothing);
      expect(find.text('Nearby responder discovery available.'), findsNothing);
      expect(find.text('Push notifications connected.'), findsNothing);
    });

    testWidgets('3.5: Online expanded state reveals network status upon tap and collapses on toggle', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(
            initialPosition: testPosition,
            initialMode: CommunicationMode.online,
          ),
        ),
      );
      await tester.pump();

      // Tap on the Online status control
      await tester.tap(find.text('Online'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250)); // Animation complete

      // Expanded state reveals concise user-facing benefits
      expect(find.text('Online Network'), findsOneWidget);
      expect(find.text('Emergency network connected.'), findsOneWidget);
      expect(find.text('Nearby responder discovery available.'), findsOneWidget);
      expect(find.text('Push notifications connected.'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);

      // Tap again to collapse
      await tester.tap(find.text('Online'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Online Network'), findsNothing);
      expect(find.text('Emergency network connected.'), findsNothing);
    });

    testWidgets('3.6: Offline collapsed state shows concise "Offline P2P" control with NO technical block visible by default', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(
            initialPosition: testPosition,
            initialMode: CommunicationMode.offline,
          ),
        ),
      );
      await tester.pump();

      // Small, non-intrusive collapsed status control
      expect(find.text('Offline P2P'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);

      // TECHNICAL DETAILS MUST NOT BE VISIBLE BY DEFAULT
      expect(find.text('Bluetooth Low Energy'), findsNothing);
      expect(find.text('Nearby P2P Discovery'), findsNothing);
      expect(find.text('Local Emergency Cache'), findsNothing);
      expect(find.text('Nearby emergency communication is available without internet.'), findsNothing);
      expect(find.text('Online map tiles and road routing require internet.'), findsNothing);
      expect(find.text('Bluetooth'), findsNothing);
      expect(find.text('Local cache'), findsNothing);
      expect(find.text('Firestore'), findsNothing);
      expect(find.text('FCM'), findsNothing);
    });

    testWidgets('3.7: Offline expanded state reveals readiness indicators upon tap and hides internal jargon', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(
            initialPosition: testPosition,
            initialMode: CommunicationMode.offline,
          ),
        ),
      );
      await tester.pump();

      // Tap on Offline P2P control
      await tester.tap(find.text('Offline P2P'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Expanded state reveals benefit and concise readiness indicators
      expect(find.text('Nearby emergency communication is available without internet.'), findsOneWidget);
      expect(find.text('Bluetooth'), findsOneWidget);
      expect(find.text('Nearby P2P'), findsOneWidget); // Readiness indicator
      expect(find.text('Local cache'), findsOneWidget);
      expect(find.text('Ready'), findsNWidgets(3));
      expect(find.text('Online map tiles and road routing require internet.'), findsOneWidget);

      // Verify no architecture jargon exposed
      expect(find.textContaining('Firestore'), findsNothing);
      expect(find.textContaining('FCM'), findsNothing);
      expect(find.textContaining('backend transport'), findsNothing);

      // Tap again to collapse
      await tester.tap(find.text('Offline P2P').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Nearby emergency communication is available without internet.'), findsNothing);
      expect(find.text('Bluetooth'), findsNothing);
    });

    testWidgets('3.8: Compact Android viewport (360x640) renders without RenderFlex overflow in collapsed and expanded states', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(
            initialPosition: testPosition,
            initialMode: CommunicationMode.offline,
          ),
        ),
      );
      await tester.pump();

      // Collapsed check
      expect(tester.takeException(), isNull);
      expect(find.text('Offline P2P'), findsOneWidget);

      // Expand
      await tester.tap(find.text('Offline P2P'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Expanded check on compact viewport
      expect(tester.takeException(), isNull);
      expect(find.text('Nearby emergency communication is available without internet.'), findsOneWidget);
    });
  });
}
