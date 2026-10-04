import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'communication_service_interface.dart';
import 'emergency_service.dart';
import '../models/emergency_model.dart';

class OnlineCommunicationService implements ICommunicationService {
  EmergencyService get _emergencyService => EmergencyService();
  StreamSubscription? _alertSub;

  @override
  Future<String> broadcastSOS({
    required Position position,
    required String currentUserId,
  }) async {
    return await _emergencyService.createSOS(position, victimId: currentUserId);
  }

  @override
  Stream<List<EmergencyModel>> listenForAlerts({
    required double userLat,
    required double userLon,
    required String currentUserId,
  }) {
    _alertSub?.cancel();
    final controller = StreamController<List<EmergencyModel>>.broadcast(
      onCancel: () {
        _alertSub?.cancel();
      },
    );

    _alertSub = _emergencyService
        .streamNearbySearchingEmergencies(userLat, userLon)
        .listen(
      (data) {
        if (!controller.isClosed) controller.add(data);
      },
      onError: (err) {
        if (!controller.isClosed) controller.addError(err);
      },
    );

    return controller.stream;
  }

  @override
  Future<void> stop() async {
    await _alertSub?.cancel();
    _alertSub = null;
  }
}
