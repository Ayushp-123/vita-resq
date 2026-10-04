import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_constants.dart';
import '../screens/emergency/emergency_details_screen.dart';

class NotificationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedAppSubscription;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    } catch (_) {}

    // Check cold-start / initial message when app opened from terminated state
    try {
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleMessage(initialMessage);
      }
    } catch (_) {}

    // Foreground message handler
    _messageSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleMessage(message);
    });

    // Tap notification when app is in background/opened
    _messageOpenedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessage(message);
    });

    // Register FCM token for active user and listen for refresh
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

  void _handleMessage(RemoteMessage message) {
    if (message.data.containsKey('emergencyId')) {
      String emergencyId = message.data['emergencyId'];
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => EmergencyDetailsScreen(emergencyId: emergencyId),
        ),
      );
    }
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
      // 108 Ambulance Siren Alert (Repeating Alert Tone + Rapid Haptic)
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
