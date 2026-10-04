import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/emergency_model.dart';
import '../models/responder_model.dart';
import '../models/user_model.dart';
import '../core/constants/app_constants.dart';
import 'local_database_service.dart';
import 'offline_nearby_service.dart';
import 'auth_service.dart';

class ProblemReportResult {
  final bool success;
  final bool hasNewPrimary;
  final String? newPrimaryId;
  final String? newPrimaryName;
  final String message;

  const ProblemReportResult({
    required this.success,
    this.hasNewPrimary = false,
    this.newPrimaryId,
    this.newPrimaryName,
    required this.message,
  });
}

class EmergencyService {
  final FirebaseFirestore? _injectedFirestore;
  final FirebaseAuth? _injectedAuth;

  EmergencyService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _injectedFirestore = firestore,
        _injectedAuth = auth;

  FirebaseFirestore get _firestore => _injectedFirestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _injectedAuth ?? FirebaseAuth.instance;

  /// Create new emergency document in Firestore with initial 500m radius stage
  Future<String> createSOS(Position position, {String? victimId}) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("User not authenticated");

    final effectiveVictimId = victimId ?? currentUser.uid;
    if (effectiveVictimId != currentUser.uid) {
      throw Exception("Cannot create emergency: victimId mismatch with authenticated user");
    }

    String emergencyId = _firestore.collection(AppConstants.emergenciesCollection).doc().id;

    EmergencyModel newEmergency = EmergencyModel(
      id: emergencyId,
      victimId: effectiveVictimId,
      type: 'MEDICAL',
      latitude: position.latitude,
      longitude: position.longitude,
      status: EmergencyStatus.SEARCHING,
      currentRadiusMeters: AppConstants.initialEmergencyRadiusMeters,
      notifiedUserIds: [],
      responders: {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      lastVictimLocation: {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );

    try {
      await _firestore
          .collection(AppConstants.emergenciesCollection)
          .doc(emergencyId)
          .set(newEmergency.toMap());
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception(
          'Emergency dispatch rejected by cloud security policy: [cloud_firestore/permission-denied]. '
          'Verify that authenticated UID (${currentUser.uid}) matches ownership and Firestore security rules are deployed.',
        );
      }
      rethrow;
    }

    // Schedule automated expanding radius stages (500m -> 1km -> 2km -> 5km)
    _startExpandingRadiusTimer(emergencyId);

    return emergencyId;
  }

