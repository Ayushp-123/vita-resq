import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../models/communication_mode.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<CommunicationMode> _modeController =
      StreamController<CommunicationMode>.broadcast();

  CommunicationMode _currentMode = CommunicationMode.offline;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _pingTimer;

  int _probeSequence = 0;
  bool _isChecking = false;

  CommunicationMode get currentMode => _currentMode;
  Stream<CommunicationMode> get modeStream => _modeController.stream;

  void initialize() {
    _checkConnectivityImmediate();

    _connectivitySubscription?.cancel();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((result) {
      if (result == ConnectivityResult.none) {
        _setMode(CommunicationMode.offline);
      } else {
        _checkConnectivity();
      }
    });

    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _checkConnectivity(),
    );
  }

  Future<void> _checkConnectivityImmediate() async {
    try {
      ConnectivityResult result = await _connectivity.checkConnectivity();
      if (result == ConnectivityResult.none) {
        _setMode(CommunicationMode.offline);
      } else {
        await _checkConnectivity();
      }
    } catch (_) {
      _setMode(CommunicationMode.offline);
    }
  }

  Future<void> _checkConnectivity() async {
    if (_isChecking) return;
    _isChecking = true;

    int seq = ++_probeSequence;
    bool hasInternet = await _httpReachabilityProbe();

    _isChecking = false;

    // Reject stale async probe results
    if (seq != _probeSequence) return;

    CommunicationMode newMode =
        hasInternet ? CommunicationMode.online : CommunicationMode.offline;

    _setMode(newMode);
  }

  void _setMode(CommunicationMode mode) {
    if (_currentMode != mode) {
      _currentMode = mode;
      if (!_modeController.isClosed) {
        _modeController.add(_currentMode);
      }
    }
  }

  /// Lightweight HTTP probe checking Google captive portal endpoints with 2.5s timeout
  Future<bool> _httpReachabilityProbe() async {
    try {
      final response = await http
          .get(Uri.parse('https://clients3.google.com/generate_204'))
          .timeout(const Duration(milliseconds: 2500));
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (_) {
      try {
        final fallback = await http
            .get(Uri.parse('https://www.google.com/generate_204'))
            .timeout(const Duration(milliseconds: 2500));
        return fallback.statusCode == 204 || fallback.statusCode == 200;
      } catch (_) {
        return false;
      }
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _pingTimer?.cancel();
    _modeController.close();
  }
}
