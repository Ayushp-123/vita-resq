import 'dart:math';

enum AccidentConfidence {
  NORMAL,
  POSSIBLE,
  SUSPECTED,
}

class AccidentEvaluationResult {
  final int score;
  final AccidentConfidence confidence;
  final String reasoning;
  final double acceleration;
  final double rotation;
  final double speedDrop;

  AccidentEvaluationResult({
    required this.score,
    required this.confidence,
    required this.reasoning,
    required this.acceleration,
    required this.rotation,
    required this.speedDrop,
  });
}

class AccidentDetectionEvaluator {
  /// Pure deterministic evaluator for accident detection scoring
  static AccidentEvaluationResult evaluate({
    required double xAcc,
    required double yAcc,
    required double zAcc,
    double xGyro = 0.0,
    double yGyro = 0.0,
    double zGyro = 0.0,
    double speedBeforeMps = 0.0,
    double speedAfterMps = 0.0,
    bool isSustainedStillness = false,
  }) {
    // 1. Calculate acceleration magnitude
    double accMagnitude = sqrt(xAcc * xAcc + yAcc * yAcc + zAcc * zAcc);

    // Subtract standard earth gravity (9.81 m/s^2) for net impact force estimation
    double netImpactAcc = (accMagnitude - 9.81).abs();

    // 2. Calculate gyroscope rotation magnitude
    double gyroMagnitude = sqrt(xGyro * xGyro + yGyro * yGyro + zGyro * zGyro);

    // 3. Calculate speed drop (in m/s)
    double speedDrop = max(0.0, speedBeforeMps - speedAfterMps);

    int score = 0;
    List<String> reasons = [];

    // --- Signal A: Impact Acceleration ---
    if (netImpactAcc >= 25.0) {
      score += 40;
      reasons.add('Severe Impact (${netImpactAcc.toStringAsFixed(1)} m/s²)');
    } else if (netImpactAcc >= 18.0) {
      score += 25;
      reasons.add('High Acceleration Spike (${netImpactAcc.toStringAsFixed(1)} m/s²)');
    } else if (netImpactAcc >= 12.0) {
      score += 10;
      reasons.add('Moderate Acceleration');
    }

    // --- Signal B: Sudden Speed Reduction ---
    if (speedDrop >= 5.0) {
      score += 25;
      reasons.add('Sudden Speed Drop (${(speedDrop * 3.6).toStringAsFixed(1)} km/h drop)');
    } else if (speedDrop >= 3.0) {
      score += 15;
      reasons.add('Moderate Speed Reduction');
    }

    // --- Signal C: Sudden Rotation / Orientation Change ---
    if (gyroMagnitude >= 4.0) {
      score += 15;
      reasons.add('Severe Vehicle Rotation (${gyroMagnitude.toStringAsFixed(1)} rad/s)');
    } else if (gyroMagnitude >= 2.5) {
      score += 10;
      reasons.add('Significant Rotation');
    }

    // --- Signal D: Vehicle Speed Context Prior to Incident ---
    if (speedBeforeMps >= 5.0) { // >= 18 km/h
      score += 10;
      reasons.add('Active Vehicle Speed Context');
    }

    // --- Signal E: Sustained Stillness After Impact ---
    if (isSustainedStillness && netImpactAcc > 10.0) {
      score += 10;
      reasons.add('Post-Impact Stillness');
    }

    // False Positive Guard: Isolated acceleration spike without speed drop, rotation, or vehicle speed context
    // Cap score to 45 if no other secondary signal was present
    bool hasSecondarySignal = (speedDrop >= 3.0) || (gyroMagnitude >= 2.5) || (speedBeforeMps >= 5.0) || isSustainedStillness;
    if (!hasSecondarySignal && score > 45) {
      score = 45;
    }

    AccidentConfidence confidence = AccidentConfidence.NORMAL;
    if (score >= 70) {
      confidence = AccidentConfidence.SUSPECTED;
    } else if (score >= 40) {
      confidence = AccidentConfidence.POSSIBLE;
    }

    return AccidentEvaluationResult(
      score: score,
      confidence: confidence,
      reasoning: reasons.join(' + '),
      acceleration: netImpactAcc,
      rotation: gyroMagnitude,
      speedDrop: speedDrop,
    );
  }
}
