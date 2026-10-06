import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/theme/app_theme.dart';
import '../core/navigation/app_navigator.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'app_dialogs.dart';
import 'common/common.dart';

/// Vita ResQ Navigation Drawer — Phase 3 Final Clean Directory.
///
/// Follows the core product rule:
/// - The drawer is a DIRECTORY of secondary features ("Where can I go?"), not a dashboard.
/// - Primary navigation is strictly handled by the bottom navigation bar (Home, History, Profile).
/// - Contains strictly secondary features:
///   * EMERGENCY: Emergency Contacts
///   * SAFETY: Crash Detection
///   * IMPACT: Impact & Rewards, Certificates
///   * BOTTOM: Sign Out (Destructive semantic styling)
class AppDrawer extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int>? onIndexChanged;
  final UserModel? userProfile;

  const AppDrawer({
    super.key,
    this.currentIndex = 0,
    this.onIndexChanged,
    this.userProfile,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final AuthService _authService = AuthService();

  UserModel? _profile;

  FirebaseAuth? _authInstance;
  FirebaseAuth? get _auth {
    try {
      return _authInstance ??= FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _profile = widget.userProfile;
    _loadData();
  }

  Future<void> _loadData() async {
    final user = _auth?.currentUser;
    if (_profile == null && user != null) {
      final p = await _authService.getUserProfile(user.uid);
      if (mounted) setState(() => _profile = p);
    }
  }

  void _handleContacts(BuildContext context) {
    Navigator.pop(context);
    AppNavigator.navigateToEmergencyContacts(context);
  }

  void _handleCrashDetection(BuildContext context) {
    Navigator.pop(context);
    AppNavigator.navigateToCrashDetection(context);
  }

  void _handleImpact(BuildContext context) {
    Navigator.pop(context);
    AppNavigator.navigateToImpactRewards(context);
  }

  void _handleCertificates(BuildContext context) {
    Navigator.pop(context);
    AppNavigator.navigateToCertificates(context);
  }

  void _handleAccidentDemo(BuildContext context) {
    Navigator.pop(context);
    AppNavigator.navigateToAccidentDetectionDemo(context);
  }

  void _handleSignOut(BuildContext context) async {
    final confirm = await AppDialogs.showDestructiveConfirmDialog(
      context: context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out of Vita ResQ?',
      cancelLabel: 'Cancel',
      confirmLabel: 'Sign Out',
      isDangerous: true,
    );

    if (confirm == true && context.mounted) {
      Navigator.pop(context);
      try {
        await _auth?.signOut();
      } catch (_) {}
      if (context.mounted) {
        AppNavigator.navigateToLogin(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth?.currentUser;
    final displayName = _profile?.name ?? user?.displayName ?? 'Aayon';
    final role = _profile?.userRole ?? 'CITIZEN';

    String roleDisplay = role == 'AMBULANCE_DRIVER'
        ? 'Ambulance Responder'
        : role == 'POLICE_PCR'
            ? 'Police PCR Officer'
            : 'Citizen Volunteer';

    String initials = displayName.trim().isNotEmpty
        ? displayName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'VR';
    if (initials.isEmpty) initials = 'VR';

    return Drawer(
      backgroundColor: AppColors.surfacePureWhite,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      child: SafeArea(
        child: Column(
          children: [
            // 1. TOP IDENTITY HEADER ONLY
            _buildIdentityHeader(displayName, roleDisplay, initials),

            // 2. SCROLLABLE SECONDARY MENU GROUPS
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                children: [
                  // GROUP: EMERGENCY
                  _buildSectionHeader('EMERGENCY'),
                  _DrawerRow(
                    icon: Icons.contacts_outlined,
                    label: 'Emergency Contacts',
                    onTap: () => _handleContacts(context),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: AppDivider(),
                  ),

                  // GROUP: SAFETY
                  _buildSectionHeader('SAFETY'),
                  _DrawerRow(
                    icon: Icons.car_crash_outlined,
                    label: 'Crash Detection',
                    onTap: () => _handleCrashDetection(context),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: AppDivider(),
                  ),

                  // GROUP: IMPACT
                  _buildSectionHeader('IMPACT'),
                  _DrawerRow(
                    icon: Icons.military_tech_outlined,
                    label: 'Impact & Rewards',
                    onTap: () => _handleImpact(context),
                  ),
                  _DrawerRow(
                    icon: Icons.verified_outlined,
                    label: 'Certificates',
                    onTap: () => _handleCertificates(context),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: AppDivider(),
                  ),

                  // GROUP: DEMO / JUDGE
                  _buildSectionHeader('DEMO / JUDGE'),
                  _DrawerRow(
                    icon: Icons.science_outlined,
                    label: 'Accident Detection Demo',
                    onTap: () => _handleAccidentDemo(context),
                  ),
                ],
              ),
            ),

            // 3. BOTTOM PINNED SIGN OUT
            _buildBottomSignOut(context),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityHeader(String displayName, String roleDisplay, String initials) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.warmOffWhite,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.deepNavy,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepNavy,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  roleDisplay,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textMuted,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildBottomSignOut(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSectionHeader('ACCOUNT'),
          InkWell(
            onTap: () => _handleSignOut(context),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.emergencyLightRed.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.emergencyContainer, width: 1),
              ),
              child: const Row(
                children: [
                  Icon(Icons.logout_rounded, color: AppColors.emergencyRed, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sign Out',
                      style: TextStyle(
                        color: AppColors.emergencyRed,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Vita ResQ v2.0 • Community Emergency Response Layer',
            style: AppTypography.metadata,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DrawerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.borderMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