  /// Automatically expand search radius stage over time if no helper assigned
  void _startExpandingRadiusTimer(String emergencyId) async {
    List<double> stages = [1000.0, 2000.0, 5000.0];
    for (double nextRadius in stages) {
      await Future.delayed(const Duration(seconds: 20));
      DocumentSnapshot snap = await _firestore
          .collection(AppConstants.emergenciesCollection)
          .doc(emergencyId)
          .get();

      if (!snap.exists) break;
      var emergency = EmergencyModel.fromMap(snap.data() as Map<String, dynamic>, snap.id);

      // Stop expansion if helper already assigned or emergency completed/cancelled
      if (emergency.status != EmergencyStatus.SEARCHING) break;

      // Expand to next stage without invalidating previous recipients
      await _firestore
          .collection(AppConstants.emergenciesCollection)
          .doc(emergencyId)
          .update({
        'currentRadiusMeters': nextRadius,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Update emergency status (e.g. ARRIVED, COMPLETED, CANCELLED)
  Future<void> updateEmergencyStatus(
    String emergencyId,
    EmergencyStatus status, {
    String? responderId,
  }) async {
    // OFFLINE BRANCH
    if (emergencyId.startsWith('JS-OFF-')) {
      LocalDatabaseService localDb = LocalDatabaseService();
      EmergencyModel? existing = await localDb.getEmergencyById(emergencyId);
      if (existing != null) {
        Map<String, ResponderModel> updatedResponders = Map<String, ResponderModel>.from(existing.responders);
        if (responderId != null && updatedResponders.containsKey(responderId)) {
          ResponderModel r = updatedResponders[responderId]!;
          updatedResponders[responderId] = ResponderModel(
            userId: r.userId,
            userName: r.userName,
            phoneNumber: r.phoneNumber,
            bloodGroup: r.bloodGroup,
            role: r.role,
            status: ResponderStatus.values.firstWhere(
              (e) => e.name == status.name,
              orElse: () => r.status,
            ),
            latitude: r.latitude,
            longitude: r.longitude,
            acceptedAt: r.acceptedAt,
            lastLocationUpdate: DateTime.now(),
            assignedAt: r.assignedAt,
            distanceToVictim: r.distanceToVictim,
            etaText: r.etaText,
            etaMinutes: r.etaMinutes,
            problemReason: r.problemReason,
          );
        }

        EmergencyModel updated = EmergencyModel(
          id: existing.id,
          victimId: existing.victimId,
          type: existing.type,
          latitude: existing.latitude,
          longitude: existing.longitude,
          status: status,
          helperId: existing.helperId,
          currentRadiusMeters: existing.currentRadiusMeters,
          notifiedUserIds: existing.notifiedUserIds,
          responders: updatedResponders,
          createdAt: existing.createdAt,
          updatedAt: DateTime.now(),
          lastVictimLocation: existing.lastVictimLocation,
          lastHelperLocation: existing.lastHelperLocation,
        );

        await localDb.saveEmergencyLocally(updated);
        await OfflineNearbyService().sendStatusUpdatePayload(
          emergencyId: emergencyId,
          status: status.name,
          responderId: responderId,
        );
      }
      return;
    }

    // ONLINE BRANCH (Firestore)
    Map<String, dynamic> updates = {
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (responderId != null) {
      updates['responders.$responderId.status'] = (status == EmergencyStatus.ARRIVED)
          ? ResponderStatus.ARRIVED.name
          : (status == EmergencyStatus.COMPLETED)
              ? ResponderStatus.COMPLETED.name
              : ResponderStatus.RESPONDING.name;
      updates['responders.$responderId.lastLocationUpdate'] = FieldValue.serverTimestamp();
    }

    await _firestore
        .collection(AppConstants.emergenciesCollection)
        .doc(emergencyId)
        .update(updates);
  }

  static final Set<String> _declinedEmergencyIds = {};

  /// Record an emergency as declined by the user
  void markEmergencyDeclined(String emergencyId) {
    _declinedEmergencyIds.add(emergencyId);
  }

  /// Remove emergency from declined list if user changes mind
  void unmarkEmergencyDeclined(String emergencyId) {
    _declinedEmergencyIds.remove(emergencyId);
  }

  /// Check if emergency was declined by the user
  bool isEmergencyDeclined(String emergencyId) {
    return _declinedEmergencyIds.contains(emergencyId);
  }

  /// Update responder's live location and distance inside persistent responders map
  Future<void> updateResponderLocation({
    required String emergencyId,
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    // OFFLINE BRANCH
    if (emergencyId.startsWith('JS-OFF-')) {
      LocalDatabaseService localDb = LocalDatabaseService();
      EmergencyModel? existing = await localDb.getEmergencyById(emergencyId);
      if (existing != null) {
        Map<String, ResponderModel> updatedResponders = Map<String, ResponderModel>.from(existing.responders);
        if (updatedResponders.containsKey(userId)) {
          ResponderModel r = updatedResponders[userId]!;
          updatedResponders[userId] = ResponderModel(
            userId: r.userId,
            userName: r.userName,
            phoneNumber: r.phoneNumber,
            bloodGroup: r.bloodGroup,
            role: r.role,
            status: r.status,
            latitude: latitude,
            longitude: longitude,
            acceptedAt: r.acceptedAt,
            lastLocationUpdate: DateTime.now(),
            assignedAt: r.assignedAt,
            distanceToVictim: _calculateHaversineDistance(latitude, longitude, existing.latitude, existing.longitude),
            etaText: r.etaText,
            etaMinutes: r.etaMinutes,
            problemReason: r.problemReason,
          );
        }

        EmergencyModel updated = EmergencyModel(
          id: existing.id,
          victimId: existing.victimId,
          type: existing.type,
          latitude: existing.latitude,
          longitude: existing.longitude,
          status: existing.status,
          helperId: existing.helperId,
          currentRadiusMeters: existing.currentRadiusMeters,
          notifiedUserIds: existing.notifiedUserIds,
          responders: updatedResponders,
          createdAt: existing.createdAt,
          updatedAt: DateTime.now(),
          lastVictimLocation: existing.lastVictimLocation,
          lastHelperLocation: existing.helperId == userId
              ? {
                  'latitude': latitude,
                  'longitude': longitude,
                  'updatedAt': DateTime.now().toIso8601String(),
                }
              : existing.lastHelperLocation,
        );

        await localDb.saveEmergencyLocally(updated);
        await OfflineNearbyService().sendStatusUpdatePayload(
          emergencyId: emergencyId,
          status: existing.status.name,
          responderId: userId,
          latitude: latitude,
          longitude: longitude,
        );
      }
      return;
    }

    // ONLINE BRANCH
    DocumentReference ref = _firestore.collection(AppConstants.emergenciesCollection).doc(emergencyId);

    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot snap = await transaction.get(ref);
      if (!snap.exists) return;

      var data = snap.data() as Map<String, dynamic>;
      double victimLat = (data['latitude'] as num).toDouble();
      double victimLon = (data['longitude'] as num).toDouble();
      double distance = _calculateHaversineDistance(latitude, longitude, victimLat, victimLon);

      Map<String, dynamic> responders = Map<String, dynamic>.from(data['responders'] ?? {});
      if (responders.containsKey(userId)) {
        var rData = Map<String, dynamic>.from(responders[userId]);
        rData['latitude'] = latitude;
        rData['longitude'] = longitude;
        rData['distanceToVictim'] = distance;
        rData['lastLocationUpdate'] = Timestamp.now();
        responders[userId] = rData;

        Map<String, dynamic> updates = {
          'responders': responders,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (data['helperId'] == userId) {
          updates['lastHelperLocation'] = {
            'latitude': latitude,
            'longitude': longitude,
            'updatedAt': DateTime.now().toIso8601String(),
          };
        }

        transaction.update(ref, updates);
      }
    });
  }

  /// Report a problem / delay by Primary responder with automatic standby promotion
  Future<ProblemReportResult> reportProblem({
    required String emergencyId,
    required String userId,
    required String reason,
    required bool isFatal, // true = vehicle breakdown / personal emergency / cannot continue
  }) async {
    // ----------------------------------------------------
    // OFFLINE BRANCH
    // ----------------------------------------------------
    if (emergencyId.startsWith('JS-OFF-')) {
      LocalDatabaseService localDb = LocalDatabaseService();
      EmergencyModel? existing = await localDb.getEmergencyById(emergencyId);
      if (existing == null) {
        return const ProblemReportResult(success: false, message: 'Emergency not found.');
      }

      Map<String, ResponderModel> updatedResponders = Map<String, ResponderModel>.from(existing.responders);

      if (isFatal) {
        // 1. Demote the reporting primary responder to STANDBY / UNAVAILABLE
        if (updatedResponders.containsKey(userId)) {
          ResponderModel r = updatedResponders[userId]!;
          updatedResponders[userId] = ResponderModel(
            userId: r.userId,
            userName: r.userName,
            phoneNumber: r.phoneNumber,
            bloodGroup: r.bloodGroup,
            userRole: r.userRole,
            vehicleNumber: r.vehicleNumber,
            role: ResponderRole.STANDBY,
            status: ResponderStatus.UNAVAILABLE,
            latitude: r.latitude,
            longitude: r.longitude,
            acceptedAt: r.acceptedAt,
            lastLocationUpdate: DateTime.now(),
            assignedAt: r.assignedAt,
            problemReason: reason,
          );
        }

        // 2. Find available Standby candidates
        List<ResponderModel> standbyCandidates = updatedResponders.values
            .where((r) => r.userId != userId && (r.role == ResponderRole.STANDBY || r.role == ResponderRole.SECONDARY) && r.status != ResponderStatus.UNAVAILABLE)
            .toList();

        String? newPrimaryId;
        String? newPrimaryName;
        EmergencyStatus newEmergencyStatus;

        if (standbyCandidates.isNotEmpty) {
          // Sort standby candidates by distance to victim
          standbyCandidates.sort((a, b) {
            double distA = _calculateHaversineDistance(a.latitude, a.longitude, existing.latitude, existing.longitude);
            double distB = _calculateHaversineDistance(b.latitude, b.longitude, existing.latitude, existing.longitude);
            return distA.compareTo(distB);
          });

          ResponderModel best = standbyCandidates.first;
          newPrimaryId = best.userId;
          newPrimaryName = best.userName;
          newEmergencyStatus = EmergencyStatus.ASSIGNED;

          // Promote best candidate to PRIMARY
          updatedResponders[best.userId] = ResponderModel(
            userId: best.userId,
            userName: best.userName,
            phoneNumber: best.phoneNumber,
            bloodGroup: best.bloodGroup,
            userRole: best.userRole,
            vehicleNumber: best.vehicleNumber,
            role: ResponderRole.PRIMARY,
            status: ResponderStatus.RESPONDING,
            latitude: best.latitude,
            longitude: best.longitude,
            acceptedAt: best.acceptedAt,
            lastLocationUpdate: DateTime.now(),
            assignedAt: DateTime.now(),
          );
        } else {
          newPrimaryId = null;
          newEmergencyStatus = EmergencyStatus.SEARCHING;
        }

        EmergencyModel updated = EmergencyModel(
          id: existing.id,
          victimId: existing.victimId,
          type: existing.type,
          latitude: existing.latitude,
          longitude: existing.longitude,
          status: newEmergencyStatus,
          helperId: newPrimaryId,
          currentRadiusMeters: existing.currentRadiusMeters,
          notifiedUserIds: existing.notifiedUserIds,
          responders: updatedResponders,
          createdAt: existing.createdAt,
          updatedAt: DateTime.now(),
          lastVictimLocation: existing.lastVictimLocation,
          lastHelperLocation: newPrimaryId != null && updatedResponders.containsKey(newPrimaryId)
              ? {
                  'latitude': updatedResponders[newPrimaryId]!.latitude,
                  'longitude': updatedResponders[newPrimaryId]!.longitude,
                  'updatedAt': DateTime.now().toIso8601String(),
                }
              : null,
        );

        await localDb.saveEmergencyLocally(updated);
        await OfflineNearbyService().sendStatusUpdatePayload(
          emergencyId: emergencyId,
          status: newEmergencyStatus.name,
          responderId: newPrimaryId ?? userId,
          latitude: updated.latitude,
          longitude: updated.longitude,
        );

        return ProblemReportResult(
          success: true,
          hasNewPrimary: newPrimaryId != null,
          newPrimaryId: newPrimaryId,
          newPrimaryName: newPrimaryName,
          message: newPrimaryId != null
              ? 'Handover complete: Promoted $newPrimaryName to Primary.'
              : 'Handover complete: Emergency reset to searching.',
        );
      } else {
        // Minor delay
        if (updatedResponders.containsKey(userId)) {
          ResponderModel r = updatedResponders[userId]!;
          updatedResponders[userId] = ResponderModel(
            userId: r.userId,
            userName: r.userName,
            phoneNumber: r.phoneNumber,
            bloodGroup: r.bloodGroup,
            userRole: r.userRole,
            vehicleNumber: r.vehicleNumber,
            role: r.role,
            status: ResponderStatus.DELAYED,
            latitude: r.latitude,
            longitude: r.longitude,
            acceptedAt: r.acceptedAt,
            lastLocationUpdate: DateTime.now(),
            assignedAt: r.assignedAt,
            problemReason: reason,
          );

          EmergencyModel updated = EmergencyModel(
            id: existing.id,
            victimId: existing.victimId,
            type: existing.type,
            latitude: existing.latitude,
            longitude: existing.longitude,
            status: existing.status,
            helperId: existing.helperId,
            currentRadiusMeters: existing.currentRadiusMeters,
            notifiedUserIds: existing.notifiedUserIds,
            responders: updatedResponders,
            createdAt: existing.createdAt,
            updatedAt: DateTime.now(),
            lastVictimLocation: existing.lastVictimLocation,
            lastHelperLocation: existing.lastHelperLocation,
          );
          await localDb.saveEmergencyLocally(updated);
        }
        return const ProblemReportResult(success: true, message: 'Delay reported.');
      }
    }

    // ----------------------------------------------------
    // ONLINE BRANCH (Atomic Firestore Transaction)
    // ----------------------------------------------------
    DocumentReference ref = _firestore.collection(AppConstants.emergenciesCollection).doc(emergencyId);
    ProblemReportResult result = const ProblemReportResult(success: false, message: 'Transaction failed');

    try {
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snap = await transaction.get(ref);
        if (!snap.exists) return;

        var data = snap.data() as Map<String, dynamic>;
        Map<String, dynamic> responders = Map<String, dynamic>.from(data['responders'] ?? {});
        double victimLat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
        double victimLon = (data['longitude'] as num?)?.toDouble() ?? 0.0;

        if (isFatal) {
          // 1. Demote reporting primary responder to STANDBY & UNAVAILABLE
          if (responders.containsKey(userId)) {
            var pData = Map<String, dynamic>.from(responders[userId]);
            pData['role'] = ResponderRole.STANDBY.name;
            pData['status'] = ResponderStatus.UNAVAILABLE.name;
            pData['problemReason'] = reason;
            responders[userId] = pData;
          }

          // 2. Find available Standby candidates
          List<Map<String, dynamic>> standbyCandidates = [];
          responders.forEach((key, val) {
            if (key != userId && val is Map) {
              String rRole = val['role'] ?? '';
              String rStatus = val['status'] ?? '';
              if ((rRole == ResponderRole.STANDBY.name || rRole == ResponderRole.SECONDARY.name) &&
                  rStatus != ResponderStatus.UNAVAILABLE.name) {
                standbyCandidates.add(Map<String, dynamic>.from(val));
              }
            }
          });

          String? newPrimaryId;
          String? newPrimaryName;
          Map<String, dynamic> updates = {
            'responders': responders,
            'updatedAt': FieldValue.serverTimestamp(),
          };

          if (standbyCandidates.isNotEmpty) {
            // Sort by distance to victim
            standbyCandidates.sort((a, b) {
              double latA = (a['latitude'] as num?)?.toDouble() ?? 0.0;
              double lonA = (a['longitude'] as num?)?.toDouble() ?? 0.0;
              double latB = (b['latitude'] as num?)?.toDouble() ?? 0.0;
              double lonB = (b['longitude'] as num?)?.toDouble() ?? 0.0;
              double distA = _calculateHaversineDistance(latA, lonA, victimLat, victimLon);
              double distB = _calculateHaversineDistance(latB, lonB, victimLat, victimLon);
              return distA.compareTo(distB);
            });

            var best = standbyCandidates.first;
            newPrimaryId = best['userId'];
            newPrimaryName = best['userName'] ?? 'Standby Responder';

            var candidateData = Map<String, dynamic>.from(responders[newPrimaryId!]);
            candidateData['role'] = ResponderRole.PRIMARY.name;
            candidateData['status'] = ResponderStatus.RESPONDING.name;
            candidateData['assignedAt'] = Timestamp.now();
            responders[newPrimaryId] = candidateData;

            updates['helperId'] = newPrimaryId;
            updates['status'] = AppConstants.statusAssigned;
            updates['lastHelperLocation'] = {
              'latitude': candidateData['latitude'],
              'longitude': candidateData['longitude'],
              'updatedAt': DateTime.now().toIso8601String(),
            };

            result = ProblemReportResult(
              success: true,
              hasNewPrimary: true,
              newPrimaryId: newPrimaryId,
              newPrimaryName: newPrimaryName,
              message: 'Handover complete: Promoted $newPrimaryName to Primary.',
            );
          } else {
            // No standby responders available -> reset emergency to SEARCHING!
            updates['helperId'] = '';
            updates['status'] = AppConstants.statusSearching;
            updates['lastHelperLocation'] = FieldValue.delete();

            result = const ProblemReportResult(
              success: true,
              hasNewPrimary: false,
              message: 'Handover complete: Reset to searching for new responders.',
            );
          }

          transaction.update(ref, updates);
        } else {
          // Minor delay (e.g. Traffic Delay)
          if (responders.containsKey(userId)) {
            var pData = Map<String, dynamic>.from(responders[userId]);
            pData['status'] = ResponderStatus.DELAYED.name;
            pData['problemReason'] = reason;
            responders[userId] = pData;

            transaction.update(ref, {
              'responders': responders,
              'updatedAt': FieldValue.serverTimestamp(),
            });

            result = const ProblemReportResult(
              success: true,
              hasNewPrimary: false,
              message: 'Traffic delay recorded.',
            );
          }
        }
      });
      return result;
    } catch (e) {
      return ProblemReportResult(success: false, message: e.toString());
    }
  }

  /// Mark a user as notified to prevent duplicate notification spam
  Future<void> markUserNotified(String emergencyId, String userId) async {
    if (emergencyId.startsWith('JS-OFF-')) return;
    await _firestore
        .collection(AppConstants.emergenciesCollection)
        .doc(emergencyId)
        .update({
      'notifiedUserIds': FieldValue.arrayUnion([userId]),
    });
  }

  /// Pure read/state-sync stream of an active emergency
  Stream<EmergencyModel> streamEmergency(String emergencyId) {
    return _firestore
        .collection(AppConstants.emergenciesCollection)
        .doc(emergencyId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) throw Exception("Emergency document not found");
      return EmergencyModel.fromMap(doc.data()!, doc.id);
    });
  }

  /// Stream searching emergencies for active nearby users
  Stream<List<EmergencyModel>> streamNearbySearchingEmergencies(double userLat, double userLon) {
    String? currentUserId = _auth.currentUser?.uid;

    return _firestore
        .collection(AppConstants.emergenciesCollection)
        .where('status', isEqualTo: 'SEARCHING')
        .snapshots()
        .map((snapshot) {
      List<EmergencyModel> nearbyList = [];
      DateTime now = DateTime.now();

      for (var doc in snapshot.docs) {
        var emergency = EmergencyModel.fromMap(doc.data(), doc.id);
        if (emergency.victimId == currentUserId && currentUserId != null) {
          continue; // skip own emergency if logged in as victim
        }

        // Only allow active searching emergencies created within the last 10 minutes
        int diffMinutes = now.difference(emergency.createdAt).inMinutes.abs();
        if (diffMinutes > 10) {
          continue;
        }

        double distanceMeters = _calculateHaversineDistance(
          userLat,
          userLon,
          emergency.latitude,
          emergency.longitude,
        );

        // Generous radius check: check either dynamic radius or default 50km
        double allowedRadius = max(emergency.currentRadiusMeters, 50000.0);
        bool isWithinRadius = distanceMeters <= allowedRadius || (userLat == 0.0 && userLon == 0.0);
        bool isPreviouslyNotified = currentUserId != null && emergency.notifiedUserIds.contains(currentUserId);

        if (isWithinRadius || isPreviouslyNotified) {
          nearbyList.add(emergency);
        }
      }
      return nearbyList;
    });
  }

  /// Reset emergency to SEARCHING when Primary Helper cancels or disconnects
  Future<void> resetToSearching(String emergencyId) async {
    if (emergencyId.startsWith('JS-OFF-')) return;
    await _firestore
        .collection(AppConstants.emergenciesCollection)
        .doc(emergencyId)
        .update({
      'status': EmergencyStatus.SEARCHING.name,
      'helperId': FieldValue.delete(),
      'lastHelperLocation': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cancel emergency (by Victim)
  Future<void> cancelEmergency(String emergencyId) async {
    await updateEmergencyStatus(emergencyId, EmergencyStatus.CANCELLED);
  }

  double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    if (lat1 == 0.0 || lon1 == 0.0 || lat2 == 0.0 || lon2 == 0.0) return 0.0;
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }
}

/// Model representing a trusted emergency contact
class EmergencyContact {
  final String name;
  final String phoneNumber;
  final String relationship;

  EmergencyContact({
    required this.name,
    required this.phoneNumber,
    this.relationship = 'Family',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'relationship': relationship,
    };
  }

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      relationship: map['relationship'] ?? 'Family',
    );
  }
}

/// Service managing up to 3 trusted contacts and launching auto-SMS fallback
class EmergencyContactsService {
  static final EmergencyContactsService _instance = EmergencyContactsService._internal();
  factory EmergencyContactsService() => _instance;
  EmergencyContactsService._internal();

