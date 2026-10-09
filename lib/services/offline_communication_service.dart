import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'communication_service_interface.dart';
import 'offline_nearby_service.dart';
import 'local_database_service.dart';
import 'notification_service.dart';
import 'p2p_diagnostics.dart';
import '../models/emergency_model.dart';

class OfflineCommunicationService implements ICommunicationService {
  final OfflineNearbyService _nearbyService;
  final LocalDatabaseService _localDb;

  static const int maxOfflineFreshnessMinutes = 60;

  /// Session-level deduplication set to avoid repeated notifications for the same emergency.
  static final Set<String> _notifiedEmergencyIds = {};

  static void clearNotifiedAlertsForTesting() {
    _notifiedEmergencyIds.clear();
  }

  /// Validates whether an offline emergency timestamp is within the acceptable freshness window.
  /// Uses absolute time difference to absorb clock skew in either direction up to 60 minutes.
  static bool isOfflineAlertFresh(DateTime createdAt, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    final diffMinutes = currentTime.difference(createdAt).inMinutes.abs();
    return diffMinutes <= maxOfflineFreshnessMinutes;
  }

  /// Validates a raw timestamp (milliseconds since epoch) from a P2P payload.
  /// Rejects null, non-num, non-positive, or timestamps outside the 60-minute window.
  static bool isValidAndFreshCreationTimestamp(dynamic rawTimestamp, {DateTime? now}) {
    if (rawTimestamp == null || rawTimestamp is! num) return false;
    final millis = rawTimestamp.toInt();
    if (millis <= 0) return false;
    final createdAt = DateTime.fromMillisecondsSinceEpoch(millis);
    return isOfflineAlertFresh(createdAt, now: now);
  }

  OfflineCommunicationService({
    OfflineNearbyService? nearbyService,
    LocalDatabaseService? localDb,
  })  : _nearbyService = nearbyService ?? OfflineNearbyService(),
        _localDb = localDb ?? LocalDatabaseService();

