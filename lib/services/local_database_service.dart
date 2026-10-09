import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_model.dart';
import '../models/responder_model.dart';

class LocalDatabaseService {
  static const String _legacyOfflineEmergenciesKey = 'offline_emergencies';
  static const String _emergencyKeyPrefix = 'offline_emergency_';
  static const String _emergencyIndexKey = 'offline_emergency_index';
  static const String _localDeviceIdKey = 'local_installation_device_id';

  static String? _cachedLocalDeviceId;

  /// Returns a stable, locally persisted installation identifier.
  /// This ID is unique per installation/device, persists across app restarts,
  /// and is never used as a fake Firebase UID or auth proof.
  static Future<String> getOrCreateLocalDeviceId() async {
    if (_cachedLocalDeviceId != null && _cachedLocalDeviceId!.isNotEmpty) {
      return _cachedLocalDeviceId!;
    }
    final prefs = await SharedPreferences.getInstance();
    String? existing = prefs.getString(_localDeviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      _cachedLocalDeviceId = existing;
      return existing;
    }
    final random = math.Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final r1 = random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    final r2 = random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    final id = 'dev_${timestamp}_$r1$r2';
    await prefs.setString(_localDeviceIdKey, id);
    _cachedLocalDeviceId = id;
    return id;
  }

  /// Synchronous getter for already-cached device ID (null if not yet loaded)
  static String? get cachedLocalDeviceId => _cachedLocalDeviceId;

  /// Helper for testing to set or clear the cached device ID
  static void setLocalDeviceIdForTesting(String? id) {
    _cachedLocalDeviceId = id;
  }

  static final StreamController<EmergencyModel> _emergencyUpdatesController =
      StreamController<EmergencyModel>.broadcast();

  /// Stream of local emergency updates for offline real-time UI refresh
  static Stream<EmergencyModel> get emergencyUpdatesStream => _emergencyUpdatesController.stream;

  /// Broadcast an in-memory emergency update to all reactive listeners immediately
  static void broadcastUpdate(EmergencyModel emergency) {
    if (!_emergencyUpdatesController.isClosed) {
      _emergencyUpdatesController.add(emergency);
    }
  }

  /// Get the active emergency for the given user, or null if none active
  Future<EmergencyModel?> getActiveEmergency({String? userId}) async {
    final list = await getAllLocalEmergencies();
    final localDevId = _cachedLocalDeviceId ?? await getOrCreateLocalDeviceId();
    for (var e in list) {
      if (e.isActive) {
        if (userId == null) return e;
        final isOwnDevice = e.originDeviceId != null && e.originDeviceId == localDevId;
        final isOwnAuthUser = userId != 'offline_user' && e.isVictim(userId);
        if (isOwnDevice ||
            isOwnAuthUser ||
            e.isPrimaryResponder(userId) ||
            e.isStandbyResponder(userId)) {
          return e;
        }
      }
    }
    return null;
  }

  /// Stream reactive updates for a specific emergency ID, emitting the latest
  /// stored record first, followed by real-time updates.
  Stream<EmergencyModel?> streamEmergency(String emergencyId) async* {
    EmergencyModel? initial = await getEmergencyById(emergencyId);
    yield initial;
    yield* _emergencyUpdatesController.stream.where((e) => e.id == emergencyId);
  }

  // Mutex for serializing read-modify-write operations in memory
  static Future<void> _writeLock = Future.value();

  /// Reset the write lock for test isolation
  static void resetLockForTesting() {
    _writeLock = Future.value();
  }

