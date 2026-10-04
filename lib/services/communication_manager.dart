import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'connectivity_service.dart';
import 'communication_service_interface.dart';
import 'online_communication_service.dart';
import 'offline_communication_service.dart';
import 'local_database_service.dart';
import '../models/communication_mode.dart';
import '../models/emergency_model.dart';
import '../core/constants/app_constants.dart';

class CommunicationManager {
  static final CommunicationManager _instance = CommunicationManager._internal();
  factory CommunicationManager() => _instance;
  CommunicationManager._internal();

  final ConnectivityService _connectivityService = ConnectivityService();
  final OnlineCommunicationService _onlineService = OnlineCommunicationService();
  final OfflineCommunicationService _offlineService = OfflineCommunicationService();
  final LocalDatabaseService _localDb = LocalDatabaseService();

  ICommunicationService? _activeService;
  CommunicationMode _activeMode = CommunicationMode.offline;
  StreamSubscription<CommunicationMode>? _modeSub;
  bool _isTransitioning = false;

  CommunicationMode get activeMode => _activeMode;
  Stream<CommunicationMode> get modeStream => _connectivityService.modeStream;

  void initialize() {
    _connectivityService.initialize();
    _activeMode = _connectivityService.currentMode;
    _updateActiveService(_activeMode);

    _modeSub?.cancel();
    _modeSub = _connectivityService.modeStream.listen((newMode) {
      if (newMode != _activeMode) {
        _handleModeTransition(_activeMode, newMode);
      }
    });
  }

  void _updateActiveService(CommunicationMode mode) {
    _activeMode = mode;
    if (mode == CommunicationMode.online) {
      _activeService = _onlineService;
    } else {
      _activeService = _offlineService;
    }
  }

  Future<void> _handleModeTransition(
      CommunicationMode oldMode, CommunicationMode newMode) async {
    if (_isTransitioning) return;
    _isTransitioning = true;

    try {
      // 1. Stop current active transport cleanly
      if (oldMode == CommunicationMode.online) {
        await _onlineService.stop();
      } else {
        await _offlineService.stop();
      }

      // 2. Switch mode
      _updateActiveService(newMode);

      // 3. If transitioning OFFLINE -> ONLINE, safely sync unsynchronized offline emergencies to Firestore
      if (oldMode == CommunicationMode.offline &&
          newMode == CommunicationMode.online) {
        await syncOfflineEmergencyToFirestore();
      }
    } finally {
      _isTransitioning = false;
    }
  }

  Future<String> broadcastSOS({
    required Position position,
    required String currentUserId,
  }) async {
    return await _activeService!
        .broadcastSOS(position: position, currentUserId: currentUserId);
  }

  Stream<List<EmergencyModel>> listenForAlerts({
    required double userLat,
    required double userLon,
    required String currentUserId,
  }) {
    return _activeService!.listenForAlerts(
        userLat: userLat, userLon: userLon, currentUserId: currentUserId);
  }

  /// Safely upload unsynchronized offline emergency records to Firestore
  Future<void> syncOfflineEmergencyToFirestore() async {
    List<EmergencyModel> unsynced = await _localDb.getUnsyncedEmergencies();
    for (var emergency in unsynced) {
      try {
        await FirebaseFirestore.instance
            .collection(AppConstants.emergenciesCollection)
            .doc(emergency.id)
            .set(emergency.toMap(), SetOptions(merge: true));

        await _localDb.markAsSynced(emergency.id);
      } catch (_) {}
    }
  }

  void dispose() {
    _modeSub?.cancel();
    _activeService?.stop();
    _connectivityService.dispose();
  }
}
