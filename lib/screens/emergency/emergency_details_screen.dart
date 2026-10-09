import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../services/emergency_service.dart';
import '../../services/emergency_claim_service.dart';
import '../../services/local_database_service.dart';
import '../../services/notification_service.dart';
import '../../services/hospital_service.dart';
import '../../models/emergency_model.dart';
import '../../models/responder_model.dart';
import '../../models/hospital_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_status.dart';
import '../../widgets/app_state_widgets.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/common/app_status_badge.dart';
import '../../widgets/map_widget.dart';
import '../../core/navigation/app_navigator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/common/app_feedback.dart';

class EmergencyDetailsScreen extends StatefulWidget {
  final String emergencyId;
  final EmergencyModel? initialEmergency;

  const EmergencyDetailsScreen({
    super.key,
    required this.emergencyId,
    this.initialEmergency,
  });

  @override
  State<EmergencyDetailsScreen> createState() => _EmergencyDetailsScreenState();
}

class _EmergencyDetailsScreenState extends State<EmergencyDetailsScreen> {
  final EmergencyService _emergencyService = EmergencyService();
  final EmergencyClaimService _claimService = EmergencyClaimService();
  final LocalDatabaseService _localDb = LocalDatabaseService();
  IHospitalService get _hospitalService => HospitalService.instance;
  List<HospitalModel> _nearbyHospitals = [];
  String? _lastDiscoveredEmergencyId;
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    EmergencySoundService.stopSound();
  }

  void _discoverHospitalsIfNeeded(EmergencyModel emergency) {
    if (_lastDiscoveredEmergencyId == emergency.id) return;
    _lastDiscoveredEmergencyId = emergency.id;
    _hospitalService
        .discoverNearbyHospitals(
          location: LatLng(emergency.latitude, emergency.longitude),
          emergencyId: emergency.id,
        )
        .then((hospitals) {
      if (mounted) setState(() => _nearbyHospitals = hospitals);
    }).catchError((_) {});
  }

  void _checkVictimFallback(EmergencyModel emergency) async {
    String? currentUid;
    try {
      currentUid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      currentUid = null;
    }
    if (currentUid == null || !emergency.isVictim(currentUid) || emergency.isTerminal || emergency.status != EmergencyStatus.SEARCHING) {
      return;
    }
    final alreadyDispatched = await EmergencyContactsService.hasDispatchedSmsFallback(emergency.id);
    if (alreadyDispatched) return;

    final elapsed = DateTime.now().difference(emergency.createdAt).inSeconds;
    if (elapsed >= 180) {
      await EmergencyContactsService.markSmsFallbackDispatched(emergency.id);
      final contactsService = EmergencyContactsService();
      bool sent = await contactsService.sendEmergencySMS(
        latitude: emergency.latitude,
        longitude: emergency.longitude,
        type: emergency.type,
      );
      if (sent && mounted) {
        AppSnackbar.showSuccess(
          context,
          '3-minute rule: Trusted-contact SMS ready to send.',
        );
      }
    }
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
      AppSnackbar.showSuccess(
        context,
        widget.emergencyId.startsWith('JS-OFF-')
            ? 'Accepted offline emergency as ${role.name} (Direct P2P)'
            : 'Accepted emergency response as ${role.name}',
      );
      AppNavigator.replaceWithEmergencyMap(context, widget.emergencyId);
    } else {
      AppSnackbar.showWarning(
        context,
        'This emergency is no longer active.',
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
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

    if (!isCancelled && !isCompleted) {
      _discoverHospitalsIfNeeded(emergency);
      _checkVictimFallback(emergency);
    }

    return Scaffold(
      backgroundColor: AppColors.warmOffWhite,
      appBar: AppBar(
        backgroundColor: AppColors.surfacePureWhite,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.deepNavy),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isCancelled
              ? 'Cancelled Alert'
              : isCompleted
                  ? 'Resolved Alert'
                  : 'Emergency Details',
          style: AppTypography.subheading.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.deepNavy,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderSubtle, height: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SECTION: EMERGENCY
                    Text(
                      'EMERGENCY',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Status Badge & Emergency Type
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        AppStatusBadge(
                          status: isCancelled
                              ? AppStatusType.normal
                              : isCompleted
                                  ? AppStatusType.success
                                  : AppStatusType.emergency,
                          customLabel: isCancelled
                              ? 'CANCELLED ALERT'
                              : isCompleted
                                  ? 'RESOLVED ALERT'
                                  : 'LIVE ALERT',
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Text(
                            emergency.type.toUpperCase(),
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.deepNavy,
                            ),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapVerticalMd,

                    Text(
                      isCancelled
                          ? 'Cancelled Emergency'
                          : isCompleted
                              ? 'Resolved Emergency'
                              : 'Nearby Emergency Request',
                      style: AppTypography.sectionHeading.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.deepNavy,
                      ),
                    ),
                    AppSpacing.gapVerticalLg,

                    // SECTION: LOCATION
                    Text(
                      'LOCATION',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfacePureWhite,
                        borderRadius: AppShapes.card,
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.location_on_outlined, color: AppColors.brandBlue, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  radiusStageText,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.deepNavy,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Approximate victim location • broadcast stage',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.gapVerticalLg,

                    // SECTION: MAP
                    Text(
                      'MAP',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Map Preview Card
                    Container(
                      height: 190,
                      decoration: BoxDecoration(
                        borderRadius: AppShapes.card,
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: ClipRRect(
                        borderRadius: AppShapes.card,
                        child: RealMapWidget(
                          centerLatLng: LatLng(emergency.latitude, emergency.longitude),
                          initialZoom: 15.0,
                        ),
                      ),
                    ),
                    AppSpacing.gapVerticalLg,

                    // SECTION: IMPORTANT DETAILS
                    Text(
                      'IMPORTANT DETAILS',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Roles or Closed Summary Section
                    if (isCancelled || isCompleted) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfacePureWhite,
                          borderRadius: AppShapes.card,
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isCancelled
                                  ? 'This incident was cancelled. No further volunteer response is permitted.'
                                  : 'This emergency was successfully handled and closed.',
                              style: AppTypography.body.copyWith(fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Logged: ${emergency.createdAt.day}/${emergency.createdAt.month}/${emergency.createdAt.year} • ${emergency.createdAt.hour.toString().padLeft(2, '0')}:${emergency.createdAt.minute.toString().padLeft(2, '0')}',
                              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfacePureWhite,
                          borderRadius: AppShapes.card,
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildRoleBadge(
                                  icon: Icons.medical_services_outlined,
                                  label: 'Primary',
                                  color: AppColors.emergencyRed,
                                ),
                                _buildRoleBadge(
                                  icon: Icons.health_and_safety_outlined,
                                  label: 'Secondary',
                                  color: AppColors.warningAmber,
                                ),
                                _buildRoleBadge(
                                  icon: Icons.hourglass_empty,
                                  label: 'Standby',
                                  color: AppColors.brandBlue,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              hasPrimary
                                  ? 'A Primary responder is currently assigned. You will join on STANDBY and step up automatically if needed.'
                                  : 'No helper assigned yet. Accept to become the PRIMARY responder.',
                              style: AppTypography.bodySecondary.copyWith(fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // SECTION: NEARBY HOSPITALS (STANDBY)
                    if (!isCancelled && !isCompleted) ...[
                      AppSpacing.gapVerticalLg,
                      Text(
                        'NEARBY HOSPITALS (STANDBY)',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfacePureWhite,
                          borderRadius: AppShapes.card,
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.local_hospital_outlined, size: 18, color: AppColors.brandBlue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Medical centers prepared for transport',
                                    style: AppTypography.bodyMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: AppColors.deepNavy,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Prepared in background for post-arrival victim transfer. Primary objective is reaching the victim.',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                            if (_nearbyHospitals.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ..._nearbyHospitals.take(2).map((h) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            h.name,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.deepNavy,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          h.formattedDistance,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.brandBlue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // SECTION: RESPONDER ACTION (Fixed Bottom Bar Container)
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              decoration: const BoxDecoration(
                color: AppColors.surfacePureWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, -3)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCancelled || isCompleted) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          minimumSize: const Size(0, 48),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('BACK TO HISTORY', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ] else if (_emergencyService.isEmergencyDeclined(widget.emergencyId)) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              side: const BorderSide(color: AppColors.borderSubtle),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('BACK'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandBlue,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 48),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.directions_run, size: 20),
                            label: const Text('CHANGE MIND & HELP', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              _emergencyService.unmarkEmergencyDeclined(widget.emergencyId);
                              _showConfirmationDialog();
                            },
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    _isClaiming
                        ? const AppLoadingWidget(message: 'Joining rescue...')
                        : Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textSecondary,
                                    side: const BorderSide(color: AppColors.borderSubtle),
                                    minimumSize: const Size(0, 48),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
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
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.emergencyRed,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 48),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.volunteer_activism, size: 20),
                                  label: const Text('I CAN HELP', style: TextStyle(fontWeight: FontWeight.bold)),
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
        initialData: widget.initialEmergency,
        stream: _localDb.streamEmergency(widget.emergencyId),
        builder: (context, snapshot) {
          final emergency = snapshot.data ?? widget.initialEmergency;
          if (snapshot.connectionState == ConnectionState.waiting && emergency == null) {
            return const Scaffold(body: AppLoadingWidget());
          }
          if (emergency == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Offline Emergency')),
              body: AppErrorWidget(
                title: 'Emergency Not Found',
                message: 'This emergency is no longer available offline.',
                icon: Icons.error_outline,
                iconColor: Colors.orange,
                onRetry: () => Navigator.of(context).pop(),
              ),
            );
          }
          return _buildDetailsContent(emergency);
        },
      );
    }

    Stream<EmergencyModel> emergencyStream;
    try {
      emergencyStream = _emergencyService.streamEmergency(widget.emergencyId);
    } catch (e) {
      emergencyStream = Stream.error(e);
    }

    return StreamBuilder<EmergencyModel>(
      initialData: widget.initialEmergency,
      stream: emergencyStream,
      builder: (context, snapshot) {
        final emergency = snapshot.data ?? widget.initialEmergency;
        if (snapshot.connectionState == ConnectionState.waiting && emergency == null) {
          return const Scaffold(body: AppLoadingWidget());
        }
        if (emergency == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Emergency Details')),
            body: AppErrorWidget(
              title: 'Emergency Unavailable',
              message: 'This emergency could not be loaded. It may have concluded or network signal was lost.',
              onRetry: () => Navigator.of(context).pop(),
            ),
          );
        }
        return _buildDetailsContent(emergency);
      },
    );
  }
}
