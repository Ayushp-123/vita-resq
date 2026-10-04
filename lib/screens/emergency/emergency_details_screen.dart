import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../services/emergency_service.dart';
import '../../services/emergency_claim_service.dart';
import '../../services/local_database_service.dart';
import '../../services/notification_service.dart';
import '../../models/emergency_model.dart';
import '../../models/responder_model.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_state_widgets.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/map_widget.dart';
import '../../core/navigation/app_navigator.dart';

class EmergencyDetailsScreen extends StatefulWidget {
  final String emergencyId;
  const EmergencyDetailsScreen({super.key, required this.emergencyId});

  @override
  State<EmergencyDetailsScreen> createState() => _EmergencyDetailsScreenState();
}

class _EmergencyDetailsScreenState extends State<EmergencyDetailsScreen> {
  final EmergencyService _emergencyService = EmergencyService();
  final EmergencyClaimService _claimService = EmergencyClaimService();
  final LocalDatabaseService _localDb = LocalDatabaseService();
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    EmergencySoundService.stopSound();
  }

  void _showConfirmationDialog() {
    AppDialogs.showConfirmResponseDialog(
      context: context,
      onConfirm: _handleAcceptAndRespond,
    );
  }

  void _handleAcceptAndRespond() async {
    setState(() => _isClaiming = true);
    ResponderRole? role = await _claimService.acceptAndRespond(widget.emergencyId);
    if (!mounted) return;

    if (role != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.emergencyId.startsWith('JS-OFF-')
                ? 'Accepted offline emergency as ${role.name} (Direct P2P mode)'
                : 'Accepted emergency response as ${role.name}',
          ),
          backgroundColor: Colors.green,
        ),
      );
      AppNavigator.replaceWithEmergencyMap(context, widget.emergencyId);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This emergency is no longer active.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  Widget _buildRoleBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsContent(EmergencyModel emergency) {
    ResponderModel? primary = emergency.primaryResponder;
    bool hasPrimary = primary != null;

    String radiusStageText = emergency.currentRadiusMeters >= 1000
        ? '${(emergency.currentRadiusMeters / 1000).toStringAsFixed(1)} km'
        : '${emergency.currentRadiusMeters.round()} m';

    bool isCancelled = emergency.status == EmergencyStatus.CANCELLED;
    bool isCompleted = emergency.status == EmergencyStatus.COMPLETED;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCancelled
                    ? const Color(0xFF94A3B8)
                    : isCompleted
                        ? const Color(0xFF10B981)
                        : AppTheme.primaryRed,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isCancelled
                  ? 'CANCELLED ALERT'
                  : isCompleted
                      ? 'RESOLVED ALERT'
                      : 'LIVE ALERT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: isCancelled
                    ? const Color(0xFF64748B)
                    : isCompleted
                        ? const Color(0xFF065F46)
                        : AppTheme.primaryRed,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Headline & Stage Distance
                    Text(
                      isCancelled
                          ? 'CANCELLED EMERGENCY'
                          : isCompleted
                              ? 'RESOLVED EMERGENCY'
                              : 'NEARBY EMERGENCY',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: isCancelled
                            ? const Color(0xFF64748B)
                            : isCompleted
                                ? const Color(0xFF065F46)
                                : AppTheme.primaryRed,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          radiusStageText,
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: (isCancelled || isCompleted)
                                ? const Color(0xFFE2E8F0)
                                : AppTheme.secondaryContainerBlue.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isCancelled
                                    ? Icons.cancel
                                    : isCompleted
                                        ? Icons.check_circle
                                        : Icons.radar,
                                size: 16,
                                color: isCancelled
                                    ? const Color(0xFF64748B)
                                    : isCompleted
                                        ? const Color(0xFF065F46)
                                        : AppTheme.secondaryBlue,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isCancelled
                                    ? 'Cancelled'
                                    : isCompleted
                                        ? 'Resolved'
                                        : emergency.status == EmergencyStatus.ARRIVED
                                            ? 'Arrived'
                                            : emergency.status == EmergencyStatus.APPROACHING
                                                ? 'Approaching'
                                                : emergency.status == EmergencyStatus.ASSIGNED
                                                    ? 'Assigned'
                                                    : 'Searching...',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isCancelled
                                      ? const Color(0xFF64748B)
                                      : isCompleted
                                          ? const Color(0xFF065F46)
                                          : emergency.status == EmergencyStatus.ARRIVED
                                              ? AppTheme.emeraldGreen
                                              : emergency.status == EmergencyStatus.APPROACHING || emergency.status == EmergencyStatus.ASSIGNED
                                                  ? AppTheme.brandBlue
                                                  : AppTheme.emergencyRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Map Preview Card
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.surfaceHighest),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: RealMapWidget(
                          centerLatLng: LatLng(emergency.latitude, emergency.longitude),
                          initialZoom: 15.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Role Badges or Closed Summary Section
                    if (isCancelled || isCompleted) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.surfaceHighest),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'INCIDENT LOG SUMMARY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.onSurfaceVariant,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isCancelled
                                  ? 'This incident was cancelled. No further volunteer response is permitted.'
                                  : 'This emergency was successfully handled. The victim received assistance.',
                              style: const TextStyle(fontSize: 13, color: AppTheme.onSurface),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Logged At: ${emergency.createdAt.day}/${emergency.createdAt.month}/${emergency.createdAt.year} • ${emergency.createdAt.hour.toString().padLeft(2, '0')}:${emergency.createdAt.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.surfaceHighest),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'RESPONDER ROLES AVAILABLE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.onSurfaceVariant,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildRoleBadge(
                                  icon: Icons.medical_services_outlined,
                                  label: 'Primary',
                                  color: AppTheme.primaryRed,
                                ),
                                _buildRoleBadge(
                                  icon: Icons.health_and_safety_outlined,
                                  label: 'Secondary',
                                  color: AppTheme.tertiaryAmber,
                                ),
                                _buildRoleBadge(
                                  icon: Icons.hourglass_empty,
                                  label: 'Standby',
                                  color: AppTheme.secondaryBlue,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              hasPrimary
                                  ? 'A Primary responder is currently assigned. You will join on STANDBY and step up automatically if needed.'
                                  : 'No helper assigned yet. Accept to become the PRIMARY responder.',
                              style: const TextStyle(fontSize: 13, color: AppTheme.onSurface),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Fixed Bottom Sheet Container
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceLowest,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCancelled || isCompleted) ...[
                    Row(
                      children: [
                        Icon(
                          isCancelled ? Icons.cancel_outlined : Icons.check_circle_outline,
                          color: isCancelled ? const Color(0xFF64748B) : Colors.green,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isCancelled ? 'Emergency Was Cancelled' : 'Emergency Resolved',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isCancelled
                          ? 'This alert was cancelled by the victim or false alarm guard. No response needed.'
                          : 'This emergency incident has been successfully resolved and closed.',
                      style: const TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryBlue),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('BACK TO HISTORY'),
                      ),
                    ),
                  ] else if (_emergencyService.isEmergencyDeclined(widget.emergencyId)) ...[
                    const Row(
                      children: [
                        Icon(Icons.do_not_disturb_on_outlined, color: AppTheme.tertiaryAmber),
                        SizedBox(width: 10),
                        Text(
                          'You Declined This Alert',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'You previously declined to respond to this emergency. If you can now assist, tap below.',
                      style: TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('BACK'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
                            icon: const Icon(Icons.directions_run, size: 20),
                            label: const Text('CHANGE MIND & HELP'),
                            onPressed: () {
                              _emergencyService.unmarkEmergencyDeclined(widget.emergencyId);
                              _showConfirmationDialog();
                            },
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.primaryRed),
                        SizedBox(width: 10),
                        Text(
                          'Become a Helper?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Your live location will be shared with the victim and dispatch network while active.',
                      style: TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    _isClaiming
                        ? const AppLoadingWidget(message: 'Accepting emergency...')
                        : Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    _emergencyService.markEmergencyDeclined(widget.emergencyId);
                                    if (mounted) Navigator.of(context).pop();
                                  },
                                  child: const Text('DECLINE'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
                                  icon: const Icon(Icons.directions_run, size: 20),
                                  label: const Text('I CAN HELP'),
                                  onPressed: _showConfirmationDialog,
                                ),
                              ),
                            ],
                          ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isOffline = widget.emergencyId.startsWith('JS-OFF-');

    if (isOffline) {
      return StreamBuilder<EmergencyModel?>(
        stream: _localDb.streamEmergency(widget.emergencyId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Scaffold(body: AppLoadingWidget());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('📡 OFFLINE EMERGENCY')),
              body: AppErrorWidget(
                title: 'Offline Emergency Not Found',
                message: 'Offline emergency record not found in local storage.',
                icon: Icons.error_outline,
                iconColor: Colors.orange,
                onRetry: () => Navigator.of(context).pop(),
              ),
            );
          }
          return _buildDetailsContent(snapshot.data!);
        },
      );
    }

    return StreamBuilder<EmergencyModel>(
      stream: _emergencyService.streamEmergency(widget.emergencyId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(body: AppLoadingWidget());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('🚨 EMERGENCY ALERT')),
            body: AppErrorWidget(
              title: 'Emergency Unavailable',
              message: 'Emergency details unavailable: ${snapshot.error ?? 'Not Found'}',
              onRetry: () => Navigator.of(context).pop(),
            ),
          );
        }
        return _buildDetailsContent(snapshot.data!);
      },
    );
  }
}
