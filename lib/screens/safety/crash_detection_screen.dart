import 'package:flutter/material.dart';
import '../../services/accident_detection_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../widgets/common/app_feedback.dart';

/// Dedicated Crash Detection Screen (Phase 11 Information Architecture).
///
/// Configures high-G vehicular collision impact monitoring, 15-second siren
/// warning alert, and automatic emergency SOS escalation protocol.
class CrashDetectionScreen extends StatefulWidget {
  final bool? initialEnabled;

  const CrashDetectionScreen({
    super.key,
    this.initialEnabled,
  });

  @override
  State<CrashDetectionScreen> createState() => _CrashDetectionScreenState();
}

class _CrashDetectionScreenState extends State<CrashDetectionScreen> {
  final AccidentDetectionService _accidentService = AccidentDetectionService();

  late bool _isEnabled;

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.initialEnabled ?? _accidentService.isEnabled;
    _initService();
  }

  Future<void> _initService() async {
    await _accidentService.initialize();
    if (mounted) {
      setState(() {
        _isEnabled = _accidentService.isEnabled;
      });
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    setState(() => _isEnabled = value);
    await _accidentService.setEnabled(value);
    if (mounted) {
      if (value) {
        AppSnackbar.showSuccess(context, 'Automatic Crash Detection enabled.');
      } else {
        AppSnackbar.showWarning(context, 'Automatic Crash Detection paused.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmOffWhite,
      appBar: AppBar(
        backgroundColor: AppColors.warmOffWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.deepNavy),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Crash Detection',
          style: AppTypography.sectionHeading.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.deepNavy,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Main Toggle Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfacePureWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _isEnabled
                                  ? AppColors.emergencyLightRed
                                  : AppColors.subtleBlueGray,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.car_crash_rounded,
                              color: _isEnabled
                                  ? AppColors.emergencyRed
                                  : AppColors.textMuted,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Automatic Crash Detection',
                                  style: AppTypography.subheading.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.deepNavy,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _isEnabled ? 'Active & monitoring sensors' : 'Monitoring paused',
                                  style: AppTypography.bodySecondary.copyWith(
                                    fontSize: 12,
                                    color: _isEnabled ? AppColors.emeraldGreen : AppColors.textSecondary,
                                    fontWeight: _isEnabled ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _isEnabled,
                            activeTrackColor: AppColors.emergencyRed,
                            onChanged: _toggleEnabled,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Status Indicator Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _isEnabled
                            ? AppColors.emeraldGreen.withValues(alpha: 0.08)
                            : AppColors.subtleBlueGray,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isEnabled
                              ? AppColors.emeraldGreen.withValues(alpha: 0.3)
                              : AppColors.borderSubtle,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isEnabled ? Icons.check_circle_rounded : Icons.pause_circle_outline_rounded,
                            color: _isEnabled ? AppColors.emeraldGreen : AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _isEnabled
                                  ? 'Background sensor telemetry active. High-G impact monitoring enabled.'
                                  : 'Crash detection is currently turned off. No automated SOS alerts will trigger.',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _isEnabled ? AppColors.deepNavy : AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // How It Works / Safety Protocol
                    Text(
                      '15-SECOND SAFETY PROTOCOL',
                      style: AppTypography.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfacePureWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Column(
                        children: [
                          _buildProtocolStep(
                            stepNumber: '1',
                            title: 'Collision Impact Analysis',
                            description: 'Evaluates sudden high-G deceleration (>25 m/s²), rotational gyro velocity, and vehicle speed context in real time.',
                            icon: Icons.speed_rounded,
                          ),
                          const Divider(height: 20, color: AppColors.borderSubtle),
                          _buildProtocolStep(
                            stepNumber: '2',
                            title: '15-Second Audible Warning',
                            description: 'Triggers a high-priority siren and pulsing vibrations. If uninjured, you can tap "I\'M OKAY" to cancel with zero false alarms.',
                            icon: Icons.alarm_rounded,
                          ),
                          const Divider(height: 20, color: AppColors.borderSubtle),
                          _buildProtocolStep(
                            stepNumber: '3',
                            title: 'Automatic Emergency Dispatch',
                            description: 'If you are unresponsive after 15 seconds, Vita ResQ automatically broadcasts an active SOS with coordinates to nearby responders.',
                            icon: Icons.emergency_rounded,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Sensor & Hardware Telemetry
                    Text(
                      'SENSOR HARDWARE STATUS',
                      style: AppTypography.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfacePureWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Column(
                        children: [
                          _buildSensorRow(
                            name: 'Linear Accelerometer',
                            detail: 'Impact G-Force detection',
                            isAvailable: true,
                          ),
                          const Divider(height: 16, color: AppColors.borderSubtle),
                          _buildSensorRow(
                            name: 'Gyroscope Sensor',
                            detail: 'Vehicle roll & angular rate',
                            isAvailable: true,
                          ),
                          const Divider(height: 16, color: AppColors.borderSubtle),
                          _buildSensorRow(
                            name: 'GPS Telemetry Engine',
                            detail: 'Speed deceleration context',
                            isAvailable: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Safety Note
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.subtleBlueGray,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded, color: AppColors.textSecondary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Optimized for battery efficiency. Operates in the background while commuting and will not trigger on simple phone drops or sudden walking stops.',
                              style: AppTypography.bodySecondary.copyWith(fontSize: 11.5, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildProtocolStep({
    required String stepNumber,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.deepNavy,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              stepNumber,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.subheading.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepNavy,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: AppTypography.bodySecondary.copyWith(fontSize: 12, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSensorRow({
    required String name,
    required String detail,
    required bool isAvailable,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: AppTypography.subheading.copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.deepNavy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: AppTypography.bodySecondary.copyWith(fontSize: 11.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isAvailable ? AppColors.emeraldGreen : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isAvailable ? 'Ready' : 'Unavailable',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isAvailable ? AppColors.emeraldGreen : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
