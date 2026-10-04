import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jan_sarthi/widgets/sos_button.dart';

void main() {
  testWidgets('SOSButton renders in idle state with hold instructions', (WidgetTester tester) async {
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

  testWidgets('SOSButton ignores accidental quick tap and cancels early release', (WidgetTester tester) async {
    bool activated = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SOSButton(
            holdDuration: const Duration(milliseconds: 500),
            onSOSActivated: () => activated = true,
          ),
        ),
      ),
    );

    // Quick tap
    await tester.tap(find.byType(SOSButton));
    await tester.pump(const Duration(milliseconds: 100));

    expect(activated, isFalse);

    // Press down and release early before duration completes
    final gesture = await tester.startGesture(tester.getCenter(find.byType(SOSButton)));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));

    expect(activated, isFalse);
  });

  testWidgets('SOSButton triggers callback when held for required duration', (WidgetTester tester) async {
    bool activated = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SOSButton(
            holdDuration: const Duration(milliseconds: 500),
            onSOSActivated: () => activated = true,
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(find.byType(SOSButton)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pump();

    expect(activated, isTrue);
  });
}
