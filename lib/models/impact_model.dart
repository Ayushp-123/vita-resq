import 'package:flutter/material.dart';

/// Achievement badge definition
class ImpactBadge {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const ImpactBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isUnlocked': isUnlocked,
      'unlockedAt': unlockedAt?.toIso8601String(),
    };
  }

  factory ImpactBadge.fromMap(Map<String, dynamic> map, ImpactBadge definition) {
    return ImpactBadge(
      id: definition.id,
      title: definition.title,
      description: definition.description,
      icon: definition.icon,
      color: definition.color,
      isUnlocked: map['isUnlocked'] ?? false,
      unlockedAt: map['unlockedAt'] != null ? DateTime.tryParse(map['unlockedAt']) : null,
    );
  }
}

/// Single contribution record for verified emergency help
class ImpactContribution {
  final String emergencyId;
  final String emergencyType; // MEDICAL, ACCIDENT, OFFLINE, GENERAL
  final int pointsEarned;
  final String description;
  final DateTime timestamp;
  final bool isOffline;

  const ImpactContribution({
    required this.emergencyId,
    required this.emergencyType,
    required this.pointsEarned,
    required this.description,
    required this.timestamp,
    this.isOffline = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'emergencyId': emergencyId,
      'emergencyType': emergencyType,
      'pointsEarned': pointsEarned,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'isOffline': isOffline,
    };
  }

  factory ImpactContribution.fromMap(Map<String, dynamic> map) {
    return ImpactContribution(
      emergencyId: map['emergencyId'] ?? '',
      emergencyType: map['emergencyType'] ?? 'GENERAL',
      pointsEarned: (map['pointsEarned'] as num?)?.toInt() ?? 0,
      description: map['description'] ?? 'Emergency assistance verified',
      timestamp: map['timestamp'] != null ? DateTime.tryParse(map['timestamp']) ?? DateTime.now() : DateTime.now(),
      isOffline: map['isOffline'] ?? false,
    );
  }
}

/// Recognition Level details
class ImpactLevel {
  final int levelNumber;
  final String title;
  final String badgeName;
  final int minPoints;
  final int maxPoints;
  final IconData icon;
  final Color color;

  const ImpactLevel({
    required this.levelNumber,
    required this.title,
    required this.badgeName,
    required this.minPoints,
    required this.maxPoints,
    required this.icon,
    required this.color,
  });

  double getProgress(int currentPoints) {
    if (currentPoints >= maxPoints) return 1.0;
    if (currentPoints <= minPoints) return 0.0;
    return (currentPoints - minPoints) / (maxPoints - minPoints);
  }

  int getPointsToNext(int currentPoints) {
    if (currentPoints >= maxPoints) return 0;
    return maxPoints - currentPoints;
  }
}

/// Aggregated user impact profile
class UserImpactProfile {
  final int impactPoints;
  final int verifiedAssists;
  final int victimsReached;
  final int totalAccepted;
  final List<String> unlockedBadgeIds;
  final List<ImpactContribution> recentContributions;

  const UserImpactProfile({
    this.impactPoints = 0,
    this.verifiedAssists = 0,
    this.victimsReached = 0,
    this.totalAccepted = 0,
    this.unlockedBadgeIds = const [],
    this.recentContributions = const [],
  });

  /// Reliability Score percentage (e.g. 94%)
  double get reliabilityScore {
    if (totalAccepted == 0) return 100.0;
    double score = (verifiedAssists / totalAccepted) * 100.0;
    return score.clamp(0.0, 100.0);
  }

  /// Calculates current recognition level
  ImpactLevel get currentLevel {
    if (impactPoints >= 500) {
      return const ImpactLevel(
        levelNumber: 5,
        title: 'Vita ResQ Champion',
        badgeName: 'CHAMPION',
        minPoints: 500,
        maxPoints: 1000,
        icon: Icons.workspace_premium_rounded,
        color: Color(0xFFEAB308), // Gold
      );
    } else if (impactPoints >= 300) {
      return const ImpactLevel(
        levelNumber: 4,
        title: 'Community Guardian',
        badgeName: 'GUARDIAN',
        minPoints: 300,
        maxPoints: 500,
        icon: Icons.shield_rounded,
        color: Color(0xFF3B82F6), // Blue
      );
    } else if (impactPoints >= 150) {
      return const ImpactLevel(
        levelNumber: 3,
        title: 'Trusted Responder',
        badgeName: 'TRUSTED',
        minPoints: 150,
        maxPoints: 300,
        icon: Icons.verified_user_rounded,
        color: Color(0xFF10B981), // Emerald
      );
    } else if (impactPoints >= 50) {
      return const ImpactLevel(
        levelNumber: 2,
        title: 'Vita ResQ Responder',
        badgeName: 'RESPONDER',
        minPoints: 50,
        maxPoints: 150,
        icon: Icons.local_hospital_rounded,
        color: Color(0xFFF97316), // Orange
      );
    } else {
      return const ImpactLevel(
        levelNumber: 1,
        title: 'Community Volunteer',
        badgeName: 'VOLUNTEER',
        minPoints: 0,
        maxPoints: 50,
        icon: Icons.volunteer_activism_rounded,
        color: Color(0xFF6B7280), // Slate
      );
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'impactPoints': impactPoints,
      'verifiedAssists': verifiedAssists,
      'victimsReached': victimsReached,
      'totalAccepted': totalAccepted,
      'unlockedBadgeIds': unlockedBadgeIds,
      'recentContributions': recentContributions.map((c) => c.toMap()).toList(),
    };
  }

  factory UserImpactProfile.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const UserImpactProfile();
    return UserImpactProfile(
      impactPoints: (map['impactPoints'] as num?)?.toInt() ?? 0,
      verifiedAssists: (map['verifiedAssists'] as num?)?.toInt() ?? 0,
      victimsReached: (map['victimsReached'] as num?)?.toInt() ?? 0,
      totalAccepted: (map['totalAccepted'] as num?)?.toInt() ?? 0,
      unlockedBadgeIds: List<String>.from(map['unlockedBadgeIds'] ?? []),
      recentContributions: (map['recentContributions'] as List<dynamic>?)
              ?.map((item) => ImpactContribution.fromMap(Map<String, dynamic>.from(item)))
              .toList() ??
          [],
    );
  }
}
