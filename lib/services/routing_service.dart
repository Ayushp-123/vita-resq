import 'routing_service_interface.dart';
import 'osrm_routing_service.dart';

/// Service factory providing access to the active routing service
class RoutingService {
  static final IRoutingService instance = OSRMRoutingService();
}
