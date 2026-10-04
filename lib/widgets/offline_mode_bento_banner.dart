import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class OfflineModeBentoBanner extends StatelessWidget {
  final bool isBluetoothActive;
  final bool isNearbyDiscoveryActive;
  final bool isLocalDataSaved;

  const OfflineModeBentoBanner({
    super.key,
    this.isBluetoothActive = true,
    this.isNearbyDiscoveryActive = true,
    this.isLocalDataSaved = true,
  });

  Widget _buildBentoItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.secondaryBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? AppTheme.emeraldGreen : const Color(0xFFCBD5E1),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppTheme.emeraldGreen.withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppTheme.amberGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.tertiaryAmber.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.wifi_tethering_error_rounded,
                  size: 26,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OFFLINE P2P COMMUNICATION',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF92400E),
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Cellular / internet unavailable. Direct nearby-device emergency communication active.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFB45309),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildBentoItem(
            icon: Icons.bluetooth_searching_rounded,
            title: 'Bluetooth Low Energy',
            subtitle: 'Scanning nearby emergency peers',
            isActive: isBluetoothActive,
          ),
          const SizedBox(height: 8),
          _buildBentoItem(
            icon: Icons.radar_rounded,
            title: 'Nearby P2P Discovery',
            subtitle: 'Nearby-device communication ready',
            isActive: isNearbyDiscoveryActive,
          ),
          const SizedBox(height: 8),
          _buildBentoItem(
            icon: Icons.offline_bolt_rounded,
            title: 'Local Emergency Cache',
            subtitle: 'Ready for instant P2P broadcast',
            isActive: isLocalDataSaved,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFB45309)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Online map tiles & road routing require internet. Emergency alert dispatch & nearby responder coordination operate offline via direct P2P.',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E),
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