  static Future<T> _synchronized<T>(Future<T> Function() computation) {
    final completer = Completer<T>();
    _writeLock = _writeLock.then((_) async {
      try {
        final result = await computation();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    }).catchError((_) {});
    return completer.future;
  }

  /// Save or update an emergency locally with isolated per-emergency storage
  /// and broadcast update event to reactive streams
  Future<void> saveEmergencyLocally(EmergencyModel emergency) async {
    return _synchronized(() async {
      final prefs = await SharedPreferences.getInstance();

      Map<String, dynamic> map = emergency.toMap();
      map['isSynced'] = false;
      Map<String, dynamic> jsonSafeMap = _makeJsonSafe(map) as Map<String, dynamic>;
      String jsonStr = jsonEncode(jsonSafeMap);

      // 1. Write to isolated per-emergency key
      String emergencyKey = '$_emergencyKeyPrefix${emergency.id}';
      await prefs.setString(emergencyKey, jsonStr);

      // 2. Update index list
      List<String> index = prefs.getStringList(_emergencyIndexKey) ?? [];
      if (!index.contains(emergency.id)) {
        index.add(emergency.id);
        await prefs.setStringList(_emergencyIndexKey, index);
      }

      // 3. Keep legacy list updated for backward compatibility
      _syncToLegacyList(prefs, emergency.id, jsonSafeMap);

      // Broadcast local update
      _emergencyUpdatesController.add(emergency);
    });
  }

  static void _syncToLegacyList(SharedPreferences prefs, String id, Map<String, dynamic> jsonSafeMap) {
    try {
      List<String> list = prefs.getStringList(_legacyOfflineEmergenciesKey) ?? [];
      list.removeWhere((item) {
        try {
          var existing = jsonDecode(item);
          return existing['id'] == id;
        } catch (_) {
          return false;
        }
      });
      list.add(jsonEncode(jsonSafeMap));
      prefs.setStringList(_legacyOfflineEmergenciesKey, list);
    } catch (_) {}
  }

  /// Get all locally saved emergencies (for offline history display)
  Future<List<EmergencyModel>> getAllLocalEmergencies() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> index = prefs.getStringList(_emergencyIndexKey) ?? [];
    Map<String, EmergencyModel> emergenciesMap = {};

    // 1. Read from isolated per-emergency keys
    for (String id in index) {
      String? jsonStr = prefs.getString('$_emergencyKeyPrefix$id');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        try {
          var map = jsonDecode(jsonStr);
          if (map is Map<String, dynamic>) {
            var restoredMap = _restoreFirestoreMap(map);
            emergenciesMap[id] = EmergencyModel.fromMap(restoredMap, restoredMap['id'] ?? id);
          }
        } catch (_) {}
      }
    }

