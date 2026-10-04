import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/impact_model.dart';

/// Authoritative Civic Recognition & Impact Service
class ImpactRewardService {
  static final ImpactRewardService _instance = ImpactRewardService._internal();
  factory ImpactRewardService() => _instance;
  ImpactRewardService._internal();

  static const String _prefsKeyPrefix = 'jan_sarthi_impact_profile_';
  static const String _processedAwardsKey = 'jan_sarthi_processed_awards_';

  /// Standard badge catalog
  static final List<ImpactBadge> allBadgeDefinitions = [
    const ImpactBadge(
      id: 'first_response',
      title: 'First Response',
      description: 'Completed your first verified emergency response.',
      icon: Icons.volunteer_activism_rounded,
      color: Color(0xFF10B981), // Emerald
    ),
    const ImpactBadge(
      id: 'offline_guardian',
      title: 'Offline Guardian',
      description: 'Successfully assisted during an offline P2P emergency without internet.',
      icon: Icons.wifi_off_rounded,
      color: Color(0xFF3B82F6), // Blue
    ),
    const ImpactBadge(
      id: 'rapid_responder',
      title: 'Rapid Responder',
      description: 'Reached the emergency scene within the 100-meter verification geofence.',
      icon: Icons.bolt_rounded,
      color: Color(0xFFF59E0B), // Amber
    ),
    const ImpactBadge(
      id: 'reliable_shield',
      title: 'Reliable Shield',
      description: 'Maintained 90%+ reliability across your emergency responses.',
      icon: Icons.shield_rounded,
      color: Color(0xFF8B5CF6), // Purple
    ),
    const ImpactBadge(
      id: 'accident_hero',
      title: 'Accident Hero',
      description: 'Assisted in an automated crash detection or high-impact emergency.',
      icon: Icons.car_crash_rounded,
      color: Color(0xFFEF4444), // Red
    ),
    const ImpactBadge(
      id: 'night_guardian',
      title: 'Night Guardian',
      description: 'Completed emergency assistance during critical night hours (9 PM – 6 AM).',
      icon: Icons.bedtime_rounded,
      color: Color(0xFF6366F1), // Indigo
    ),
  ];

  /// Loads current user's profile from local cache or Firestore
  Future<UserImpactProfile> getImpactProfile([String? userId]) async {
    String? currentUid;
    try {
      currentUid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {}
    final uid = userId ?? currentUid ?? 'local_user';
    final prefs = await SharedPreferences.getInstance();

    // 1. Try local cache first for instant UI response
    final localJson = prefs.getString('$_prefsKeyPrefix$uid');
    UserImpactProfile profile = const UserImpactProfile();

    if (localJson != null) {
      try {
        final Map<String, dynamic> map = jsonDecode(localJson);
        profile = UserImpactProfile.fromMap(map);
      } catch (_) {}
    }

    // 2. Fetch latest from Firestore if online and user logged in
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser != null && uid == auth.currentUser!.uid) {
        final firestore = FirebaseFirestore.instance;
        final doc = await firestore.collection('users').doc(uid).get();
        if (doc.exists && doc.data() != null && doc.data()!.containsKey('impactProfile')) {
          final cloudMap = Map<String, dynamic>.from(doc.data()!['impactProfile']);
          profile = UserImpactProfile.fromMap(cloudMap);
          // Sync to local cache
          await prefs.setString('$_prefsKeyPrefix$uid', jsonEncode(profile.toMap()));
        }
      }
    } catch (_) {}

