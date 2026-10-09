import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:geolocator/geolocator.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/emergency_model.dart';
import '../models/responder_model.dart';
import 'local_database_service.dart';
import 'p2p_diagnostics.dart';
import 'p2p_payload_integrity.dart';

class ClaimProcessResult {
  final bool accepted;
  final ResponderRole? role;
  final String? reason;
  final EmergencyModel? updatedEmergency;
  final Map<String, dynamic> ackPayload;

  ClaimProcessResult({
    required this.accepted,
    this.role,
    this.reason,
    this.updatedEmergency,
    required this.ackPayload,
  });
}

class OfflineNearbyService {
  static final OfflineNearbyService _instance = OfflineNearbyService._internal();
  factory OfflineNearbyService() => _instance;
  OfflineNearbyService._internal();

  final Strategy strategy = Strategy.P2P_STAR;
  final Map<String, ConnectionInfo> _connectedPeers = {};
  final Set<String> _connectedEndpoints = {};
  Function(Map<String, dynamic>)? onSOSReceivedCallback;

  bool _isAdvertising = false;
  bool _isDiscovering = false;
  int _discoverySubscribers = 0;
  final StreamController<Map<String, dynamic>> _sosDiscoveredController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get sosDiscoveredStream => _sosDiscoveredController.stream;
  bool get isAdvertising => _isAdvertising;
  bool get isDiscovering => _isDiscovering;

  final StreamController<Map<String, dynamic>> _claimAckController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of incoming CLAIM_ACK payloads for two-way handshake
  Stream<Map<String, dynamic>> get claimAckStream => _claimAckController.stream;

  bool get hasConnectedPeers => _connectedEndpoints.isNotEmpty;
  Set<String> get connectedEndpoints => Set.unmodifiable(_connectedEndpoints);

  void addConnectedEndpointForTesting(String endpointId) {
    _connectedEndpoints.add(endpointId);
  }

  void removeConnectedEndpointForTesting(String endpointId) {
    _connectedEndpoints.remove(endpointId);
  }

  void notifyClaimAckForTesting(Map<String, dynamic> ack) {
    _claimAckController.add(ack);
  }

  void triggerSOSDiscoveredForTesting(Map<String, dynamic> sosData) {
    onSOSReceivedCallback?.call(sosData);
  }

  /// Request permissions for Offline P2P (Bluetooth, Location, Nearby Devices)
  Future<bool> checkOfflinePermissions() async {
    bool isGpsEnabled = false;
    try {
      isGpsEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      // Graceful fallback for mock/test environments
      isGpsEnabled = true;
    }

    if (!isGpsEnabled) {
      P2PDiagnostics.log('PERM', 'GPS_DISABLED', {'status': 'DISABLED'});
    }

    Map<Permission, PermissionStatus> statuses = {};
    try {
      statuses = await [
        Permission.location,
        Permission.bluetooth,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.nearbyWifiDevices,
      ].request();
    } catch (e) {
      P2PDiagnostics.log('PERM', 'PERMISSION_REQUEST_EXCEPTION', {'error': e.toString()});
      return isGpsEnabled;
    }

    bool allGranted = statuses.values.every((status) => status.isGranted || status.isLimited);
    if (!allGranted) {
      final denied = statuses.entries
          .where((e) => !e.value.isGranted && !e.value.isLimited)
          .map((e) => e.key.toString())
          .join(', ');
      P2PDiagnostics.log('PERM', 'PERMISSIONS_DENIED', {'denied': denied});
    }

    return allGranted && isGpsEnabled;
  }