    // 2. Check legacy list for any emergencies not yet in the index
    List<String> legacyList = prefs.getStringList(_legacyOfflineEmergenciesKey) ?? [];
    for (var item in legacyList) {
      try {
        var map = jsonDecode(item);
        if (map is Map<String, dynamic>) {
          String id = map['id'] ?? '';
          if (id.isNotEmpty && !emergenciesMap.containsKey(id)) {
            var restoredMap = _restoreFirestoreMap(map);
            emergenciesMap[id] = EmergencyModel.fromMap(restoredMap, id);
          }
        }
      } catch (_) {}
    }
    return emergenciesMap.values.toList();
  }

  /// Get unsynchronized offline emergencies
  Future<List<EmergencyModel>> getUnsyncedEmergencies() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> index = prefs.getStringList(_emergencyIndexKey) ?? [];
    Map<String, EmergencyModel> unsyncedMap = {};

    for (String id in index) {
      String? jsonStr = prefs.getString('$_emergencyKeyPrefix$id');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        try {
          var map = jsonDecode(jsonStr);
          if (map is Map<String, dynamic> && map['isSynced'] == false) {
            var restoredMap = _restoreFirestoreMap(map);
            unsyncedMap[id] = EmergencyModel.fromMap(restoredMap, restoredMap['id'] ?? id);
          }
        } catch (_) {}
      }
    }

    // Check legacy list for un-migrated items
    List<String> legacyList = prefs.getStringList(_legacyOfflineEmergenciesKey) ?? [];
    for (var item in legacyList) {
      try {
        var map = jsonDecode(item);
        if (map is Map<String, dynamic> && map['isSynced'] == false) {
          String id = map['id'] ?? '';
          if (id.isNotEmpty && !unsyncedMap.containsKey(id)) {
            var restoredMap = _restoreFirestoreMap(map);
            unsyncedMap[id] = EmergencyModel.fromMap(restoredMap, id);
          }
        }
      } catch (_) {}
    }
    return unsyncedMap.values.toList();
  }

  /// Mark emergency as synchronized
  Future<void> markAsSynced(String emergencyId) async {
    return _synchronized(() async {
      final prefs = await SharedPreferences.getInstance();

      // 1. Update isolated key
      String emergencyKey = '$_emergencyKeyPrefix$emergencyId';
      String? jsonStr = prefs.getString(emergencyKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        try {
          var map = jsonDecode(jsonStr);
          if (map is Map<String, dynamic>) {
            map['isSynced'] = true;
            await prefs.setString(emergencyKey, jsonEncode(map));
          }
        } catch (_) {}
      }

      // 2. Also update legacy list
      List<String> list = prefs.getStringList(_legacyOfflineEmergenciesKey) ?? [];
      List<String> updated = list.map((item) {
        try {
          var map = jsonDecode(item);
          if (map is Map<String, dynamic> && map['id'] == emergencyId) {
            map['isSynced'] = true;
            return jsonEncode(map);
          }
        } catch (_) {}
        return item;
      }).toList();
      await prefs.setStringList(_legacyOfflineEmergenciesKey, updated);
    });
  }

  /// Get an individual emergency by ID from local storage
  Future<EmergencyModel?> getEmergencyById(String emergencyId) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Check isolated per-emergency key first
    String emergencyKey = '$_emergencyKeyPrefix$emergencyId';
    String? jsonStr = prefs.getString(emergencyKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        var map = jsonDecode(jsonStr);
        if (map is Map<String, dynamic>) {
          var restoredMap = _restoreFirestoreMap(map);
          return EmergencyModel.fromMap(restoredMap, emergencyId);
        }
      } catch (_) {}
    }

    // 2. Fallback to legacy list for backward compatibility with auto-migration
    List<String> list = prefs.getStringList(_legacyOfflineEmergenciesKey) ?? [];
    for (var item in list) {
      try {
        var map = jsonDecode(item);
        if (map is Map<String, dynamic> && map['id'] == emergencyId) {
          var restoredMap = _restoreFirestoreMap(map);
          // Migrate to isolated key
          await prefs.setString(emergencyKey, item);
          List<String> index = prefs.getStringList(_emergencyIndexKey) ?? [];
          if (!index.contains(emergencyId)) {
            index.add(emergencyId);
            await prefs.setStringList(_emergencyIndexKey, index);
          }
          return EmergencyModel.fromMap(restoredMap, emergencyId);
        }
      } catch (_) {}
    }
    return null;
  }

  /// Update status of a locally stored emergency if it exists
  Future<void> updateEmergencyStatus(String emergencyId, EmergencyStatus status, {String? responderId}) async {
    EmergencyModel? existing = await getEmergencyById(emergencyId);
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
      await saveEmergencyLocally(updated);
    }
  }

  /// Recursively convert Firestore Timestamps and DateTimes into JSON-safe ISO-8601 strings
  static dynamic _makeJsonSafe(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    } else if (value is DateTime) {
      return value.toIso8601String();
    } else if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _makeJsonSafe(v)));
    } else if (value is List) {
      return value.map(_makeJsonSafe).toList();
    }
    return value;
  }

  /// Restore Firestore Timestamps from stored JSON-safe map so EmergencyModel.fromMap can parse it
  static Map<String, dynamic> _restoreFirestoreMap(Map<String, dynamic> jsonMap) {
    Map<String, dynamic> restored = Map<String, dynamic>.from(jsonMap);

    // 1. Top-level dates
    if (restored['createdAt'] is String) {
      try {
        restored['createdAt'] = Timestamp.fromDate(DateTime.parse(restored['createdAt']));
      } catch (_) {
        restored['createdAt'] = Timestamp.now();
      }
    } else if (restored['createdAt'] is int) {
      restored['createdAt'] = Timestamp.fromMillisecondsSinceEpoch(restored['createdAt']);
    }

    if (restored['updatedAt'] is String) {
      try {
        restored['updatedAt'] = Timestamp.fromDate(DateTime.parse(restored['updatedAt']));
      } catch (_) {
        restored['updatedAt'] = Timestamp.now();
      }
    } else if (restored['updatedAt'] is int) {
      restored['updatedAt'] = Timestamp.fromMillisecondsSinceEpoch(restored['updatedAt']);
    }

    // 2. Responders map dates
    if (restored['responders'] != null && restored['responders'] is Map) {
      Map<String, dynamic> responders = Map<String, dynamic>.from(restored['responders']);
      responders.forEach((key, val) {
        if (val is Map) {
          Map<String, dynamic> rMap = Map<String, dynamic>.from(val);
          if (rMap['acceptedAt'] is String) {
            try {
              rMap['acceptedAt'] = Timestamp.fromDate(DateTime.parse(rMap['acceptedAt']));
            } catch (_) {
              rMap['acceptedAt'] = Timestamp.now();
            }
          } else if (rMap['acceptedAt'] is int) {
            rMap['acceptedAt'] = Timestamp.fromMillisecondsSinceEpoch(rMap['acceptedAt']);
          }

          if (rMap['lastLocationUpdate'] is String) {
            try {
              rMap['lastLocationUpdate'] = Timestamp.fromDate(DateTime.parse(rMap['lastLocationUpdate']));
            } catch (_) {
              rMap['lastLocationUpdate'] = Timestamp.now();
            }
          } else if (rMap['lastLocationUpdate'] is int) {
            rMap['lastLocationUpdate'] = Timestamp.fromMillisecondsSinceEpoch(rMap['lastLocationUpdate']);
          }

          if (rMap['assignedAt'] != null) {
            if (rMap['assignedAt'] is String) {
              try {
                rMap['assignedAt'] = Timestamp.fromDate(DateTime.parse(rMap['assignedAt']));
              } catch (_) {
                rMap['assignedAt'] = null;
              }
            } else if (rMap['assignedAt'] is int) {
              rMap['assignedAt'] = Timestamp.fromMillisecondsSinceEpoch(rMap['assignedAt']);
            }
          }
          responders[key] = rMap;
        }
      });
      restored['responders'] = responders;
    }

    return restored;
  }
}
