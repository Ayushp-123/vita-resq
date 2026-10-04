import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jan_sarthi/models/impact_model.dart';
import 'package:jan_sarthi/services/impact_reward_service.dart';
import 'package:jan_sarthi/widgets/community_certificate_dialog.dart';
import 'package:jan_sarthi/widgets/victim_feedback_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Jan Sarthi Civic Recognition & Impact System Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. UserImpactProfile calculates recognition levels and progress accurately', () {
      // Level 1: Volunteer
      const p1 = UserImpactProfile(impactPoints: 25);
      expect(p1.currentLevel.levelNumber, 1);
      expect(p1.currentLevel.title, 'Community Volunteer');
      expect(p1.currentLevel.getProgress(25), 0.5);
      expect(p1.currentLevel.getPointsToNext(25), 25);

      // Level 2: Responder
      const p2 = UserImpactProfile(impactPoints: 100);
      expect(p2.currentLevel.levelNumber, 2);
      expect(p2.currentLevel.title, 'Vita ResQ Responder');
      expect(p2.currentLevel.getProgress(100), 0.5);

      // Level 3: Trusted Responder
      const p3 = UserImpactProfile(impactPoints: 200);
      expect(p3.currentLevel.levelNumber, 3);
      expect(p3.currentLevel.title, 'Trusted Responder');

      // Level 4: Community Guardian
      const p4 = UserImpactProfile(impactPoints: 350);
      expect(p4.currentLevel.levelNumber, 4);
      expect(p4.currentLevel.title, 'Community Guardian');

      // Level 5: Vita ResQ Champion
      const p5 = UserImpactProfile(impactPoints: 600);
      expect(p5.currentLevel.levelNumber, 5);
      expect(p5.currentLevel.title, 'Vita ResQ Champion');
      expect(p5.currentLevel.getPointsToNext(600), 400);
    });

    test('2. Reliability Score calculation and bounds check', () {
      // No emergencies accepted yet -> defaults to 100%
      const p0 = UserImpactProfile(totalAccepted: 0, verifiedAssists: 0);
      expect(p0.reliabilityScore, 100.0);

      // 28 assists out of 30 accepted -> 93.3%
      const p1 = UserImpactProfile(totalAccepted: 30, verifiedAssists: 28);
      expect(p1.reliabilityScore, closeTo(93.33, 0.05));

      // 10 assists out of 10 accepted -> 100%
      const p2 = UserImpactProfile(totalAccepted: 10, verifiedAssists: 10);
      expect(p2.reliabilityScore, 100.0);
    });

    test('3. ImpactRewardService records acceptance without duplicate inflation', () async {
      final service = ImpactRewardService();

      await service.recordEmergencyAccepted('user_001', 'em_101');
      var profile = await service.getImpactProfile('user_001');
      expect(profile.totalAccepted, 1);

      // Duplicate acceptance for same emergency should not increment totalAccepted again
      await service.recordEmergencyAccepted('user_001', 'em_101');
      profile = await service.getImpactProfile('user_001');
      expect(profile.totalAccepted, 1);

      // New emergency increments
      await service.recordEmergencyAccepted('user_001', 'em_102');
      profile = await service.getImpactProfile('user_001');
      expect(profile.totalAccepted, 2);
    });

    test('4. Arrival verification awards points and unlocks badges', () async {
      final service = ImpactRewardService();

      // Verified arrival for offline primary emergency with accident detection
      final pts = await service.recordArrivalVerified(
        userId: 'user_002',
        emergencyId: 'em_201',
        isPrimary: true,
        isOffline: true,
        emergencyType: 'ACCIDENT',
      );

      // 10 base + 5 primary + 5 offline + 5 accident = 25 pts
      expect(pts, 25);

      final profile = await service.getImpactProfile('user_002');
      expect(profile.impactPoints, 25);
      expect(profile.verifiedAssists, 1);
      expect(profile.victimsReached, 1);
      expect(profile.unlockedBadgeIds.contains('first_response'), isTrue);
      expect(profile.unlockedBadgeIds.contains('rapid_responder'), isTrue);
      expect(profile.unlockedBadgeIds.contains('offline_guardian'), isTrue);
      expect(profile.unlockedBadgeIds.contains('accident_hero'), isTrue);

      // Duplicate arrival call for same emergency awards 0 pts
      final duplicatePts = await service.recordArrivalVerified(
        userId: 'user_002',
        emergencyId: 'em_201',
        isPrimary: true,
        isOffline: true,
      );
      expect(duplicatePts, 0);
    });

    test('5. Victim feedback verification awards confirmation bonus', () async {
      final service = ImpactRewardService();

      final bonus = await service.recordVictimFeedback(
        helperId: 'helper_777',
        emergencyId: 'em_999',
        wasHelpful: true,
      );
      expect(bonus, 10);

      final profile = await service.getImpactProfile('helper_777');
      expect(profile.impactPoints, 10);
      expect(profile.recentContributions.length, 1);
      expect(profile.recentContributions.first.pointsEarned, 10);

      // Duplicate feedback for same emergency returns 0
      final dupBonus = await service.recordVictimFeedback(
        helperId: 'helper_777',
        emergencyId: 'em_999',
        wasHelpful: true,
      );
      expect(dupBonus, 0);
    });

    testWidgets('6. CommunityCertificateDialog renders accurately with user credentials', (tester) async {
      const profile = UserImpactProfile(
        impactPoints: 284,
        verifiedAssists: 27,
        victimsReached: 24,
        totalAccepted: 29,
        unlockedBadgeIds: ['first_response', 'rapid_responder'],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CommunityCertificateDialog(
              userName: 'Rahul Sharma',
              impactProfile: profile,
            ),
          ),
        ),
      );

      expect(find.text('COMMUNITY RESPONDER CERTIFICATE'), findsOneWidget);
      expect(find.text('RAHUL SHARMA'), findsOneWidget);
      expect(find.text('284'), findsOneWidget);
      expect(find.text('27'), findsOneWidget);
      expect(find.text('SHARE CERTIFICATE'), findsOneWidget);
    });

    testWidgets('7. VictimFeedbackDialog renders helper card and feedback options', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VictimFeedbackDialog(
              emergencyId: 'em_555',
              helperId: 'h_123',
              helperName: 'Priya Patel',
              helperRole: '108 Ambulance Driver',
            ),
          ),
        ),
      );

      expect(find.text('Verify Assistance'), findsOneWidget);
      expect(find.text('Priya Patel'), findsOneWidget);
      expect(find.text('108 Ambulance Driver'), findsOneWidget);
      expect(find.text('YES, HELPED ME'), findsOneWidget);
    });
  });
}