    return profile;
  }

  /// Records when a user accepts an emergency (increments totalAccepted)
  Future<void> recordEmergencyAccepted(String userId, String emergencyId) async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await getImpactProfile(userId);

    // Prevent duplicate accepted count for same emergency
    final acceptedEmergencies = prefs.getStringList('accepted_list_$userId') ?? [];
    if (acceptedEmergencies.contains(emergencyId)) return;

    acceptedEmergencies.add(emergencyId);
    await prefs.setStringList('accepted_list_$userId', acceptedEmergencies);

    final updated = UserImpactProfile(
      impactPoints: profile.impactPoints,
      verifiedAssists: profile.verifiedAssists,
      victimsReached: profile.victimsReached,
      totalAccepted: profile.totalAccepted + 1,
      unlockedBadgeIds: profile.unlockedBadgeIds,
      recentContributions: profile.recentContributions,
    );

    await _saveProfile(userId, updated);
  }

  /// Awards verified points when responder reaches within 100m geofence
  Future<int> recordArrivalVerified({
    required String userId,
    required String emergencyId,
    required bool isPrimary,
    required bool isOffline,
    String? emergencyType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final awardKey = 'arrival_${userId}_$emergencyId';
    final processedAwards = prefs.getStringList('$_processedAwardsKey$userId') ?? [];

    if (processedAwards.contains(awardKey)) {
      return 0; // Already awarded for this arrival
    }

    processedAwards.add(awardKey);
    await prefs.setStringList('$_processedAwardsKey$userId', processedAwards);

    // Points calculation:
    // Base arrival: +10 pts
    // Primary bonus: +5 pts
    // Offline P2P bonus: +5 pts
    // Accident bonus: +5 pts
    int points = 10;
    if (isPrimary) points += 5;
    if (isOffline) points += 5;
    if (emergencyType == 'ACCIDENT' || emergencyType == 'COLLISION') points += 5;

    final profile = await getImpactProfile(userId);
    final List<String> newBadges = List.from(profile.unlockedBadgeIds);

    // Badge triggers
    if (!newBadges.contains('first_response')) newBadges.add('first_response');
    if (!newBadges.contains('rapid_responder')) newBadges.add('rapid_responder');
    if (isOffline && !newBadges.contains('offline_guardian')) newBadges.add('offline_guardian');
    if (emergencyType == 'ACCIDENT' && !newBadges.contains('accident_hero')) newBadges.add('accident_hero');

    final hour = DateTime.now().hour;
    if ((hour >= 21 || hour < 6) && !newBadges.contains('night_guardian')) {
      newBadges.add('night_guardian');
    }

    final contribution = ImpactContribution(
      emergencyId: emergencyId,
      emergencyType: emergencyType ?? (isOffline ? 'OFFLINE' : 'MEDICAL'),
      pointsEarned: points,
      description: 'Scene reached & arrival verified via GPS geofence',
      timestamp: DateTime.now(),
      isOffline: isOffline,
    );

    final updated = UserImpactProfile(
      impactPoints: profile.impactPoints + points,
      verifiedAssists: profile.verifiedAssists + 1,
      victimsReached: profile.victimsReached + 1,
      totalAccepted: profile.totalAccepted > 0 ? profile.totalAccepted : profile.verifiedAssists + 1,
      unlockedBadgeIds: newBadges,
      recentContributions: [contribution, ...profile.recentContributions].take(10).toList(),
    );

    await _saveProfile(userId, updated);
    return points;
  }

  /// Awards completion & resolution points when emergency is finished
  Future<int> recordEmergencyCompleted({
    required String userId,
    required String emergencyId,
    required bool isPrimary,
    required bool isOffline,
    String? emergencyType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final awardKey = 'completion_${userId}_$emergencyId';
    final processedAwards = prefs.getStringList('$_processedAwardsKey$userId') ?? [];

    if (processedAwards.contains(awardKey)) {
      return 0; // Already awarded for this emergency completion
    }

    processedAwards.add(awardKey);
    await prefs.setStringList('$_processedAwardsKey$userId', processedAwards);

    // Completion points: +10 pts
    int points = 10;
    if (isOffline) points += 2;

    final profile = await getImpactProfile(userId);
    final List<String> newBadges = List.from(profile.unlockedBadgeIds);

    if (!newBadges.contains('first_response')) newBadges.add('first_response');
    if (profile.reliabilityScore >= 90.0 && profile.verifiedAssists >= 5 && !newBadges.contains('reliable_shield')) {
      newBadges.add('reliable_shield');
    }

    final contribution = ImpactContribution(
      emergencyId: emergencyId,
      emergencyType: emergencyType ?? (isOffline ? 'OFFLINE' : 'GENERAL'),
      pointsEarned: points,
      description: 'Emergency successfully resolved & closed',
      timestamp: DateTime.now(),
      isOffline: isOffline,
    );

    final updated = UserImpactProfile(
      impactPoints: profile.impactPoints + points,
      verifiedAssists: profile.verifiedAssists,
      victimsReached: profile.victimsReached,
      totalAccepted: profile.totalAccepted,
      unlockedBadgeIds: newBadges,
      recentContributions: [contribution, ...profile.recentContributions].take(10).toList(),
    );

    await _saveProfile(userId, updated);
    return points;
  }

  /// Victim feedback verification (+10 points to helper)
  Future<int> recordVictimFeedback({
    required String helperId,
    required String emergencyId,
    required bool wasHelpful,
  }) async {
    if (!wasHelpful) return 0;

    final prefs = await SharedPreferences.getInstance();
    final awardKey = 'victim_feedback_${helperId}_$emergencyId';
    final processedAwards = prefs.getStringList('$_processedAwardsKey$helperId') ?? [];

    if (processedAwards.contains(awardKey)) {
      return 0;
    }

    processedAwards.add(awardKey);
    await prefs.setStringList('$_processedAwardsKey$helperId', processedAwards);

    const int points = 10;
    final profile = await getImpactProfile(helperId);

    final contribution = ImpactContribution(
      emergencyId: emergencyId,
      emergencyType: 'VERIFIED_HELP',
      pointsEarned: points,
      description: 'Victim confirmed helpful assistance received',
      timestamp: DateTime.now(),
    );

    final updated = UserImpactProfile(
      impactPoints: profile.impactPoints + points,
      verifiedAssists: profile.verifiedAssists,
      victimsReached: profile.victimsReached,
      totalAccepted: profile.totalAccepted,
      unlockedBadgeIds: profile.unlockedBadgeIds,
      recentContributions: [contribution, ...profile.recentContributions].take(10).toList(),
    );

    await _saveProfile(helperId, updated);
    return points;
  }

  /// Internal save to SharedPreferences and Firestore
  Future<void> _saveProfile(String userId, UserImpactProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final profileMap = profile.toMap();

    // 1. Local Cache
    await prefs.setString('$_prefsKeyPrefix$userId', jsonEncode(profileMap));

    // 2. Firestore Sync
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser != null && userId == auth.currentUser!.uid) {
        final firestore = FirebaseFirestore.instance;
        await firestore.collection('users').doc(userId).set({
          'impactProfile': profileMap,
          'impactPoints': profile.impactPoints,
          'verifiedAssists': profile.verifiedAssists,
          'victimsReached': profile.victimsReached,
          'reliabilityScore': profile.reliabilityScore,
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  /// Gets list of badge objects with unlock state populated
  Future<List<ImpactBadge>> getBadgesWithState([String? userId]) async {
    final profile = await getImpactProfile(userId);
    return allBadgeDefinitions.map((def) {
      final isUnlocked = profile.unlockedBadgeIds.contains(def.id);
      return ImpactBadge(
        id: def.id,
        title: def.title,
        description: def.description,
        icon: def.icon,
        color: def.color,
        isUnlocked: isUnlocked,
      );
    }).toList();
  }
}
