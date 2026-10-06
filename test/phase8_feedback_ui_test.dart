import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jan_sarthi/core/theme/app_theme.dart';
import 'package:jan_sarthi/models/emergency_model.dart';
import 'package:jan_sarthi/models/communication_mode.dart';
import 'package:jan_sarthi/services/notification_service.dart';
import 'package:jan_sarthi/widgets/common/app_feedback.dart';
import 'package:jan_sarthi/widgets/app_dialogs.dart';
import 'package:jan_sarthi/widgets/accident_detection_dialog.dart';
import 'package:jan_sarthi/widgets/permission_request_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testEmergency = EmergencyModel(
    id: 'emg-phase8-01',
    victimId: 'victim-01',
    latitude: 21.2253,
    longitude: 81.3107,
    status: EmergencyStatus.SEARCHING,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    type: 'Medical',
    currentRadiusMeters: 1500,
  );

  group('Phase 8: Notifications & Global Feedback UX', () {
    // -------------------------------------------------------------
    // 8.1 Emergency alert presentation
    // -------------------------------------------------------------
    test('8.1.1: EmergencyAlertPresentation formats clean, non-technical titles and bodies', () {
      // Victim perspectives
      expect(
        EmergencyAlertPresentation.formatTitle(role: 'VICTIM', status: EmergencyStatus.SEARCHING),
        'Help request active',
      );
      expect(
        EmergencyAlertPresentation.formatTitle(role: 'VICTIM', status: EmergencyStatus.ASSIGNED),
        'Responder on the way',
      );
      expect(
        EmergencyAlertPresentation.formatTitle(role: 'VICTIM', status: EmergencyStatus.ARRIVED),
        'Responder has arrived',
      );
      expect(
        EmergencyAlertPresentation.formatTitle(role: 'VICTIM', status: EmergencyStatus.COMPLETED),
        'Emergency completed',
      );

      // Responder perspectives
      expect(
        EmergencyAlertPresentation.formatTitle(role: 'RESPONDER', status: EmergencyStatus.SEARCHING),
        'New emergency nearby',
      );
      expect(
        EmergencyAlertPresentation.formatTitle(role: 'RESPONDER', status: EmergencyStatus.ASSIGNED),
        "You're responding",
      );
      expect(
        EmergencyAlertPresentation.formatTitle(role: 'RESPONDER', status: EmergencyStatus.ARRIVED),
        "You've arrived",
      );

      // Body copy sanity
      final body = EmergencyAlertPresentation.formatBody(
        role: 'RESPONDER',
        status: EmergencyStatus.SEARCHING,
      );
      expect(body, contains('Someone nearby needs emergency assistance.'));
      expect(body.contains('Exception'), isFalse);
      expect(body.contains('status='), isFalse);
    });

    testWidgets('8.1.2: Nearby emergency dialog renders human alert hierarchy and >=48dp targets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  AppDialogs.showNearbyEmergencyDialog(
                    context: ctx,
                    emergency: testEmergency,
                    mode: CommunicationMode.online,
                    userRole: 'CITIZEN',
                    onViewEmergency: () {},
                  );
                },
                child: const Text('Trigger Alert'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Alert'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('NEARBY EMERGENCY ALERT'), findsOneWidget);
      expect(find.text('Someone nearby needs urgent assistance.'), findsOneWidget);
      expect(find.textContaining('1.5 km'), findsOneWidget);
      expect(find.text('VIEW EMERGENCY'), findsOneWidget);
      expect(find.text('DECLINE / DISMISS'), findsOneWidget);

      final viewBtn = tester.getRect(find.ancestor(of: find.text('VIEW EMERGENCY'), matching: find.byType(ElevatedButton)));
      expect(viewBtn.height, greaterThanOrEqualTo(48.0));
    });

    // -------------------------------------------------------------
    // 8.2 Crash warning UI
    // -------------------------------------------------------------
    testWidgets('8.2: Crash warning UI presents POSSIBLE CRASH DETECTED, Are you okay?, [ I\'M OKAY ]', (tester) async {
      bool cancelTapped = false;
      bool autoTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AccidentDetectionDialog(
              reasoning: 'G-Force Spike: 4.8G impact detected',
              onCancel: () => cancelTapped = true,
              onConfirmAutoSOS: () => autoTriggered = true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Safety-critical wording
      expect(find.text('POSSIBLE CRASH DETECTED'), findsOneWidget);
      expect(find.text('Are you okay?'), findsOneWidget);
      expect(find.textContaining('Sensors detected a sudden hard impact'), findsOneWidget);

      // Countdown elements
      expect(find.text('15'), findsOneWidget);
      expect(find.text('SECONDS'), findsOneWidget);

      // Primary prominent action
      final okayButtonFinder = find.ancestor(
        of: find.text("I'M OKAY"),
        matching: find.byType(ElevatedButton),
      );
      expect(okayButtonFinder, findsOneWidget);
      final okayRect = tester.getRect(okayButtonFinder);
      expect(okayRect.height, greaterThanOrEqualTo(54.0));

      // Secondary action
      final sosButtonFinder = find.ancestor(
        of: find.text('DISPATCH SOS NOW'),
        matching: find.byType(OutlinedButton),
      );
      expect(sosButtonFinder, findsOneWidget);
      final sosRect = tester.getRect(sosButtonFinder);
      expect(sosRect.height, greaterThanOrEqualTo(48.0));

      // Tap safe button
      await tester.tap(find.text("I'M OKAY"));
      await tester.pump(const Duration(milliseconds: 100));
      expect(cancelTapped, isTrue);
      expect(autoTriggered, isFalse);
    });

    // -------------------------------------------------------------
    // 8.3 SOS confirmation
    // -------------------------------------------------------------
    testWidgets('8.3: SOS confirmation bottom sheet presents 5-second countdown with clear cancel option', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  AppDialogs.showSOSConfirmationBottomSheet(
                    context: ctx,
                    currentAddress: 'Sector 6, Bhilai',
                    isOnline: true,
                    onConfirmSOS: () {},
                  );
                },
                child: const Text('Open SOS Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open SOS Sheet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('DISPATCHING EMERGENCY SOS'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('SEC'), findsOneWidget);

      final cancelBtnFinder = find.ancestor(
        of: find.text('CANCEL SOS (FALSE ALARM)'),
        matching: find.byType(ElevatedButton),
      );
      expect(cancelBtnFinder, findsOneWidget);
      expect(tester.getRect(cancelBtnFinder).height, greaterThanOrEqualTo(52.0));

      final sendNowFinder = find.ancestor(
        of: find.text('SEND IMMEDIATELY'),
        matching: find.byType(OutlinedButton),
      );
      expect(sendNowFinder, findsOneWidget);
      expect(tester.getRect(sendNowFinder).height, greaterThanOrEqualTo(48.0));
    });

    // -------------------------------------------------------------
    // 8.4 Cancel emergency dialog & destructive action hierarchy
    // -------------------------------------------------------------
    testWidgets('8.4: Cancel emergency dialog prioritizes keeping emergency active as primary action', (tester) async {
      bool cancelConfirmed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  AppDialogs.showCancelEmergencyDialog(
                    context: ctx,
                    onConfirmCancel: () => cancelConfirmed = true,
                  );
                },
                child: const Text('Cancel SOS'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Cancel SOS'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel emergency?'), findsOneWidget);
      expect(find.text('Are you sure you no longer need help? Responders will be notified.'), findsOneWidget);

      // Safe option should be the prominent ElevatedButton
      final keepActiveFinder = find.ancestor(
        of: find.text('Keep Emergency Active'),
        matching: find.byType(ElevatedButton),
      );
      expect(keepActiveFinder, findsOneWidget);

      // Destructive option should be the OutlinedButton
      final confirmCancelFinder = find.ancestor(
        of: find.text('Cancel Emergency'),
        matching: find.byType(OutlinedButton),
      );
      expect(confirmCancelFinder, findsOneWidget);

      // Both >= 48dp
      expect(tester.getRect(keepActiveFinder).height, greaterThanOrEqualTo(48.0));
      expect(tester.getRect(confirmCancelFinder).height, greaterThanOrEqualTo(48.0));

      // Tapping Keep Emergency Active dismisses without calling onConfirmCancel
      await tester.tap(find.text('Keep Emergency Active'));
      await tester.pumpAndSettle();
      expect(cancelConfirmed, isFalse);
    });

    // -------------------------------------------------------------
    // 8.5 Snackbar styling & content
    // -------------------------------------------------------------
    testWidgets('8.5: AppSnackbar provides non-stacking floating feedback without tech errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Column(
                children: [
                  ElevatedButton(
                    onPressed: () => AppSnackbar.showSuccess(ctx, 'Profile updated.'),
                    child: const Text('Show Success'),
                  ),
                  ElevatedButton(
                    onPressed: () => AppSnackbar.showError(ctx, "Couldn't connect right now."),
                    child: const Text('Show Error'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // 1. Show success snackbar
      await tester.tap(find.text('Show Success'));
      await tester.pump();
      expect(find.text('Profile updated.'), findsOneWidget);

      // 2. Show error snackbar - hides previous and renders new
      await tester.tap(find.text('Show Error'));
      await tester.pump();
      expect(find.text("Couldn't connect right now."), findsOneWidget);
      expect(find.text('Profile updated.'), findsNothing);
    });

    // -------------------------------------------------------------
    // 8.6 Loading state
    // -------------------------------------------------------------
    testWidgets('8.6: AppLoadingState renders clean progress indicator with contextual message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppLoadingState(message: 'Finding nearby help…'),
          ),
        ),
      );

      expect(find.text('Finding nearby help…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    // -------------------------------------------------------------
    // 8.7 Error state
    // -------------------------------------------------------------
    testWidgets('8.7: AppErrorState renders plain English message with recovery action', (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorState(
              title: "Couldn't update your profile",
              message: 'Check your internet connection and try again.',
              buttonText: 'Try Again',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text("Couldn't update your profile"), findsOneWidget);
      expect(find.text('Check your internet connection and try again.'), findsOneWidget);

      final retryButton = find.text('Try Again');
      expect(retryButton, findsOneWidget);
      await tester.tap(retryButton);
      expect(retried, isTrue);
    });

    // -------------------------------------------------------------
    // 8.8 Offline/Online messaging
    // -------------------------------------------------------------
    testWidgets('8.8: AppFeedbackBanner presents clear status without network diagnostic clutter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppFeedbackBanner(
                  status: AppStatusType.online,
                  title: 'Online',
                  message: 'Connected to live cloud emergency dispatch.',
                ),
                AppFeedbackBanner(
                  status: AppStatusType.offline,
                  title: 'Offline rescue mode',
                  message: 'Peer-to-peer mesh enabled. Nearby devices can still receive your SOS.',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Offline rescue mode'), findsOneWidget);
      expect(find.textContaining('Peer-to-peer mesh enabled'), findsOneWidget);
      expect(find.textContaining('SocketException'), findsNothing);
    });

    // -------------------------------------------------------------
    // 8.9 Empty state
    // -------------------------------------------------------------
    testWidgets('8.9: AppEmptyState communicates clear title, human explanation, and next step', (tester) async {
      bool actionTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppEmptyState(
              icon: Icons.contacts_outlined,
              title: 'No emergency contacts',
              message: 'Add trusted contacts who should receive automatic SMS alerts.',
              actionLabel: 'Add Contact',
              onAction: () => actionTriggered = true,
            ),
          ),
        ),
      );

      expect(find.text('No emergency contacts'), findsOneWidget);
      expect(find.text('Add trusted contacts who should receive automatic SMS alerts.'), findsOneWidget);
      expect(find.text('Add Contact'), findsOneWidget);

      await tester.tap(find.text('Add Contact'));
      expect(actionTriggered, isTrue);
    });

    // -------------------------------------------------------------
    // 8.10 Compact viewport responsiveness
    // -------------------------------------------------------------
    testWidgets('8.10: Feedback components render without RenderFlex overflow on 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const AppFeedbackBanner(
                    status: AppStatusType.warning,
                    title: 'Location Signal Low',
                    message: 'Move closer to an open area with clear sky view.',
                    actionLabel: 'Refresh GPS',
                  ),
                  PermissionRequestDialog(onPermissionsGranted: () {}),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Location Access'), findsOneWidget);
      expect(find.text('Emergency Alerts'), findsOneWidget);
      expect(find.text('Nearby Connectivity'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // 8.11 Accessibility & touch target expectations
    // -------------------------------------------------------------
    testWidgets('8.11: Action targets meet >= 48dp minimum requirements across dialogs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  AppDialogs.showDestructiveConfirmDialog(
                    context: ctx,
                    title: 'Remove contact?',
                    message: 'This contact will no longer receive emergency alerts.',
                    cancelLabel: 'Keep Contact',
                    confirmLabel: 'Remove Contact',
                  );
                },
                child: const Text('Open Destructive'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Destructive'));
      await tester.pumpAndSettle();

      final keepContactRect = tester.getRect(
        find.ancestor(of: find.text('Keep Contact'), matching: find.byType(ElevatedButton)),
      );
      final removeContactRect = tester.getRect(
        find.ancestor(of: find.text('Remove Contact'), matching: find.byType(OutlinedButton)),
      );

      expect(keepContactRect.height, greaterThanOrEqualTo(48.0));
      expect(removeContactRect.height, greaterThanOrEqualTo(48.0));
    });
  });
}
