import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'accident_detection_evaluator.dart';
import 'location_service.dart';

class AccidentDetectionService {
  static final AccidentDetectionService _instance = AccidentDetectionService._internal();
  factory AccidentDetectionService() => _instance;
  AccidentDetectionService._internal();

  static const String _settingKey = 'setting_automatic_accident_detection';

  final LocationService _locationService = LocationService();
  final StreamController<AccidentEvaluationResult> _accidentController =
      StreamController<AccidentEvaluationResult>.broadcast();

  Stream<AccidentEvaluationResult> get possibleAccidentStream => _accidentController.stream;

  StreamSubscription<UserAccelerometerEvent>? _userAccelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  bool _isMonitoring = false;
  bool _isEnabled = true;
  bool _isConfirmationActive = false;

  // Sensor state buffers
  double _lastXAcc = 0.0;
  double _lastYAcc = 0.0;
  double _lastZAcc = 0.0;

  double _lastXGyro = 0.0;
  double _lastYGyro = 0.0;
  double _lastZGyro = 0.0;

  double _speedBeforeImpact = 0.0;
  DateTime? _lastEvaluationTime;

  bool get isMonitoring => _isMonitoring;
  bool get isEnabled => _isEnabled;

  /// Initialize settings and start monitoring if enabled
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_settingKey) ?? true;
    if (_isEnabled) {
      start();
    }
  }

  /// Toggle setting
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_settingKey, enabled);

    if (enabled) {
      start();
    } else {
      stop();
    }
  }

  /// Mark confirmation dialog active state to prevent duplicate triggers
  void setConfirmationActive(bool active) {
    _isConfirmationActive = active;
  }

  /// Start sensor monitoring safely without duplicate listeners
  void start() {
    if (_isMonitoring || !_isEnabled) return;
    _isMonitoring = true;

    if (kDebugMode) {
      print('[ACCIDENT] Starting sensor monitoring...');
    }

    _gyroSub?.cancel();
    _gyroSub = gyroscopeEventStream().listen((GyroscopeEvent event) {
      _lastXGyro = event.x;
      _lastYGyro = event.y;
      _lastZGyro = event.z;
    }, onError: (_) {});

    _userAccelSub?.cancel();
    _userAccelSub = userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
      _lastXAcc = event.x;
      _lastYAcc = event.y;
      _lastZAcc = event.z;

      _onAccelerometerEvent();
    }, onError: (_) {});
  }

  void _onAccelerometerEvent() async {
    if (!_isMonitoring || _isConfirmationActive) return;

    DateTime now = DateTime.now();
    if (_lastEvaluationTime != null && now.difference(_lastEvaluationTime!).inMilliseconds < 1500) {
      return;
    }

    // Get current speed from LocationService
    double currentSpeedMps = _locationService.lastSpeedMps;

    // Evaluate sensor inputs
    AccidentEvaluationResult result = AccidentDetectionEvaluator.evaluate(
      xAcc: _lastXAcc,
      yAcc: _lastYAcc,
      zAcc: _lastZAcc,
      xGyro: _lastXGyro,
      yGyro: _lastYGyro,
      zGyro: _lastZGyro,
      speedBeforeMps: _speedBeforeImpact,
      speedAfterMps: currentSpeedMps,
    );

    _speedBeforeImpact = currentSpeedMps;

    if (result.confidence == AccidentConfidence.SUSPECTED) {
      _lastEvaluationTime = now;
      if (kDebugMode) {
        print('[ACCIDENT] SUSPECTED ACCIDENT DETECTED! score=${result.score} acc=${result.acceleration.toStringAsFixed(1)} reasoning=${result.reasoning}');
      }
      _accidentController.add(result);
    }
  }

  /// Stop sensor monitoring and cancel subscriptions
  void stop() {
    _isMonitoring = false;
    _userAccelSub?.cancel();
    _userAccelSub = null;
    _gyroSub?.cancel();
    _gyroSub = null;
    if (kDebugMode) {
      print('[ACCIDENT] Stopped sensor monitoring.');
    }
  }

  /// Inject a simulated high-confidence accident event through the evaluator pipeline
  /// ONLY available for development/demo testing
  void simulateAccidentEvent() {
    if (_isConfirmationActive) {
      if (kDebugMode) {
        print('[ACCIDENT DEMO] Ignored simulated event: confirmation dialog or SOS already active.');
      }
      return;
    }

    // High-confidence simulated crash metrics:
    // Impact acceleration: 27.2 m/s^2 (+40 pts)
    // Speed reduction: 6.0 m/s (+25 pts)
    // Angular rotation: 4.5 rad/s (+15 pts)
    // Vehicle speed context: 10.0 m/s (+10 pts)
    // Total score: 90/100 (SUSPECTED)
    AccidentEvaluationResult result = AccidentDetectionEvaluator.evaluate(
      xAcc: 30.0,
      yAcc: 18.0,
      zAcc: 12.0,
      xGyro: 2.5,
      yGyro: 3.0,
      zGyro: 2.0,
      speedBeforeMps: 10.0,
      speedAfterMps: 4.0,
    );

    if (kDebugMode) {
      print('[ACCIDENT DEMO] Injected simulated crash event: score=${result.score}, confidence=${result.confidence}');
    }

    if (result.confidence == AccidentConfidence.SUSPECTED) {
      _lastEvaluationTime = DateTime.now();
      _accidentController.add(result);
    }
  }

  /// Dispose service resources
  void dispose() {
    stop();
  }
}
