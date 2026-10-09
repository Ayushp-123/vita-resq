import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/constants/app_constants.dart';
import '../models/emergency_model.dart';
import '../screens/emergency/emergency_details_screen.dart';
import 'responder_mode_service.dart';

/// Centralized presentation copy for emergency push and in-app alert feedback (Phase 8).
class EmergencyAlertPresentation {
  static String formatTitle({required String role, required EmergencyStatus status}) {
    final isVictim = role.toUpperCase() == 'VICTIM';
    switch (status) {
      case EmergencyStatus.SEARCHING:
        return isVictim ? 'Help request active' : 'New emergency nearby';
      case EmergencyStatus.ASSIGNED:
        return isVictim ? 'Responder on the way' : "You're responding";
      case EmergencyStatus.APPROACHING:
        return isVictim ? 'Responder approaching' : 'Approaching location';
      case EmergencyStatus.ARRIVED:
        return isVictim ? 'Responder has arrived' : "You've arrived";
      case EmergencyStatus.COMPLETED:
        return 'Emergency completed';
      case EmergencyStatus.CANCELLED:
        return 'Emergency cancelled';
    }
  }

  static String formatBody({required String role, required EmergencyStatus status, String? type}) {
    final isVictim = role.toUpperCase() == 'VICTIM';
    switch (status) {
      case EmergencyStatus.SEARCHING:
        return isVictim
            ? 'Alerting nearby responders and emergency services.'
            : 'Someone nearby needs emergency assistance.';
      case EmergencyStatus.ASSIGNED:
        return isVictim
            ? 'A nearby responder has accepted and is preparing.'
            : 'Navigation and emergency details ready.';
      case EmergencyStatus.APPROACHING:
        return isVictim
            ? 'Your responder is en-route and closing in.'
            : 'Navigating to victim coordinates.';
      case EmergencyStatus.ARRIVED:
        return isVictim
            ? 'Help is now at your location.'
            : 'You have reached the emergency scene.';
      case EmergencyStatus.COMPLETED:
        return 'The emergency has been resolved safely.';
      case EmergencyStatus.CANCELLED:
        return 'The emergency request was cancelled.';
    }
  }
}

class NotificationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static const MethodChannel _platformChannel = MethodChannel('com.example.jan_sarthi/notifications');

  /// Cold-start pending emergency ID waiting for navigatorKey to be mounted
  static String? pendingEmergencyId;

  /// Deduplication set to prevent repeated alerts for the same incident
  static final Set<String> _processedEmergencyNotifications = <String>{};

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedAppSubscription;
  bool _isInitialized = false;

  /// Clear deduplication cache (strictly for testing)
  @visibleForTesting
  static void resetProcessedNotifications() {
    _processedEmergencyNotifications.clear();
    pendingEmergencyId = null;
  }

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Request runtime notification permissions
    try {
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    } catch (_) {}

    try {
      final status = await Permission.notification.status;
      if (!status.isGranted && !status.isPermanentlyDenied) {
        await Permission.notification.request();
      }
    } catch (_) {}

    // 2. Set up native method channel handler for notification taps & service events
    _platformChannel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onNotificationTapped') {
        final emergencyId = call.arguments?.toString();
        if (emergencyId != null && emergencyId.isNotEmpty) {
          navigateToEmergency(emergencyId);
        }
      } else if (call.method == 'onResponderModeTimedOut') {
        await ResponderModeService.instance.stopResponderMode(fromTimeout: true);
      }
    });

    // 3. Check cold-start / initial emergency ID from native intent
    try {
      final initialNativeId = await _platformChannel.invokeMethod<String>('getInitialEmergencyId');
      if (initialNativeId != null && initialNativeId.isNotEmpty) {
        navigateToEmergency(initialNativeId);
      }
    } catch (_) {}

    // 4. Check cold-start FCM initial message
    try {
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleFcmMessage(initialMessage, isTap: true);
      }
    } catch (_) {}

    // 5. Foreground FCM message listener
    _messageSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleFcmMessage(message, isTap: false);
    });

    // 6. Background FCM message opened listener
    _messageOpenedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleFcmMessage(message, isTap: true);
    });

    // 7. Register FCM token for active user and listen for refresh
    await registerToken();
  }

  /// Request and register current FCM device token into Firestore users/{uid}
  Future<void> registerToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      String? token = await _fcm.getToken();
      if (token != null && token.isNotEmpty) {
        await _updateTokenInFirestore(user.uid, token);
      }
    } catch (_) {}

    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _fcm.onTokenRefresh.listen((newToken) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && newToken.isNotEmpty) {
        _updateTokenInFirestore(currentUser.uid, newToken);
      }
    });
  }

  Future<void> _updateTokenInFirestore(String uid, String token) async {
    try {
      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .set({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void _handleFcmMessage(RemoteMessage message, {required bool isTap}) {
    final emergencyId = message.data['emergencyId']?.toString();
    if (emergencyId == null || emergencyId.isEmpty) return;

    if (isTap) {
      navigateToEmergency(emergencyId);
    } else {
      // In foreground, trigger high-importance alert notification if not already processed
      final distanceStr = message.data['distanceMeters']?.toString();
      final double? dist = distanceStr != null ? double.tryParse(distanceStr) : null;
      final type = message.data['type']?.toString() ?? 'EMERGENCY';

      showEmergencyAlertNotification(
        emergencyId: emergencyId,
        type: type,
        distanceMeters: dist,
        isOffline: false,
      );
    }
  }

  /// Centralized responder notification display (used by both Online and Offline P2P paths)
  static Future<void> showEmergencyAlertNotification({
    required String emergencyId,
    required String type,
    double? distanceMeters,
    bool isOffline = false,
    String userRole = 'CITIZEN',
    EmergencyStatus? status,
  }) async {
    if (emergencyId.isEmpty) return;

    // Reject closed, cancelled or already notified emergencies
    if (status == EmergencyStatus.COMPLETED || status == EmergencyStatus.CANCELLED) {
      return;
    }
    if (_processedEmergencyNotifications.contains(emergencyId)) {
      return;
    }
    _processedEmergencyNotifications.add(emergencyId);

    final title = isOffline
        ? 'Vita ResQ — Emergency Nearby (Offline P2P)'
        : 'Vita ResQ — Emergency Nearby';

    String distStr = '';
    if (distanceMeters != null && distanceMeters > 0) {
      distStr = distanceMeters < 1000
          ? ' • ${distanceMeters.round()} m away'
          : ' • ${(distanceMeters / 1000).toStringAsFixed(1)} km away';
    }
    final body = 'A nearby Vita ResQ user needs assistance ($type)$distStr';
    final int notificationId = emergencyId.hashCode & 0x7FFFFFFF;

    try {
      await _platformChannel.invokeMethod('showEmergencyNotification', {
        'id': notificationId,
        'title': title,
        'body': body,
        'emergencyId': emergencyId,
      });
    } catch (_) {}

    try {
      await EmergencySoundService.playEmergencyAlert(
        userRole: userRole,
        emergencyId: emergencyId,
      );
    } catch (_) {}
  }

  /// Cancel active notification when emergency is resolved, claimed, or cancelled
  static Future<void> cancelEmergencyNotification(String emergencyId) async {
    if (emergencyId.isEmpty) return;
    final int notificationId = emergencyId.hashCode & 0x7FFFFFFF;
    try {
      await _platformChannel.invokeMethod('cancelEmergencyNotification', {
        'id': notificationId,
      });
    } catch (_) {}
  }

  /// Authoritative navigation router for notification taps (foreground, background, cold-start)
  static bool navigateToEmergency(String emergencyId) {
    if (emergencyId.isEmpty) return false;

    final nav = navigatorKey.currentState;
    if (nav == null) {
      pendingEmergencyId = emergencyId;
      return false;
    }

    pendingEmergencyId = null;
    nav.push(
      MaterialPageRoute(
        builder: (_) => EmergencyDetailsScreen(emergencyId: emergencyId),
      ),
    );
    return true;
  }

  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _messageSubscription?.cancel();
    _messageOpenedAppSubscription?.cancel();
    _isInitialized = false;
  }
}

/// Dedicated Emergency Sound, Chime & Siren Service with deduplication protection
class EmergencySoundService {
  static Timer? _vibrationTimer;
  static bool _isPlaying = false;
  static final Set<String> _processedAlertSoundIds = {};
  static final Set<String> _processedHelperSoundIds = {};
  static final Set<String> _processedVictimNotifiedSoundIds = {};
  static final Set<String> _processedResolvedSoundIds = {};
  static DateTime? _lastErrorSoundTime;

  /// A. Accident Warning Trigger Sound
  static Future<void> playAccidentWarning() async {
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 150));
    HapticFeedback.heavyImpact();
  }

  /// B. Countdown Ticks
  static Future<void> playCountdownBeep({bool isFinal = false}) async {
    try {
      if (isFinal) {
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.heavyImpact();
      } else {
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.selectionClick();
      }
    } catch (_) {}
  }

  /// C. SOS Sent Confirmation Chime
  static Future<void> playSOSSentSound() async {
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    HapticFeedback.mediumImpact();
  }

  /// Alias for playSOSSentSound
  static Future<void> playSosSent() => playSOSSentSound();

  /// D. Nearby Emergency Received (with duplicate protection per emergencyId)
  static Future<void> playEmergencyAlert({
    required String userRole,
    String? emergencyId,
  }) async {
    if (emergencyId != null && _processedAlertSoundIds.contains(emergencyId)) {
      return;
    }
    if (emergencyId != null) {
      _processedAlertSoundIds.add(emergencyId);
    }
    if (_isPlaying) return;
    _isPlaying = true;

    if (userRole == 'AMBULANCE_DRIVER') {
      // Ambulance Siren Alert (Repeating Alert Tone + Rapid Haptic)
      _startSirenLoop(intervalMs: 800);
    } else if (userRole == 'POLICE_PCR') {
      // Police Tactical Siren Alert
      _startSirenLoop(intervalMs: 600);
    } else {
      // Citizen Volunteer Alert
      try {
        SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 250), () => HapticFeedback.heavyImpact());
    }
  }

  /// Alias for playEmergencyAlert
  static Future<void> playNearbyEmergency(String emergencyId, {String userRole = 'CITIZEN'}) =>
      playEmergencyAlert(userRole: userRole, emergencyId: emergencyId);

  /// E. Helper Accepted Confirmation (with duplicate protection)
  static Future<void> playHelperAccepted([String? emergencyId]) async {
    if (emergencyId != null && _processedHelperSoundIds.contains(emergencyId)) {
      return;
    }
    if (emergencyId != null) {
      _processedHelperSoundIds.add(emergencyId);
    }
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
    HapticFeedback.heavyImpact();
  }

  /// F. Victim Receives Helper Acceptance Notification (with duplicate protection)
  static Future<void> playVictimReceivedHelper(String emergencyId, [String? helperName]) async {
    if (_processedVictimNotifiedSoundIds.contains(emergencyId)) {
      return;
    }
    _processedVictimNotifiedSoundIds.add(emergencyId);
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    HapticFeedback.heavyImpact();
  }

  /// G. Emergency Resolved / Ended Confirmation (with duplicate protection)
  static Future<void> playEmergencyResolved([String? emergencyId]) async {
    if (emergencyId != null && _processedResolvedSoundIds.contains(emergencyId)) {
      return;
    }
    if (emergencyId != null) {
      _processedResolvedSoundIds.add(emergencyId);
    }
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
    HapticFeedback.mediumImpact();
  }

  /// H. Error / Failed Operation Tone (Debounced)
  static Future<void> playError([String? context]) async {
    final now = DateTime.now();
    if (_lastErrorSoundTime != null && now.difference(_lastErrorSoundTime!).inMilliseconds < 1000) {
      return;
    }
    _lastErrorSoundTime = now;
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
    HapticFeedback.vibrate();
  }

  static void _startSirenLoop({int intervalMs = 800}) {
    _vibrationTimer?.cancel();
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
    HapticFeedback.heavyImpact();

    _vibrationTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (!_isPlaying) {
        timer.cancel();
        return;
      }
      try {
        SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
      HapticFeedback.heavyImpact();
    });
  }

  /// Stop all playing alarms, sirens and vibration timers immediately
  static Future<void> stopSound() async {
    _isPlaying = false;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
  }

  /// Clear all duplicate sound history (for testing)
  static void resetDuplicateSoundHistory() {
    _processedAlertSoundIds.clear();
    _processedHelperSoundIds.clear();
    _processedVictimNotifiedSoundIds.clear();
    _processedResolvedSoundIds.clear();
    _lastErrorSoundTime = null;
  }
}
