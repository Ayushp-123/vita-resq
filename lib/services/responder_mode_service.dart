import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/emergency_model.dart';
import 'emergency_service.dart';
import 'notification_service.dart';
import 'location_service.dart';
import 'communication_manager.dart';
import 'offline_communication_service.dart';
import 'local_database_service.dart';

/// Contract for Responder Availability & Background Mode.
abstract class IResponderModeService {
  bool get isAvailable;
  Stream<bool> get availabilityStream;
  Future<void> initialize();
  Future<bool> startResponderMode({double? latitude, double? longitude, String? userId});
  Future<void> stopResponderMode({bool fromTimeout = false});
  void resetProcessedEmergencyIds();
  Future<void> handleEmergencyAlert(EmergencyModel alert, {double? userLat, double? userLon, String? currentUserId});
}

/// Service managing the foreground service lifecycle and background listener
/// for "Responder Available" mode without requiring Firebase Cloud Functions or paid backends.
class ResponderModeService implements IResponderModeService {
  static const String _prefKeyResponderMode = 'key_responder_mode_active';
  static const MethodChannel _platformChannel = MethodChannel('com.example.jan_sarthi/notifications');

  static final ResponderModeService _instance = ResponderModeService._internal();
  static IResponderModeService? _mockInstance;

  static IResponderModeService get instance => _mockInstance ?? _instance;

  @visibleForTesting
  static void setMockInstance(IResponderModeService? mock) {
    _mockInstance = mock;
  }

  ResponderModeService._internal();

  bool _isAvailable = false;
  final StreamController<bool> _availabilityController = StreamController<bool>.broadcast();
  StreamSubscription<List<EmergencyModel>>? _emergencySubscription;
  StreamSubscription<Position>? _locationSubscription;
  final Set<String> _processedEmergencyIds = <String>{};

  @override
  bool get isAvailable => _isAvailable;

  @override
  Stream<bool> get availabilityStream => _availabilityController.stream;

  @override
  void resetProcessedEmergencyIds() {
    _processedEmergencyIds.clear();
  }