  @override
  Future<String> broadcastSOS({
    required Position position,
    required String currentUserId,
  }) async {
    String emergencyId = "JS-OFF-${DateTime.now().millisecondsSinceEpoch}";
    String originDeviceId = await LocalDatabaseService.getOrCreateLocalDeviceId();

    EmergencyModel localEmergency = EmergencyModel(
      id: emergencyId,
      victimId: currentUserId,
      originDeviceId: originDeviceId,
      type: 'MEDICAL',
      latitude: position.latitude,
      longitude: position.longitude,
      status: EmergencyStatus.SEARCHING,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Save locally
    await _localDb.saveEmergencyLocally(localEmergency);
    P2PDiagnostics.log(emergencyId, 'LOCAL_DB_PERSISTED', {
      'role': 'VICTIM',
      'originDeviceId': originDeviceId,
    });

    // Broadcast via P2P Nearby Connections
    await _nearbyService.startSOSBroadcast(
      emergencyId: emergencyId,
      latitude: position.latitude,
      longitude: position.longitude,
      victimId: currentUserId,
      originDeviceId: originDeviceId,
    );

    return emergencyId;
  }

  @override
  Stream<List<EmergencyModel>> listenForAlerts({
    required double userLat,
    required double userLon,
    required String currentUserId,
  }) {
    StreamSubscription? localUpdatesSub;
    Map<String, EmergencyModel> alertMap = {};
    late StreamController<List<EmergencyModel>> controller;

    controller = StreamController<List<EmergencyModel>>.broadcast(
      onListen: () {
        // Pre-populate with non-terminal emergencies from local DB (excluding own device and stale emergencies)
        _localDb.getAllLocalEmergencies().then((list) async {
          final myDeviceId = await LocalDatabaseService.getOrCreateLocalDeviceId();
          for (var e in list) {
            if (!e.isTerminal) {
              final isOwnDev = e.originDeviceId != null && e.originDeviceId == myDeviceId;
              final isOwnUser = currentUserId != 'offline_user' && e.victimId == currentUserId;
              final isFresh = !e.isOffline || isOfflineAlertFresh(e.createdAt);
              if (!isOwnDev && !isOwnUser && isFresh) {
                alertMap[e.id] = e;
              }
            }
          }
          if (!controller.isClosed && alertMap.isNotEmpty) {
            controller.add(alertMap.values.where((e) => !e.isTerminal).toList());
          }
        });

        localUpdatesSub = LocalDatabaseService.emergencyUpdatesStream.listen((updated) async {
          final myDeviceId = await LocalDatabaseService.getOrCreateLocalDeviceId();
          final isOwnDev = updated.originDeviceId != null && updated.originDeviceId == myDeviceId;
          final isOwnUser = currentUserId != 'offline_user' && updated.victimId == currentUserId;
          if (isOwnDev || isOwnUser) return;

          if (updated.isTerminal) {
            alertMap.remove(updated.id);
          } else {
            // Keep active updates if valid/fresh
            if (!updated.isOffline || isOfflineAlertFresh(updated.createdAt)) {
              alertMap[updated.id] = updated;
            } else {
              alertMap.remove(updated.id);
            }
          }
          if (!controller.isClosed) {
            controller.add(alertMap.values.where((e) => !e.isTerminal).toList());
          }
        });
      },
      onCancel: () {
        localUpdatesSub?.cancel();
        _nearbyService.stopSOSDiscovery();
      },
    );

    _nearbyService.startSOSDiscovery(
      currentUserId: currentUserId,
      onSOSDiscovered: (data) async {
        if (data.containsKey('emergencyId')) {
          String id = data['emergencyId'];
          String victimId = data['victimId'] ?? '';
          String? originDeviceId = data['originDeviceId'];
          String myDeviceId = await LocalDatabaseService.getOrCreateLocalDeviceId();

          // Safe self-suppression:
          // 1. If originDeviceId matches this local installation's deviceId, suppress.
          if (originDeviceId != null && originDeviceId.isNotEmpty && originDeviceId == myDeviceId) {
            P2PDiagnostics.log(id, 'ALERT_SUPPRESSED_OWN_DEVICE', {'originDeviceId': originDeviceId});
            return;
          }

          // 2. If authenticated online UID is known and matches victimId (non-generic), suppress.
          if (victimId.isNotEmpty && victimId != 'offline_user' && currentUserId != 'offline_user' && victimId == currentUserId) {
            P2PDiagnostics.log(id, 'ALERT_SUPPRESSED_OWN_USER', {'victimId': victimId});
            return;
          }

          // If emergency is already known locally as terminal, do not add as active
          EmergencyModel? existingLocal = await _localDb.getEmergencyById(id);
          if (existingLocal != null && existingLocal.isTerminal) {
            alertMap.remove(id);
            if (!controller.isClosed) {
              controller.add(alertMap.values.where((e) => !e.isTerminal).toList());
            }
            return;
          }

          // INGRESS FRESHNESS VALIDATION:
          // Validate sender's creation timestamp before persisting, notifying, or exposing
          final rawTimestamp = data['timestamp'];
          final isFresh = isValidAndFreshCreationTimestamp(rawTimestamp);
          if (!isFresh) {
            final skewMinutes = (rawTimestamp is num && rawTimestamp > 0)
                ? DateTime.now()
                    .difference(DateTime.fromMillisecondsSinceEpoch(rawTimestamp.toInt()))
                    .inMinutes
                    .abs()
                : -1;
            P2PDiagnostics.log(id, 'ALERT_INGRESS_DROPPED_STALE', {
              'rawTimestamp': rawTimestamp,
              'skewMinutes': skewMinutes,
            });
            return;
          }

          EmergencyModel emergency = EmergencyModel(
            id: id,
            victimId: victimId,
            originDeviceId: originDeviceId,
            type: data['type'] ?? 'MEDICAL',
            latitude: (data['latitude'] as num).toDouble(),
            longitude: (data['longitude'] as num).toDouble(),
            status: EmergencyStatus.SEARCHING,
            createdAt: DateTime.fromMillisecondsSinceEpoch((rawTimestamp as num).toInt()),
            updatedAt: DateTime.now(),
          );

          alertMap[id] = emergency;
          await _localDb.saveEmergencyLocally(emergency);
          P2PDiagnostics.log(id, 'LOCAL_DB_PERSISTED', {'isOffline': true});
          if (!controller.isClosed) {
            controller.add(alertMap.values.where((e) => !e.isTerminal).toList());
          }

          // Session-level notification deduplication: avoid duplicate alerts on repeated packets
          if (!_notifiedEmergencyIds.contains(id)) {
            _notifiedEmergencyIds.add(id);

            final distMeters = Geolocator.distanceBetween(
              userLat,
              userLon,
              emergency.latitude,
              emergency.longitude,
            );

            NotificationService.showEmergencyAlertNotification(
              emergencyId: emergency.id,
              type: emergency.type,
              distanceMeters: distMeters,
              isOffline: true,
              status: emergency.status,
            );
            P2PDiagnostics.log(id, 'NOTIFICATION_TRIGGERED', {'status': emergency.status.name});
          }
        }
      },
    );

    return controller.stream;
  }

  @override
  Future<void> stop() async {
    _notifiedEmergencyIds.clear();
    await _nearbyService.stopAll();
  }
}
