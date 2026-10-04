import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/emergency_model.dart';
import '../models/communication_mode.dart';
import '../core/theme/app_theme.dart';
import '../services/notification_service.dart';

class AppDialogs {
  /// Show 5-Second SOS Countdown Bottom Sheet with Audio Alert & Cancel Option
  static Future<bool?> showSOSConfirmationBottomSheet({
    required BuildContext context,
    required String currentAddress,
    required bool isOnline,
    required VoidCallback onConfirmSOS,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SOSCountdownSheet(
          currentAddress: currentAddress,
          isOnline: isOnline,
          onConfirmSOS: onConfirmSOS,
        );
      },
    );
  }

  /// Show Incoming Nearby Emergency Alert Modal (Matching emergency_alert HTML design)
  static void showNearbyEmergencyDialog({
    required BuildContext context,
    required EmergencyModel emergency,
    required CommunicationMode mode,
    String userRole = 'CITIZEN',
    String? vehicleNumber,
    required VoidCallback onViewEmergency,
    VoidCallback? onDecline,
  }) {
    // Play role-specific siren and alert tone immediately with deduplication
    EmergencySoundService.playEmergencyAlert(userRole: userRole, emergencyId: emergency.id);

    bool isAmbulance = userRole == 'AMBULANCE_DRIVER';
    bool isPolice = userRole == 'POLICE_PCR';

    Color headerColor = isAmbulance
        ? AppTheme.primaryRed
        : isPolice
            ? AppTheme.secondaryBlue
            : AppTheme.primaryRed;

    String titleText = isAmbulance
        ? '🚨 URGENT DISPATCH: MEDICAL SOS'
        : isPolice
            ? '🚨 URGENT DISPATCH: POLICE ALERT'
            : '🚨 NEARBY EMERGENCY';

    String subtitleText = isAmbulance
        ? 'Priority alert dispatched to Ambulance #${vehicleNumber ?? '108'}'
        : isPolice
            ? 'Priority alert dispatched to Patrol Unit #${vehicleNumber ?? 'PCR-12'}'
            : 'Someone nearby needs emergency assistance.';

    String actionLabel = isAmbulance
        ? 'ACCEPT & START SIREN ROUTING'
        : isPolice
            ? 'ACCEPT & START POLICE ROUTING'
            : 'VIEW EMERGENCY';

    IconData actionIcon = isAmbulance
        ? Icons.local_hospital
        : isPolice
            ? Icons.local_police
            : Icons.directions_run;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceLowest,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Accent Line
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: headerColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: headerColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isAmbulance
                                ? Icons.emergency
                                : isPolice
                                    ? Icons.local_police
                                    : Icons.warning_amber_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                titleText,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: headerColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitleText,
                                style: const TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Details Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.surfaceHighest),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, color: AppTheme.secondaryBlue, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Search Radius Stage: ${(emergency.currentRadiusMeters / 1000).toStringAsFixed(1)} km',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isAmbulance || isPolice ? Colors.red.shade50 : Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isAmbulance
                                      ? '🚑 AMBULANCE EMERGENCY DISPATCH'
                                      : isPolice
                                          ? '🚓 POLICE PATROL DISPATCH'
                                          : 'Searching for a helper',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isAmbulance || isPolice ? AppTheme.primaryRed : Colors.green.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Action Buttons
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: headerColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: Icon(actionIcon, size: 20),
                      label: Text(actionLabel),
                      onPressed: () {
                        EmergencySoundService.stopSound();
                        Navigator.of(context).pop();
                        onViewEmergency();
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        EmergencySoundService.stopSound();
                        Navigator.of(context).pop();
                        if (onDecline != null) onDecline();
                      },
                      child: const Text('DECLINE / DISMISS'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      EmergencySoundService.stopSound();
    });
  }

  /// Show Confirm Response Dialog
  static void showConfirmResponseDialog({
    required BuildContext context,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.volunteer_activism, color: AppTheme.primaryRed),
              SizedBox(width: 10),
              Text('Confirm Response'),
            ],
          ),
          content: const Text(
            'Are you sure you can help? Accepting will stream your live location to the victim and dispatch network.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryBlue,
                minimumSize: const Size(120, 48),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
              child: const Text('CONFIRM'),
            ),
          ],
        );
      },
    );
  }

  /// Show Report Problem Dialog
  static void showReportProblemDialog({
    required BuildContext context,
    required Function(String reason, bool isFatal) onReport,
  }) {
    String selectedReason = 'Traffic Delay';
    bool isFatal = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(
                children: [
                  Icon(Icons.report_problem, color: AppTheme.tertiaryAmber),
                  SizedBox(width: 10),
                  Text('Report a Problem'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    decoration: const InputDecoration(labelText: 'Problem Reason'),
                    items: const [
                      DropdownMenuItem(value: 'Traffic Delay', child: Text('Traffic Delay')),
                      DropdownMenuItem(value: 'Vehicle Problem', child: Text('Vehicle Breakdown')),
                      DropdownMenuItem(value: 'Medical Issue', child: Text('Personal Emergency')),
                      DropdownMenuItem(value: 'Blocked Road', child: Text('Blocked Road')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => selectedReason = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('Cannot continue (Trigger handover to Standby pool)'),
                    value: isFatal,
                    onChanged: (val) {
                      setState(() => isFatal = val ?? false);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.tertiaryAmber,
                    minimumSize: const Size(120, 48),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onReport(selectedReason, isFatal);
                  },
                  child: const Text('SUBMIT'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SOSCountdownSheet extends StatefulWidget {
  final String currentAddress;
  final bool isOnline;
  final VoidCallback onConfirmSOS;

  const _SOSCountdownSheet({
    required this.currentAddress,
    required this.isOnline,
    required this.onConfirmSOS,
  });

  @override
  State<_SOSCountdownSheet> createState() => _SOSCountdownSheetState();
}

class _SOSCountdownSheetState extends State<_SOSCountdownSheet> with SingleTickerProviderStateMixin {
  int _secondsRemaining = 5;
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    EmergencySoundService.playAccidentWarning();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 1) {
          _secondsRemaining--;
          EmergencySoundService.playCountdownBeep(isFinal: _secondsRemaining <= 2);
        } else {
          _secondsRemaining = 0;
          timer.cancel();
          _dispatchSOS();
        }
      });
    });
  }

  void _dispatchSOS() {
    _timer?.cancel();
    EmergencySoundService.stopSound();
    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop(true);
    }
    widget.onConfirmSOS();
  }

  void _cancelSOS() {
    _timer?.cancel();
    EmergencySoundService.stopSound();
    HapticFeedback.mediumImpact();
    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop(false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 26.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.surfaceHighest,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 18),

          // Pulsing Warning Icon
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.35), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryRed.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.emergency_rounded,
                size: 44,
                color: AppTheme.primaryRed,
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'DISPATCHING EMERGENCY SOS',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryRed,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),

          const Text(
            'Alerting 108 Ambulances, Police PCR & Community Volunteers in...',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant, height: 1.3),
          ),
          const SizedBox(height: 20),

          // Circular 5-Second Countdown Indicator
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: CircularProgressIndicator(
                  value: _secondsRemaining / 5.0,
                  strokeWidth: 7,
                  backgroundColor: AppTheme.surfaceHighest,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryRed),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_secondsRemaining',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryRed,
                      height: 1.0,
                    ),
                  ),
                  const Text(
                    'SEC',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurfaceVariant,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Large Cancel Button (False Alarm Guard)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.cancel_outlined, size: 24),
            label: const Text(
              'CANCEL SOS (FALSE ALARM)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            onPressed: _cancelSOS,
          ),
          const SizedBox(height: 10),

          // Instant Send Bypass Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryRed,
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: AppTheme.primaryRed, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text(
              'SEND IMMEDIATELY',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: _dispatchSOS,
          ),
        ],
      ),
    );
  }
}