  /// Initialize and verify active foreground service state.
  /// Strictly does NOT start the foreground service automatically, preventing
  /// arbitrary background FGS startups without user interaction.
  @override
  Future<void> initialize() async {
    try {
      final bool isRunning = await _platformChannel.invokeMethod<bool>('isResponderForegroundServiceRunning') ?? false;
      if (isRunning) {
        _isAvailable = true;
        _availabilityController.add(true);
      } else {
        _isAvailable = false;
        _availabilityController.add(false);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefKeyResponderMode, false);
      }
    } catch (_) {
      _isAvailable = false;
    }
  }

  @override
  Future<bool> startResponderMode({double? latitude, double? longitude, String? userId}) async {
    if (_isAvailable) return true;

    _isAvailable = true;
    _availabilityController.add(true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyResponderMode, true);
    } catch (_) {}

    // 1. Start native Android Foreground Service with low-noise ongoing notification
    try {
      await _platformChannel.invokeMethod('startResponderForegroundService');
    } catch (_) {}

    // 2. Resolve active coordinates
    double currentLat = latitude ?? 28.6139;
    double currentLon = longitude ?? 77.2090;
    String effectiveUid = userId ?? '';
    if (effectiveUid.isEmpty) {
      try {
        effectiveUid = FirebaseAuth.instance.currentUser?.uid ?? 'offline_user';
      } catch (_) {
        effectiveUid = 'offline_user';
      }
    }

    try {
      final lastPos = await LocationService().getCurrentLocation();
      if (lastPos != null) {
        currentLat = lastPos.latitude;
        currentLon = lastPos.longitude;
      }
    } catch (_) {}

    // 3. Keep Firestore & Nearby Connections emergency listener alive
    _startBackgroundListener(currentLat, currentLon, effectiveUid);

    // 4. Update coordinates if device moves
    try {
      _locationSubscription?.cancel();
      _locationSubscription = LocationService().onPositionChanged.listen((pos) {
        currentLat = pos.latitude;
        currentLon = pos.longitude;
      });
    } catch (_) {}

    return true;
  }

  void _startBackgroundListener(double lat, double lon, String uid) {
    _emergencySubscription?.cancel();
    _emergencySubscription = CommunicationManager()
        .listenForAlerts(userLat: lat, userLon: lon, currentUserId: uid)
        .listen((emergencies) {
      for (var alert in emergencies) {
        handleEmergencyAlert(
          alert,
          userLat: lat,
          userLon: lon,
          currentUserId: uid,
        );
      }
    });
  }

  @override
  Future<void> handleEmergencyAlert(
    EmergencyModel alert, {
    double? userLat,
    double? userLon,
    String? currentUserId,
  }) async {
    String effectiveUid = currentUserId ?? '';
    if (effectiveUid.isEmpty) {
      try {
        effectiveUid = FirebaseAuth.instance.currentUser?.uid ?? 'offline_user';
      } catch (_) {
        effectiveUid = 'offline_user';
      }
    }

    // 1. Skip victim's own emergency
    final myDeviceId = await LocalDatabaseService.getOrCreateLocalDeviceId();
    final isOwnDevice = alert.originDeviceId != null && alert.originDeviceId == myDeviceId;
    final isOwnAuthUser = effectiveUid != 'offline_user' && alert.victimId == effectiveUid;
    if (isOwnDevice || isOwnAuthUser) {
      return;
    }

    // 2. Only actionable SEARCHING emergencies trigger alerts
    if (alert.status != EmergencyStatus.SEARCHING) {
      return;
    }

    // 3. Deduplication: skip already notified / processed emergencies
    if (_processedEmergencyIds.contains(alert.id)) {
      return;
    }

    // 4. Skip if user previously declined this emergency
    try {
      if (EmergencyService().isEmergencyDeclined(alert.id)) {
        return;
      }
    } catch (_) {}

    // 5. Skip stale emergencies (60 minutes for offline P2P to absorb device clock skew, 10 min for online)
    if (alert.isOffline) {
      if (!OfflineCommunicationService.isOfflineAlertFresh(alert.createdAt)) {
        return;
      }
    } else {
      if (DateTime.now().difference(alert.createdAt).inMinutes.abs() > 10) {
        return;
      }
    }

    // Mark as processed
    _processedEmergencyIds.add(alert.id);

    // If online, mark user notified in Firestore
    if (!alert.isOffline && effectiveUid != 'offline_user') {
      try {
        await EmergencyService().markUserNotified(alert.id, effectiveUid);
      } catch (_) {}
    }

    // 6. Calculate proximity
    double? distMeters;
    if (userLat != null && userLon != null) {
      distMeters = Geolocator.distanceBetween(
        userLat,
        userLon,
        alert.latitude,
        alert.longitude,
      );
    }

    // 7. Dispatch HIGH-IMPORTANCE local notification with sound & vibration
    await NotificationService.showEmergencyAlertNotification(
      emergencyId: alert.id,
      type: alert.type,
      distanceMeters: distMeters,
      isOffline: alert.isOffline,
      status: alert.status,
    );
  }

  @override
  Future<void> stopResponderMode({bool fromTimeout = false}) async {
    if (!_isAvailable && !fromTimeout) return;

    _isAvailable = false;
    _availabilityController.add(false);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyResponderMode, false);
    } catch (_) {}

    // 1. Cancel background listeners
    await _emergencySubscription?.cancel();
    _emergencySubscription = null;

    await _locationSubscription?.cancel();
    _locationSubscription = null;

    // 2. Stop native Android Foreground Service and remove persistent notification
    if (!fromTimeout) {
      try {
        await _platformChannel.invokeMethod('stopResponderForegroundService');
      } catch (_) {}
    }
  }
}
