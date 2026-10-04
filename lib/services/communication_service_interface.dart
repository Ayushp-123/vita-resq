import 'package:geolocator/geolocator.dart';
import '../models/emergency_model.dart';

abstract class ICommunicationService {
  Future<String> broadcastSOS({
    required Position position,
    required String currentUserId,
  });

  Stream<List<EmergencyModel>> listenForAlerts({
    required double userLat,
    required double userLon,
    required String currentUserId,
  });

  Future<void> stop();
}
