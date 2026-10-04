import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_model.dart';

class LocalDatabaseService {
  static const String _legacyOfflineEmergenciesKey = 'offline_emergencies';
  static const String _emergencyKeyPrefix = 'offline_emergency_';
  static const String _emergencyIndexKey = 'offline_emergency_index';

  static final StreamController<EmergencyModel> _emergencyUpdatesController =
      StreamController<EmergencyModel>.broadcast();

  /// Stream of local emergency updates for offline real-time UI refresh
  static Stream<EmergencyModel> get emergencyUpdatesStream => _emergencyUpdatesController.stream;

  /// Stream reactive updates for a specific emergency ID, emitting the latest
  /// stored record first, followed by real-time updates.
  Stream<EmergencyModel?> streamEmergency(String emergencyId) async* {
    EmergencyModel? initial = await getEmergencyById(emergencyId);
    yield initial;
    yield* _emergencyUpdatesController.stream.where((e) => e.id == emergencyId);
  }

  // Mutex for serializing read-modify-write operations in memory
  static Future<void> _writeLock = Future.value();

  static Future<T> _synchronized<T>(Future<T> Function() computation) {
    final completer = Completer<T>();
    _writeLock = _writeLock.then((_) async {
      try {
        final result = await computation();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
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
