import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'communication_service_interface.dart';
import 'offline_nearby_service.dart';
import 'local_database_service.dart';
import '../models/emergency_model.dart';

class OfflineCommunicationService implements ICommunicationService {
  final OfflineNearbyService _nearbyService = OfflineNearbyService();
  final LocalDatabaseService _localDb = LocalDatabaseService();

  @override
  Future<String> broadcastSOS({
    required Position position,
    required String currentUserId,
  }) async {
    String emergencyId = "JS-OFF-${DateTime.now().millisecondsSinceEpoch}";

    EmergencyModel localEmergency = EmergencyModel(
      id: emergencyId,
      victimId: currentUserId,
      type: 'MEDICAL',
      latitude: position.latitude,
      longitude: position.longitude,
      status: EmergencyStatus.SEARCHING,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Save locally
    await _localDb.saveEmergencyLocally(localEmergency);

    // Broadcast via P2P Nearby Connections
    await _nearbyService.startSOSBroadcast(
      emergencyId: emergencyId,
      latitude: position.latitude,
      longitude: position.longitude,
      victimId: currentUserId,
    );

    return emergencyId;
  }

  @override
  Stream<List<EmergencyModel>> listenForAlerts({
    required double userLat,
    required double userLon,
    required String currentUserId,
  }) {
    StreamController<List<EmergencyModel>> controller = StreamController.broadcast();
    Map<String, EmergencyModel> alertMap = {};

    _nearbyService.startSOSDiscovery(
      currentUserId: currentUserId,
      onSOSDiscovered: (data) async {
        if (data.containsKey('emergencyId')) {
          String id = data['emergencyId'];
          String victimId = data['victimId'] ?? '';

          // Do NOT alert the victim about their own emergency!
          if (victimId.isNotEmpty && victimId == currentUserId) {
            return;
          }

          EmergencyModel emergency = EmergencyModel(
            id: id,
            victimId: victimId,
            type: data['type'] ?? 'MEDICAL',
            latitude: (data['latitude'] as num).toDouble(),
            longitude: (data['longitude'] as num).toDouble(),
            status: EmergencyStatus.SEARCHING,
            createdAt: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch),
            updatedAt: DateTime.now(),
          );

          alertMap[id] = emergency;
          await _localDb.saveEmergencyLocally(emergency);
          controller.add(alertMap.values.toList());
        }
      },
    );

    return controller.stream;
  }

  @override
  Future<void> stop() async {
    await _nearbyService.stopAll();
  }
}