  static const String _contactsStorageKey = 'jan_sarthi_emergency_contacts_v1';

  /// Fetch saved emergency contacts (up to 3)
  Future<List<EmergencyContact>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonStr = prefs.getString(_contactsStorageKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        List<dynamic> list = jsonDecode(jsonStr);
        return list.map((item) => EmergencyContact.fromMap(item as Map<String, dynamic>)).toList();
      } catch (e) {
        if (kDebugMode) print('[CONTACTS] Error decoding contacts: $e');
      }
    }
    return [];
  }

  /// Save emergency contacts (max 3) and sync with Firestore user document
  Future<void> saveContacts(List<EmergencyContact> contacts) async {
    final limitedContacts = contacts.take(3).toList();
    final prefs = await SharedPreferences.getInstance();
    String jsonStr = jsonEncode(limitedContacts.map((c) => c.toMap()).toList());
    await prefs.setString(_contactsStorageKey, jsonStr);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .set({
          'emergencyContacts': limitedContacts.map((c) => c.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      if (kDebugMode) print('[CONTACTS] Firestore sync error: $e');
    }
  }

  static const MethodChannel _smsChannel = MethodChannel('com.example.jan_sarthi/sms');

  /// Send direct background SMS (Zero clicks required, silent background transmission for unconscious victims)
  Future<bool> sendDirectBackgroundSMS({
    required List<String> phoneNumbers,
    required String message,
  }) async {
    try {
      final bool? success = await _smsChannel.invokeMethod<bool>('sendDirectSms', {
        'phoneNumbers': phoneNumbers,
        'message': message,
      });
      return success ?? false;
    } catch (e) {
      if (kDebugMode) print('[DIRECT SMS] MethodChannel fallback: $e');
      return false;
    }
  }

  /// Format emergency message payload with victim details and Google Maps location
  static String formatEmergencyMessage({
    required double latitude,
    required double longitude,
    String type = 'EMERGENCY',
    String? victimName,
    String? victimPhone,
    String? bloodGroup,
  }) {
    String mapsUrl = 'https://maps.google.com/?q=${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}';

    StringBuffer sb = StringBuffer();
    sb.writeln('🚨 VITA RESQ CRITICAL EMERGENCY ALERT!');
    sb.writeln('Status: SOS Active ($type)');
    if (victimName != null && victimName.isNotEmpty) {
      sb.writeln('👤 Victim: $victimName');
    }
    if (victimPhone != null && victimPhone.isNotEmpty) {
      sb.writeln('📞 Contact: $victimPhone');
    }
    if (bloodGroup != null && bloodGroup.isNotEmpty) {
      sb.writeln('🩸 Blood Group: $bloodGroup');
    }
    sb.writeln('📍 Live Google Maps Location:');
    sb.writeln(mapsUrl);
    sb.writeln('⏰ Dispatched via Vita ResQ Emergency Response Network');

    return sb.toString().trim();
  }

  /// Construct intent-based SMS Uri with platform-appropriate recipient delimiter
  static Uri buildSmsUri({
    required List<String> phoneNumbers,
    required String message,
    bool? isIOS,
  }) {
    bool onIOS = isIOS ?? (Platform.isIOS);
    String separator = onIOS ? ',' : ';';
    String recipients = phoneNumbers.join(separator);
    return Uri(
      scheme: 'sms',
      path: recipients,
      queryParameters: <String, String>{
        'body': message,
      },
    );
  }

  /// Format and dispatch SMS via system SMS intent (Play Store compliant, intent-based)
  Future<bool> sendEmergencySMS({
    required double latitude,
    required double longitude,
    String type = 'EMERGENCY',
    String? victimName,
    String? victimPhone,
    String? bloodGroup,
  }) async {
    List<EmergencyContact> contacts = await getContacts();
    if (contacts.isEmpty) {
      if (kDebugMode) print('[CONTACTS] No emergency contacts configured.');
      return false;
    }

    // Try to load cached user profile if not provided
    if (victimName == null || bloodGroup == null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        UserModel? profile = await AuthService().getUserProfile(user.uid);
        if (profile != null) {
          victimName ??= profile.name;
          victimPhone ??= profile.phoneNumber;
          bloodGroup ??= profile.bloodGroup;
        }
      }
    }

    String message = formatEmergencyMessage(
      latitude: latitude,
      longitude: longitude,
      type: type,
      victimName: victimName,
      victimPhone: victimPhone,
      bloodGroup: bloodGroup,
    );

    List<String> phoneNumbers = contacts
        .map((c) => c.phoneNumber.trim())
        .where((phone) => phone.isNotEmpty)
        .toList();

    if (phoneNumbers.isEmpty) return false;

    // Intent-based SMS dispatch (compliant with Google Play permissions policy)
    final Uri smsUri = buildSmsUri(phoneNumbers: phoneNumbers, message: message);

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        // Fallback for single recipient or direct scheme parsing
        final Uri fallbackUri = Uri.parse('sms:${phoneNumbers.first}?body=${Uri.encodeComponent(message)}');
        if (await canLaunchUrl(fallbackUri)) {
          await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
          return true;
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) print('[CONTACTS] SMS intent launch failed: $e');
      return false;
    }
  }

  /// Dispatch emergency message directly to WhatsApp contact
  Future<bool> sendEmergencyWhatsApp({
    required double latitude,
    required double longitude,
    String type = 'EMERGENCY',
    String? specificPhoneNumber,
  }) async {
    List<EmergencyContact> contacts = await getContacts();
    if (contacts.isEmpty) return false;

    // Load victim profile
    String? victimName;
    String? victimPhone;
    String? bloodGroup;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      UserModel? profile = await AuthService().getUserProfile(user.uid);
      if (profile != null) {
        victimName = profile.name;
        victimPhone = profile.phoneNumber;
        bloodGroup = profile.bloodGroup;
      }
    }

    String mapsUrl = 'https://maps.google.com/?q=${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}';

    StringBuffer sb = StringBuffer();
    sb.writeln('🚨 *VITA RESQ CRITICAL EMERGENCY ALERT!*');
    sb.writeln('Status: SOS Active ($type)');
    if (victimName != null && victimName.isNotEmpty) {
      sb.writeln('👤 *Victim:* $victimName');
    }
    if (victimPhone != null && victimPhone.isNotEmpty) {
      sb.writeln('📞 *Contact:* $victimPhone');
    }
    if (bloodGroup != null && bloodGroup.isNotEmpty) {
      sb.writeln('🩸 *Blood Group:* $bloodGroup');
    }
    sb.writeln('📍 *Live Google Maps Location:*');
    sb.writeln(mapsUrl);
    sb.writeln('⏰ _Auto-Dispatched via Vita ResQ Emergency Response Network_');

    String message = sb.toString().trim();

    // Auto-normalize phone number with International Country Code (default: +91 India)
    String targetPhone = specificPhoneNumber ?? contacts.first.phoneNumber;
    String formattedPhone = normalizePhoneNumber(targetPhone);

    final Uri waUri = Uri.parse('whatsapp://send?phone=$formattedPhone&text=${Uri.encodeComponent(message)}');
    final Uri waMeUri = Uri.parse('https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}');
    final Uri webWaUri = Uri.parse('https://api.whatsapp.com/send?phone=$formattedPhone&text=${Uri.encodeComponent(message)}');

    try {
      if (await canLaunchUrl(waUri)) {
        await launchUrl(waUri, mode: LaunchMode.externalApplication);
        return true;
      } else if (await canLaunchUrl(waMeUri)) {
        await launchUrl(waMeUri, mode: LaunchMode.externalApplication);
        return true;
      } else if (await canLaunchUrl(webWaUri)) {
        await launchUrl(webWaUri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (e) {
      if (kDebugMode) print('[WHATSAPP] Launch error: $e');
    }
    return false;
  }

  /// Normalize any phone number with country code (+91 by default)
  static String normalizePhoneNumber(String phone, {String defaultCountryCode = '91'}) {
    String clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0') && clean.length == 11) {
      clean = clean.substring(1);
    }
    if (clean.length == 10) {
      clean = '$defaultCountryCode$clean';
    }
    return clean;
  }
}
