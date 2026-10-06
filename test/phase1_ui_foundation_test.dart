import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jan_sarthi/core/theme/app_theme.dart';
import 'package:jan_sarthi/widgets/common/common.dart';

void main() {
  group('Vita ResQ Phase 1 UI Foundation — Design Tokens', () {
    test('1.1: Color System tokens match locked specification', () {
      expect(AppColors.warmOffWhite, const Color(0xFFFBF9F5));
      expect(AppColors.primaryBackground, const Color(0xFFFBF9F5));
      expect(AppColors.subtleBlueGray, const Color(0xFFF1F5F9));
      expect(AppColors.surfaceCard, const Color(0xFFFFFFFF));

      expect(AppColors.deepNavy, const Color(0xFF0F172A));
      expect(AppColors.emergencyRed, const Color(0xFFDC2626));
      expect(AppColors.softBlue, const Color(0xFF2563EB));
      expect(AppColors.emeraldGreen, const Color(0xFF10B981));
      expect(AppColors.warningAmber, const Color(0xFFF59E0B));

      // Backward-compatible AppTheme properties
      expect(AppTheme.primaryNavy, const Color(0xFF0F172A));
      expect(AppTheme.brandBlue, const Color(0xFF2563EB));
      expect(AppTheme.emergencyRed, const Color(0xFFDC2626));
      expect(AppTheme.emeraldGreen, const Color(0xFF10B981));
      expect(AppTheme.surfaceLight, const Color(0xFFF8FAFC));
    });

    test('1.2: Shape System tokens define soft and rounded language', () {
      expect(AppShapes.radiusSm, 10.0);
      expect(AppShapes.radiusMd, 16.0);
      expect(AppShapes.radiusLg, 24.0);
      expect(AppShapes.buttonRadius, 16.0);
      expect(AppShapes.inputRadius, 14.0);
      expect(AppShapes.cardRadius, 20.0);
      expect(AppShapes.dialogRadius, 24.0);
      expect(AppShapes.statusBadgeRadius, 8.0);
      expect(AppShapes.radiusPill, 100.0);

      expect(AppShapes.card.topLeft.x, 20.0);
      expect(AppShapes.button.topLeft.x, 16.0);
      expect(AppShapes.input.topLeft.x, 14.0);
    });

    test('1.3: Typography System provides centralized legible styles', () {
      expect(AppTypography.display.fontSize, 28);
      expect(AppTypography.display.fontWeight, FontWeight.w800);

      expect(AppTypography.pageHeading.fontSize, 22);
      expect(AppTypography.pageHeading.fontWeight, FontWeight.w700);

      expect(AppTypography.sectionHeading.fontSize, 18);
      expect(AppTypography.sectionHeading.fontWeight, FontWeight.w700);

      expect(AppTypography.body.fontSize, 15);
      expect(AppTypography.bodyMedium.fontWeight, FontWeight.w500);

      expect(AppTypography.caption.fontSize, 12);
      expect(AppTypography.metadata.fontSize, 11);
      expect(AppTypography.buttonText.fontSize, 15);

      expect(AppTypography.emergencyStatus.color, AppColors.emergencyRed);
      expect(AppTypography.emergencyStatus.fontWeight, FontWeight.w800);

      expect(AppTypography.numericDisplay.fontSize, 26);
      expect(AppTypography.numericDisplay.fontWeight, FontWeight.w800);
      expect(AppTypography.numericCompact.fontSize, 16);
    });

    test('1.4: Spacing System provides 8pt grid scale and touch targets', () {
      expect(AppSpacing.xs, 4.0);
      expect(AppSpacing.sm, 8.0);
      expect(AppSpacing.md, 12.0);
      expect(AppSpacing.lg, 16.0);
      expect(AppSpacing.xl, 20.0);
      expect(AppSpacing.xxl, 24.0);
      expect(AppSpacing.xxxl, 32.0);

      expect(AppSpacing.minTouchTarget, 48.0);
      expect(AppSpacing.buttonHeight, 52.0);
      expect(AppSpacing.inputHeight, 52.0);
      expect(AppSpacing.iconButtonSize, 48.0);
    });

    test('1.5: Motion System tokens stay within 150-250ms target range', () {
      expect(AppMotion.fast.inMilliseconds, 150);
      expect(AppMotion.normal.inMilliseconds, 200);
      expect(AppMotion.transition.inMilliseconds, 250);
      expect(AppMotion.easeOut, Curves.easeOutCubic);
      expect(AppMotion.easeInOut, Curves.easeInOutCubic);
    });

    test('1.6: Status System correctly configures all 8 semantic statuses', () {
      final statuses = [
        AppStatusType.normal,
        AppStatusType.online,
        AppStatusType.offline,
        AppStatusType.warning,
        AppStatusType.emergency,
        AppStatusType.success,
        AppStatusType.completed,
        AppStatusType.error,
      ];

      for (final s in statuses) {
        final config = AppStatusConfig.resolve(s);
        expect(config.label.isNotEmpty, isTrue);
        expect(config.color, isNotNull);
        expect(config.backgroundColor, isNotNull);
        expect(config.borderColor, isNotNull);
        expect(config.icon, isNotNull);
      }

      expect(AppStatusConfig.resolve(AppStatusType.emergency).color, AppColors.emergencyRed);
      expect(AppStatusConfig.resolve(AppStatusType.online).color, AppColors.emeraldGreen);
      expect(AppStatusConfig.resolve(AppStatusType.warning).color, AppColors.warningAmber);
      expect(AppStatusConfig.resolve(AppStatusType.completed).color, AppColors.softBlueDark);
    });

    test('1.7: AppTheme.lightTheme integrates design tokens cleanly', () {
      final theme = AppTheme.lightTheme;
      expect(theme.useMaterial3, isTrue);
      expect(theme.scaffoldBackgroundColor, AppColors.warmOffWhite);
      expect(theme.colorScheme.primary, AppColors.deepNavy);
      expect(theme.colorScheme.secondary, AppColors.softBlue);
      expect(theme.colorScheme.error, AppColors.emergencyRed);
      expect(theme.cardTheme.color, AppColors.surfacePureWhite);
    });
  });

  group('Vita ResQ Phase 1 UI Foundation — Widget Primitives', () {
    testWidgets('2.1: AppButton renders primary variant and triggers callback', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AppButton.primary(
              label: 'CONFIRM RESCUE',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('CONFIRM RESCUE'), findsOneWidget);
      await tester.tap(find.text('CONFIRM RESCUE'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('2.2: AppButton displays progress indicator when loading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: AppButton(
              label: 'LOADING ACTION',
              onPressed: null,
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('LOADING ACTION'), findsOneWidget);
    });

    testWidgets('2.3: AppIconButton renders with accessible touch target and tooltip', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AppIconButton(
              icon: Icons.notifications_outlined,
              tooltip: 'Notifications',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      expect(find.byType(Tooltip), findsOneWidget);

      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('2.4: AppTextField toggles password visibility on icon tap', (tester) async {
      final controller = TextEditingController(text: 'SecretPass123');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AppTextField(
              controller: controller,
              label: 'Password',
              isPassword: true,
            ),
          ),
        ),
      );

      expect(find.text('Password'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      final editableText = tester.widget<EditableText>(find.byType(EditableText));
      expect(editableText.obscureText, isTrue);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      final updatedEditable = tester.widget<EditableText>(find.byType(EditableText));
      expect(updatedEditable.obscureText, isFalse);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('2.5: AppDropdownField renders items and selections', (tester) async {
      String? selectedValue = 'Police';
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AppDropdownField<String>(
              label: 'Emergency Service',
              value: selectedValue,
              items: const [
                DropdownMenuItem(value: 'Ambulance', child: Text('Ambulance (108)')),
                DropdownMenuItem(value: 'Police', child: Text('Police (100)')),
              ],
              onChanged: (val) => selectedValue = val,
            ),
          ),
        ),
      );

      expect(find.text('Emergency Service'), findsOneWidget);
      expect(find.text('Police (100)'), findsOneWidget);
    });

    testWidgets('2.6: AppCard renders soft card with subtle borders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: AppCard(
              child: Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
      expect(find.byType(AppCard), findsOneWidget);
    });

    testWidgets('2.7: AppSection supports open sections without floating cards', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: AppSection(
              title: 'Nearby Responders',
              subtitle: 'Active civilian volunteers',
              child: Text('Section Body'),
            ),
          ),
        ),
      );

      expect(find.text('Nearby Responders'), findsOneWidget);
      expect(find.text('Active civilian volunteers'), findsOneWidget);
      expect(find.text('Section Body'), findsOneWidget);
    });

    testWidgets('2.8: AppInfoContainer renders callout with message and icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: AppInfoContainer(
              title: 'Safety Tip',
              message: 'Keep calm and stay in a visible area.',
              icon: Icon(Icons.info_outline),
            ),
          ),
        ),
      );

      expect(find.text('Safety Tip'), findsOneWidget);
      expect(find.text('Keep calm and stay in a visible area.'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('2.9: AppStatusContainer renders semantic status banner', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: AppStatusContainer(
              status: AppStatusType.online,
              customSubtitle: 'Mesh transport active',
            ),
          ),
        ),
      );

      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Mesh transport active'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
    });

    testWidgets('2.10: AppStatusBadge displays pill badges for all states', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Column(
              children: [
                AppStatusBadge.emergency(),
                AppStatusBadge.online(),
                AppStatusBadge.offline(),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Emergency Active'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Offline (P2P)'), findsOneWidget);
    });

    testWidgets('2.11: AppBottomNavBar locks exactly to 3 tabs: Home, History, Profile', (tester) async {
      int selectedTab = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            bottomNavigationBar: AppBottomNavBar(
              currentIndex: selectedTab,
              onTap: (idx) => selectedTab = idx,
            ),
          ),
        ),
      );

      // Verify the 3 locked tabs exist
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      // Verify Impact tab is NOT in bottom navigation
      expect(find.text('Impact'), findsNothing);

      // Test tap interaction
      await tester.tap(find.text('History'));
      await tester.pump();
      expect(selectedTab, 1);

      await tester.tap(find.text('Profile'));
      await tester.pump();
      expect(selectedTab, 2);
    });
  });
}
