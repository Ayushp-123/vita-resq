import 'package:flutter_test/flutter_test.dart';
import 'package:jan_sarthi/services/accident_detection_evaluator.dart';

void main() {
  group('Jan Sarthi Automatic Accident Detection Evaluator Tests', () {
    test('TEST 1: Normal movement produces NORMAL confidence (Score 0)', () {
      final res = AccidentDetectionEvaluator.evaluate(
        xAcc: 0.0,
        yAcc: 9.81,
        zAcc: 0.0,
        xGyro: 0.1,
        yGyro: 0.1,
        zGyro: 0.1,
        speedBeforeMps: 2.0,
        speedAfterMps: 2.0,
      );

      expect(res.confidence, equals(AccidentConfidence.NORMAL));
      expect(res.score, equals(0));
    });

    test('TEST 2: Isolated single acceleration spike without secondary signals is capped at 45 (Not SUSPECTED)', () {
      final res = AccidentDetectionEvaluator.evaluate(
        xAcc: 30.0, // High acceleration spike (~3.0g)
        yAcc: 9.81,
        zAcc: 0.0,
        xGyro: 0.0,
        yGyro: 0.0,
        zGyro: 0.0,
        speedBeforeMps: 0.0,
        speedAfterMps: 0.0,
      );

      expect(res.confidence, isNot(equals(AccidentConfidence.SUSPECTED)));
      expect(res.score, lessThanOrEqualTo(45));
    });

    test('TEST 3: Acceleration + significant rotation produces score >= 20', () {
      final res = AccidentDetectionEvaluator.evaluate(
        xAcc: 20.0,
        yAcc: 9.81,
        zAcc: 0.0,
        xGyro: 3.0,
        yGyro: 1.0,
        zGyro: 1.0,
        speedBeforeMps: 3.0,
        speedAfterMps: 3.0,
      );

      expect(res.score, greaterThanOrEqualTo(20));
      expect(res.reasoning, contains('Rotation'));
    });

    test('TEST 4: Impact acceleration + sudden speed drop + rotation + vehicle context produces SUSPECTED accident (Score >= 70)', () {
      final res = AccidentDetectionEvaluator.evaluate(
        xAcc: 35.0, // Impact spike
        yAcc: 9.81,
        zAcc: 0.0,
        xGyro: 4.5, // High rotation
        yGyro: 2.0,
        zGyro: 1.0,
        speedBeforeMps: 15.0, // 54 km/h
        speedAfterMps: 0.5,   // Sudden drop to near zero
        isSustainedStillness: true,
      );

      expect(res.score, greaterThanOrEqualTo(70));
      expect(res.confidence, equals(AccidentConfidence.SUSPECTED));
      expect(res.reasoning, contains('Severe Impact'));
    });

    test('TEST 5: Evaluation result exposes metrics accurately', () {
      final res = AccidentDetectionEvaluator.evaluate(
        xAcc: 0.0,
        yAcc: 9.81,
        zAcc: 0.0,
      );

      expect(res.acceleration, closeTo(0.0, 0.1));
      expect(res.rotation, equals(0.0));
      expect(res.speedDrop, equals(0.0));
    });

    test('TEST 6: simulateAccidentEvent evaluation output produces SUSPECTED confidence (Score >= 70)', () {
      final res = AccidentDetectionEvaluator.evaluate(
        xAcc: 30.0,
        yAcc: 18.0,
        zAcc: 12.0,
        xGyro: 2.5,
        yGyro: 3.0,
        zGyro: 2.0,
        speedBeforeMps: 10.0,
        speedAfterMps: 4.0,
      );

      expect(res.confidence, equals(AccidentConfidence.SUSPECTED));
      expect(res.score, greaterThanOrEqualTo(70));
    });
  });
}