  /// Start P2P advertising (Victim broadcasting SOS to multiple nearby peers)
  Future<void> startSOSBroadcast({
    required String emergencyId,
    required double latitude,
    required double longitude,
    required String victimId,
    String? originDeviceId,
  }) async {
    originDeviceId ??= await LocalDatabaseService.getOrCreateLocalDeviceId();
    P2PDiagnostics.log(emergencyId, 'ADVERTISING_START', {
      'role': 'VICTIM',
      'originDeviceId': originDeviceId,
    });

    final permOk = await checkOfflinePermissions();
    if (!permOk) {
      P2PDiagnostics.log(emergencyId, 'ADVERTISING_WARNING', {'reason': 'PERMISSIONS_OR_GPS_MISSING'});
    }

    String userName = "JanSarthi_Victim_$victimId";

    Map<String, dynamic> payloadMap = {
      'eventType': 'SOS_BROADCAST',
      'emergencyId': emergencyId,
      'victimId': victimId,
      'originDeviceId': originDeviceId,
      'latitude': latitude,
      'longitude': longitude,
      'type': 'MEDICAL',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    payloadMap = P2PPayloadIntegrity.signPayload(payloadMap);
    String payloadJson = jsonEncode(payloadMap);

    if (_isAdvertising) {
      try {
        await Nearby().stopAdvertising();
      } catch (_) {}
      _isAdvertising = false;
    }

    try {
      await Nearby().startAdvertising(
        userName,
        strategy,
        onConnectionInitiated: (String id, ConnectionInfo info) async {
          _connectedPeers[id] = info;
          _connectedEndpoints.add(id);
          P2PDiagnostics.log(emergencyId, 'CONNECTION_INITIATED', {'endpointId': id});
          await Nearby().acceptConnection(
            id,
            onPayLoadRecieved: (String endpointId, Payload payload) async {
              if (payload.type == PayloadType.BYTES && payload.bytes != null) {
                try {
                  final verifiedData = P2PPayloadIntegrity.parseAndVerifyBytes(payload.bytes!);
                  if (verifiedData != null) {
                    final emId = verifiedData['emergencyId'] ?? emergencyId;
                    P2PDiagnostics.log(emId, 'INTEGRITY_CHECK', {'result': 'PASSED'});
                    P2PDiagnostics.log(emId, 'PAYLOAD_RECEIVED', {
                      'bytes': payload.bytes!.length,
                      'eventType': verifiedData['eventType'],
                    });
                    await handleIncomingPayload(verifiedData);
                    _sosDiscoveredController.add(verifiedData);
                    if (onSOSReceivedCallback != null) {
                      onSOSReceivedCallback!(verifiedData);
                    }
                  } else {
                    P2PDiagnostics.log(emergencyId, 'INTEGRITY_CHECK', {'result': 'FAILED'});
                  }
                } catch (e) {
                  P2PDiagnostics.log(emergencyId, 'PAYLOAD_PARSE_ERROR', {'error': e.toString()});
                }
              }
            },
          );
        },
        onConnectionResult: (String id, Status status) async {
          P2PDiagnostics.log(emergencyId, 'CONNECTION_RESULT', {'endpointId': id, 'status': status.name});
          if (status == Status.CONNECTED) {
            _connectedEndpoints.add(id);
            try {
              await Nearby().sendBytesPayload(
                id,
                Uint8List.fromList(utf8.encode(payloadJson)),
              );
              P2PDiagnostics.log(emergencyId, 'PAYLOAD_SENT', {'bytes': payloadJson.length, 'endpointId': id});
            } catch (e) {
              P2PDiagnostics.log(emergencyId, 'PAYLOAD_SEND_ERROR', {'endpointId': id, 'error': e.toString()});
            }
          } else {
            _connectedEndpoints.remove(id);
          }
        },
        onDisconnected: (String id) {
          P2PDiagnostics.log(emergencyId, 'ENDPOINT_DISCONNECTED', {'endpointId': id});
          _connectedPeers.remove(id);
          _connectedEndpoints.remove(id);
        },
      );
      _isAdvertising = true;
      P2PDiagnostics.log(emergencyId, 'ADVERTISING_STARTED', {'status': 'SUCCESS'});
    } catch (e) {
      _isAdvertising = false;
      P2PDiagnostics.log(emergencyId, 'ADVERTISING_FAILED', {'error': e.toString()});
    }
  }

  /// Start P2P discovery (Nearby users discovering broadcasting victims)
  Future<void> startSOSDiscovery({
    required String currentUserId,
    required Function(Map<String, dynamic>) onSOSDiscovered,
  }) async {
    _discoverySubscribers++;
    onSOSReceivedCallback = onSOSDiscovered;

    P2PDiagnostics.log('NONE', 'DISCOVERY_REQUESTED', {
      'role': 'RESPONDER',
      'subscribers': _discoverySubscribers,
      'isDiscovering': _isDiscovering,
    });

    if (_isDiscovering) {
      return;
    }

    final permOk = await checkOfflinePermissions();
    if (!permOk) {
      P2PDiagnostics.log('NONE', 'DISCOVERY_WARNING', {'reason': 'PERMISSIONS_OR_GPS_MISSING'});
    }

    try {
      await Nearby().startDiscovery(
        "JanSarthi_Helper_$currentUserId",
        strategy,
        onEndpointFound: (String id, String userName, String serviceId) async {
          P2PDiagnostics.log('NONE', 'ENDPOINT_FOUND', {'endpointId': id, 'serviceId': serviceId});
          await Nearby().requestConnection(
            "JanSarthi_Helper_$currentUserId",
            id,
            onConnectionInitiated: (String endpointId, ConnectionInfo info) async {
              _connectedEndpoints.add(endpointId);
              P2PDiagnostics.log('NONE', 'CONNECTION_INITIATED', {'endpointId': endpointId});
              await Nearby().acceptConnection(
                endpointId,
                onPayLoadRecieved: (String epId, Payload payload) async {
                  if (payload.type == PayloadType.BYTES && payload.bytes != null) {
                    try {
                      final verifiedData = P2PPayloadIntegrity.parseAndVerifyBytes(payload.bytes!);
                      if (verifiedData != null) {
                        final emId = verifiedData['emergencyId'] ?? 'NONE';
                        P2PDiagnostics.log(emId, 'INTEGRITY_CHECK', {'result': 'PASSED'});
                        P2PDiagnostics.log(emId, 'PAYLOAD_RECEIVED', {
                          'bytes': payload.bytes!.length,
                          'eventType': verifiedData['eventType'],
                        });
                        await handleIncomingPayload(verifiedData);
                        _sosDiscoveredController.add(verifiedData);
                        if (verifiedData['eventType'] != 'CLAIM_REQUEST' &&
                            verifiedData['eventType'] != 'CLAIM_ACK' &&
                            verifiedData['eventType'] != 'RESPONDER_ACCEPTANCE' &&
                            verifiedData['eventType'] != 'STATUS_UPDATE') {
                          onSOSDiscovered(verifiedData);
                          if (onSOSReceivedCallback != null && onSOSReceivedCallback != onSOSDiscovered) {
                            onSOSReceivedCallback!(verifiedData);
                          }
                        }
                      } else {
                        P2PDiagnostics.log('NONE', 'INTEGRITY_CHECK', {'result': 'FAILED'});
                      }
                    } catch (e) {
                      P2PDiagnostics.log('NONE', 'PAYLOAD_PARSE_ERROR', {'error': e.toString()});
                    }
                  }
                },
              );
            },
            onConnectionResult: (String endpointId, Status status) {
              P2PDiagnostics.log('NONE', 'CONNECTION_RESULT', {'endpointId': endpointId, 'status': status.name});
              if (status == Status.CONNECTED) {
                _connectedEndpoints.add(endpointId);
              } else {
                _connectedEndpoints.remove(endpointId);
              }
            },
            onDisconnected: (String endpointId) {
              P2PDiagnostics.log('NONE', 'ENDPOINT_DISCONNECTED', {'endpointId': endpointId});
              _connectedEndpoints.remove(endpointId);
            },
          );
        },
        onEndpointLost: (String? id) {
          P2PDiagnostics.log('NONE', 'ENDPOINT_LOST', {'endpointId': id ?? 'null'});
          if (id != null) _connectedEndpoints.remove(id);
        },
      );
      _isDiscovering = true;
      P2PDiagnostics.log('NONE', 'DISCOVERY_STARTED', {'status': 'SUCCESS'});
    } catch (e) {
      if (e.toString().contains('8002') || e.toString().contains('STATUS_ALREADY_DISCOVERING')) {
        _isDiscovering = true;
        P2PDiagnostics.log('NONE', 'DISCOVERY_ALREADY_ACTIVE', {'status': 'ACTIVE'});
      } else {
        _isDiscovering = false;
        P2PDiagnostics.log('NONE', 'DISCOVERY_FAILED', {'error': e.toString()});
      }
    }
  }

  /// Decrement discovery subscriber count and stop discovery only if no subscribers remain
  Future<void> stopSOSDiscovery() async {
    if (_discoverySubscribers > 0) {
      _discoverySubscribers--;
    }
    P2PDiagnostics.log('NONE', 'DISCOVERY_RELEASED', {
      'remainingSubscribers': _discoverySubscribers,
      'isDiscovering': _isDiscovering,
    });

    if (_discoverySubscribers == 0 && _isDiscovering) {
      try {
        await Nearby().stopDiscovery();
      } catch (_) {}
      _isDiscovering = false;
      P2PDiagnostics.log('NONE', 'DISCOVERY_STOPPED', {'status': 'STOPPED'});
    }
  }

  Future<bool> _broadcastJson(Map<String, dynamic> map) async {
    Map<String, dynamic> signedMap = map.containsKey(P2PPayloadIntegrity.integrityField)
        ? map
        : P2PPayloadIntegrity.signPayload(map);
    String jsonStr = jsonEncode(signedMap);
    Uint8List bytes = Uint8List.fromList(utf8.encode(jsonStr));
    bool sentAny = false;
    for (String endpointId in _connectedEndpoints) {
      try {
        await Nearby().sendBytesPayload(endpointId, bytes);
        sentAny = true;
      } catch (_) {}
    }
    return sentAny;
  }

  /// Direct access to payload integrity verification
  static Map<String, dynamic> signPayload(Map<String, dynamic> payload) =>
      P2PPayloadIntegrity.signPayload(payload);

  static bool verifyPayloadIntegrity(dynamic payload) =>
      P2PPayloadIntegrity.verifyPayload(payload);

  static Map<String, dynamic>? parseAndVerifyRawBytes(Uint8List? bytes) =>
      P2PPayloadIntegrity.parseAndVerifyBytes(bytes);

  static Map<String, dynamic>? parseAndVerifyJsonString(String rawJson) =>
      P2PPayloadIntegrity.parseAndVerifyString(rawJson);

  /// Handle any incoming P2P payload, routing CLAIM_REQUEST, CLAIM_ACK,
  /// RESPONDER_ACCEPTANCE, and STATUS_UPDATE deterministically.
  /// If [requireIntegrity] is true, payloads without valid signatures fail safely.
  Future<bool> handleIncomingPayload(Map<String, dynamic> data, {bool requireIntegrity = false}) async {
    if (requireIntegrity && !P2PPayloadIntegrity.verifyPayload(data)) {
      return false;
    }
    String? eventType = data['eventType'];
    if (eventType == 'CLAIM_REQUEST') {
      ClaimProcessResult result = await processClaimRequest(data, LocalDatabaseService());
      await sendClaimAck(result.ackPayload);
    } else if (eventType == 'CLAIM_ACK') {
      _claimAckController.add(data);
    } else if (eventType == 'RESPONDER_ACCEPTANCE' || data.containsKey('responderId')) {
      await processAcceptancePayload(data, LocalDatabaseService());
    } else if (eventType == 'STATUS_UPDATE') {
      await processStatusUpdatePayload(data, LocalDatabaseService());
    }
    return true;
  }

  /// Transmit a CLAIM_REQUEST payload over P2P Nearby Connections
  Future<bool> sendClaimRequest({
    required String requestId,
    required String emergencyId,
    required String responderId,
    required String responderName,
    String? originDeviceId,
    String? phoneNumber,
    String? bloodGroup,
    String? userRole,
    String? vehicleNumber,
    required double latitude,
    required double longitude,
  }) async {
    originDeviceId ??= await LocalDatabaseService.getOrCreateLocalDeviceId();
    Map<String, dynamic> payloadMap = {
      'eventType': 'CLAIM_REQUEST',
      'requestId': requestId,
      'emergencyId': emergencyId,
      'responderId': responderId,
      'responderName': responderName,
      'originDeviceId': originDeviceId,
      'phoneNumber': phoneNumber,
      'bloodGroup': bloodGroup,
      'userRole': userRole,
      'vehicleNumber': vehicleNumber,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    P2PDiagnostics.log(emergencyId, 'CLAIM_REQUEST_SENT', {
      'requestId': requestId,
      'responderId': responderId,
      'originDeviceId': originDeviceId,
    });

    return _broadcastJson(payloadMap);
  }

  /// Transmit a CLAIM_ACK payload over P2P Nearby Connections back to the requester
  Future<bool> sendClaimAck(Map<String, dynamic> ackPayload) async {
    final emId = ackPayload['emergencyId'] ?? 'NONE';
    P2PDiagnostics.log(emId, 'CLAIM_ACK_SENT', {
      'accepted': ackPayload['accepted'],
      'role': ackPayload['role'],
      'reason': ackPayload['reason'],
    });
    return _broadcastJson(ackPayload);
  }

  /// Transmit an acceptance payload from Helper to Victim over Nearby Connections
  Future<bool> sendAcceptancePayload({
    required String emergencyId,
    required String responderId,
    required String responderName,
    String? phoneNumber,
    String? bloodGroup,
    required double latitude,
    required double longitude,
    required ResponderRole role,
  }) async {
    Map<String, dynamic> payloadMap = {
      'eventType': 'RESPONDER_ACCEPTANCE',
      'emergencyId': emergencyId,
      'responderId': responderId,
      'responderName': responderName,
      'phoneNumber': phoneNumber,
      'bloodGroup': bloodGroup,
      'role': role.name,
      'status': (role == ResponderRole.PRIMARY ? ResponderStatus.RESPONDING : ResponderStatus.STANDBY).name,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    return _broadcastJson(payloadMap);
  }

  /// Transmit status updates (ARRIVED, COMPLETED, CANCELLED, LOCATION_UPDATE) over P2P
  Future<bool> sendStatusUpdatePayload({
    required String emergencyId,
    required String status,
    String? responderId,
    double? latitude,
    double? longitude,
  }) async {
    Map<String, dynamic> payloadMap = {
      'eventType': 'STATUS_UPDATE',
      'emergencyId': emergencyId,
      'status': status,
      'responderId': responderId,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    return _broadcastJson(payloadMap);
  }

  /// Process an incoming CLAIM_REQUEST payload deterministically on the victim's device
  /// Performs authoritative checks: victim != responder, active status, duplicate prevention,
  /// assigning PRIMARY or STANDBY, and updating victim's LocalDatabaseService.
  static Future<ClaimProcessResult> processClaimRequest(
    Map<String, dynamic> data,
    LocalDatabaseService localDb,
  ) async {
    String? emergencyId = data['emergencyId'];
    String? responderId = data['responderId'];
    String requestId = data['requestId'] ?? DateTime.now().millisecondsSinceEpoch.toString();

    if (emergencyId == null || emergencyId.isEmpty || responderId == null || responderId.isEmpty) {
      Map<String, dynamic> failAck = {
        'eventType': 'CLAIM_ACK',
        'requestId': requestId,
        'emergencyId': emergencyId ?? '',
        'responderId': responderId ?? '',
        'accepted': false,
        'reason': 'INVALID_REQUEST',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      return ClaimProcessResult(accepted: false, reason: 'INVALID_REQUEST', ackPayload: failAck);
    }

    EmergencyModel? existingEmergency = await localDb.getEmergencyById(emergencyId);
    if (existingEmergency == null) {
      Map<String, dynamic> failAck = {
        'eventType': 'CLAIM_ACK',
        'requestId': requestId,
        'emergencyId': emergencyId,
        'responderId': responderId,
        'accepted': false,
        'reason': 'EMERGENCY_NOT_FOUND',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      return ClaimProcessResult(accepted: false, reason: 'EMERGENCY_NOT_FOUND', ackPayload: failAck);
    }

    // Authoritative check: Victim cannot volunteer for their own emergency
    final isSameOrigin = existingEmergency.originDeviceId != null &&
        data['originDeviceId'] != null &&
        existingEmergency.originDeviceId == data['originDeviceId'];
    final isSameAuthVictim = responderId != 'offline_user' &&
        existingEmergency.victimId.isNotEmpty &&
        existingEmergency.victimId != 'offline_user' &&
        existingEmergency.victimId == responderId;

    if (isSameOrigin || isSameAuthVictim) {
      Map<String, dynamic> failAck = {
        'eventType': 'CLAIM_ACK',
        'requestId': requestId,
        'emergencyId': emergencyId,
        'responderId': responderId,
        'accepted': false,
        'reason': 'VICTIM_CANNOT_RESPOND',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      P2PDiagnostics.log(emergencyId, 'CLAIM_ACK_REJECTED', {
        'reason': 'VICTIM_CANNOT_RESPOND',
        'isSameOrigin': isSameOrigin,
      });
      return ClaimProcessResult(accepted: false, reason: 'VICTIM_CANNOT_RESPOND', ackPayload: failAck);
    }

    // Authoritative check: Inactive or closed emergency cannot be claimed
    if (existingEmergency.isClosed || !existingEmergency.isActive) {
      Map<String, dynamic> failAck = {
        'eventType': 'CLAIM_ACK',
        'requestId': requestId,
        'emergencyId': emergencyId,
        'responderId': responderId,
        'accepted': false,
        'reason': 'EMERGENCY_INACTIVE',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      return ClaimProcessResult(accepted: false, reason: 'EMERGENCY_INACTIVE', ackPayload: failAck);
    }

    // Duplicate claim check: If already registered, return existing role
    if (existingEmergency.responders.containsKey(responderId)) {
      ResponderRole existingRole = existingEmergency.responders[responderId]!.role;
      Map<String, dynamic> dupAck = {
        'eventType': 'CLAIM_ACK',
        'requestId': requestId,
        'emergencyId': emergencyId,
        'responderId': responderId,
        'accepted': true,
        'role': existingRole.name,
        'status': existingEmergency.responders[responderId]!.status.name,
        'isDuplicate': true,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      return ClaimProcessResult(
        accepted: true,
        role: existingRole,
        reason: 'ALREADY_CLAIMED',
        updatedEmergency: existingEmergency,
        ackPayload: dupAck,
      );
    }

    // Determine role: Primary if no active primary exists, else Standby
    bool hasPrimary = existingEmergency.helperId != null &&
        existingEmergency.helperId!.isNotEmpty &&
        existingEmergency.responders.values.any((r) => r.role == ResponderRole.PRIMARY);

    ResponderRole assignedRole = hasPrimary ? ResponderRole.STANDBY : ResponderRole.PRIMARY;
    ResponderStatus assignedStatus = hasPrimary ? ResponderStatus.STANDBY : ResponderStatus.RESPONDING;

    DateTime acceptedTime = data['timestamp'] != null
        ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
        : DateTime.now();

    ResponderModel newResponder = ResponderModel(
      userId: responderId,
      userName: data['responderName'] ?? 'Offline Responder',
      phoneNumber: data['phoneNumber'],
      bloodGroup: data['bloodGroup'],
      userRole: data['userRole'] ?? 'CITIZEN',
      vehicleNumber: data['vehicleNumber'],
      role: assignedRole,
      status: assignedStatus,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      acceptedAt: acceptedTime,
      lastLocationUpdate: acceptedTime,
      assignedAt: assignedRole == ResponderRole.PRIMARY ? acceptedTime : null,
    );

    Map<String, ResponderModel> updatedResponders = Map<String, ResponderModel>.from(existingEmergency.responders);
    updatedResponders[responderId] = newResponder;

    EmergencyModel updatedEmergency = EmergencyModel(
      id: existingEmergency.id,
      victimId: existingEmergency.victimId,
      originDeviceId: existingEmergency.originDeviceId,
      type: existingEmergency.type,
      latitude: existingEmergency.latitude,
      longitude: existingEmergency.longitude,
      status: assignedRole == ResponderRole.PRIMARY ? EmergencyStatus.ASSIGNED : existingEmergency.status,
      helperId: assignedRole == ResponderRole.PRIMARY ? responderId : existingEmergency.helperId,
      currentRadiusMeters: existingEmergency.currentRadiusMeters,
      notifiedUserIds: existingEmergency.notifiedUserIds,
      responders: updatedResponders,
      createdAt: existingEmergency.createdAt,
      updatedAt: DateTime.now(),
      lastVictimLocation: existingEmergency.lastVictimLocation,
      lastHelperLocation: assignedRole == ResponderRole.PRIMARY
          ? {
              'latitude': newResponder.latitude,
              'longitude': newResponder.longitude,
              'updatedAt': DateTime.now().toIso8601String(),
            }
          : existingEmergency.lastHelperLocation,
    );

    await localDb.saveEmergencyLocally(updatedEmergency);

    Map<String, dynamic> ackPayload = {
      'eventType': 'CLAIM_ACK',
      'requestId': requestId,
      'emergencyId': emergencyId,
      'responderId': responderId,
      'accepted': true,
      'role': assignedRole.name,
      'status': assignedStatus.name,
      'victimLatitude': existingEmergency.latitude,
      'victimLongitude': existingEmergency.longitude,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    return ClaimProcessResult(
      accepted: true,
      role: assignedRole,
      updatedEmergency: updatedEmergency,
      ackPayload: ackPayload,
    );
  }

  /// Process an incoming acceptance payload deterministically and persist to LocalDatabaseService
  static Future<EmergencyModel?> processAcceptancePayload(
    Map<String, dynamic> data,
    LocalDatabaseService localDb,
  ) async {
    if (data['eventType'] != 'RESPONDER_ACCEPTANCE' && !data.containsKey('responderId')) {
      return null;
    }
    String? emergencyId = data['emergencyId'];
    String? responderId = data['responderId'];
    if (emergencyId == null || emergencyId.isEmpty || responderId == null || responderId.isEmpty) {
      return null;
    }

    EmergencyModel? existingEmergency = await localDb.getEmergencyById(emergencyId);
    if (existingEmergency == null) {
      return null;
    }

    if (existingEmergency.responders.containsKey(responderId)) {
      return existingEmergency;
    }

    bool hasPrimary = existingEmergency.helperId != null &&
        existingEmergency.helperId!.isNotEmpty &&
        existingEmergency.responders.values.any((r) => r.role == ResponderRole.PRIMARY);

    ResponderRole assignedRole = hasPrimary ? ResponderRole.STANDBY : ResponderRole.PRIMARY;
    ResponderStatus assignedStatus = hasPrimary ? ResponderStatus.STANDBY : ResponderStatus.RESPONDING;

    DateTime acceptedTime = data['timestamp'] != null
        ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
        : DateTime.now();

    ResponderModel newResponder = ResponderModel(
      userId: responderId,
      userName: data['responderName'] ?? 'Offline Responder',
      phoneNumber: data['phoneNumber'],
      bloodGroup: data['bloodGroup'],
      role: assignedRole,
      status: assignedStatus,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      acceptedAt: acceptedTime,
      lastLocationUpdate: acceptedTime,
      assignedAt: assignedRole == ResponderRole.PRIMARY ? acceptedTime : null,
    );

    Map<String, ResponderModel> updatedResponders = Map<String, ResponderModel>.from(existingEmergency.responders);
    updatedResponders[responderId] = newResponder;

    EmergencyModel updatedEmergency = EmergencyModel(
      id: existingEmergency.id,
      victimId: existingEmergency.victimId,
      originDeviceId: existingEmergency.originDeviceId,
      type: existingEmergency.type,
      latitude: existingEmergency.latitude,
      longitude: existingEmergency.longitude,
      status: assignedRole == ResponderRole.PRIMARY ? EmergencyStatus.ASSIGNED : existingEmergency.status,
      helperId: assignedRole == ResponderRole.PRIMARY ? responderId : existingEmergency.helperId,
      currentRadiusMeters: existingEmergency.currentRadiusMeters,
      notifiedUserIds: existingEmergency.notifiedUserIds,
      responders: updatedResponders,
      createdAt: existingEmergency.createdAt,
      updatedAt: DateTime.now(),
      lastVictimLocation: existingEmergency.lastVictimLocation,
      lastHelperLocation: assignedRole == ResponderRole.PRIMARY
          ? {
              'latitude': newResponder.latitude,
              'longitude': newResponder.longitude,
              'updatedAt': DateTime.now().toIso8601String(),
            }
          : existingEmergency.lastHelperLocation,
    );

    await localDb.saveEmergencyLocally(updatedEmergency);
    return updatedEmergency;
  }

  /// Process an incoming status update payload (ARRIVED, COMPLETED, CANCELLED, LOCATION_UPDATE)
  static Future<EmergencyModel?> processStatusUpdatePayload(
    Map<String, dynamic> data,
    LocalDatabaseService localDb,
  ) async {
    String? emergencyId = data['emergencyId'];
    if (emergencyId == null || emergencyId.isEmpty) return null;

    EmergencyModel? existingEmergency = await localDb.getEmergencyById(emergencyId);
    if (existingEmergency == null) return null;

    String? newStatusStr = data['status'];
    EmergencyStatus updatedStatus = existingEmergency.status;
    if (newStatusStr != null) {
      updatedStatus = EmergencyStatus.values.firstWhere(
        (e) => e.name == newStatusStr,
        orElse: () => existingEmergency.status,
      );
    }

    double? lat = (data['latitude'] as num?)?.toDouble();
    double? lon = (data['longitude'] as num?)?.toDouble();
    String? responderId = data['responderId'];

    Map<String, ResponderModel> updatedResponders = Map<String, ResponderModel>.from(existingEmergency.responders);
    Map<String, dynamic>? updatedLastHelperLoc = existingEmergency.lastHelperLocation;
    Map<String, dynamic>? updatedLastVictimLoc = existingEmergency.lastVictimLocation;
    double updatedLat = existingEmergency.latitude;
    double updatedLon = existingEmergency.longitude;

    bool isVictimUpdate = (data['isVictim'] == true) || (responderId == null) || (responderId == existingEmergency.victimId);

    if (isVictimUpdate && lat != null && lon != null) {
      updatedLat = lat;
      updatedLon = lon;
      updatedLastVictimLoc = {
        'latitude': lat,
        'longitude': lon,
        'updatedAt': DateTime.now().toIso8601String(),
      };
    } else if (responderId != null && updatedResponders.containsKey(responderId) && lat != null && lon != null) {
      ResponderModel r = updatedResponders[responderId]!;
      updatedResponders[responderId] = ResponderModel(
        userId: r.userId,
        userName: r.userName,
        phoneNumber: r.phoneNumber,
        bloodGroup: r.bloodGroup,
        role: r.role,
        status: newStatusStr != null
            ? ResponderStatus.values.firstWhere(
                (e) => e.name == newStatusStr,
                orElse: () => r.status,
              )
            : r.status,
        latitude: lat,
        longitude: lon,
        acceptedAt: r.acceptedAt,
        lastLocationUpdate: DateTime.now(),
        assignedAt: r.assignedAt,
        distanceToVictim: r.distanceToVictim,
        etaText: r.etaText,
        etaMinutes: r.etaMinutes,
        problemReason: r.problemReason,
      );

      if (existingEmergency.helperId == responderId) {
        updatedLastHelperLoc = {
          'latitude': lat,
          'longitude': lon,
          'updatedAt': DateTime.now().toIso8601String(),
        };
      }
    }

    EmergencyModel updatedEmergency = EmergencyModel(
      id: existingEmergency.id,
      victimId: existingEmergency.victimId,
      originDeviceId: existingEmergency.originDeviceId,
      type: existingEmergency.type,
      latitude: updatedLat,
      longitude: updatedLon,
      status: updatedStatus,
      helperId: existingEmergency.helperId,
      currentRadiusMeters: existingEmergency.currentRadiusMeters,
      notifiedUserIds: existingEmergency.notifiedUserIds,
      responders: updatedResponders,
      createdAt: existingEmergency.createdAt,
      updatedAt: DateTime.now(),
      lastVictimLocation: updatedLastVictimLoc,
      lastHelperLocation: updatedLastHelperLoc,
    );

    await localDb.saveEmergencyLocally(updatedEmergency);
    return updatedEmergency;
  }

  /// Stop all offline advertising & discovery
  Future<void> stopAll() async {
    try {
      await Nearby().stopAdvertising();
    } catch (_) {}
    try {
      await Nearby().stopDiscovery();
    } catch (_) {}
    try {
      await Nearby().stopAllEndpoints();
    } catch (_) {}
    _isAdvertising = false;
    _isDiscovering = false;
    _discoverySubscribers = 0;
    _connectedPeers.clear();
    _connectedEndpoints.clear();
    P2PDiagnostics.log('NONE', 'STOP_ALL', {'status': 'CLEARED'});
  }
}
