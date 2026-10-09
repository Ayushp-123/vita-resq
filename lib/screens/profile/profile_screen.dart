import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../models/impact_model.dart';
import '../../services/emergency_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/navigation/app_navigator.dart';
import '../../widgets/common/app_bottom_nav_bar.dart';
import '../../widgets/common/app_feedback.dart';
import '../../widgets/app_dialogs.dart';
import '../history/emergency_history_screen.dart';

/// Vita ResQ Profile Screen — Phase 11 Clean Information Architecture.
///
/// Follows the core principle: PROFILE = ME.
/// Contains strictly personal identity, account details, and account actions.
/// All secondary features (Contacts, Crash Detection, Impact, Certificates, Demo)
/// reside exclusively in their dedicated screens reachable from the Drawer directory.
class ProfileScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;
  final UserModel? initialUserProfile;
  final UserImpactProfile? initialImpactProfile;
  final List<EmergencyContact>? initialContacts;
  final List<ImpactBadge>? initialBadges;

  const ProfileScreen({
    super.key,
    this.onBackPressed,
    this.initialUserProfile,
    this.initialImpactProfile,
    this.initialContacts,
    this.initialBadges,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();

  UserModel? _userProfile;

  @override
  void initState() {
    super.initState();
    if (widget.initialUserProfile != null) {
      _userProfile = widget.initialUserProfile;
    }
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _authService.currentUser;
    if (user != null) {
      UserModel? profile = await _authService.getUserProfile(user.uid);
      if (mounted) {
        setState(() {
          _userProfile = profile ?? widget.initialUserProfile;
        });
      }
    } else if (widget.initialUserProfile != null && mounted) {
      setState(() {
        _userProfile = widget.initialUserProfile;
      });
    }
  }

  void _showEditProfileDialog() {
    final user = _authService.currentUser;
    final nameController = TextEditingController(text: _userProfile?.name ?? user?.displayName ?? '');
    final phoneController = TextEditingController(text: _userProfile?.phoneNumber ?? '');
    final vehicleController = TextEditingController(text: _userProfile?.vehicleNumber ?? '');
    String selectedBloodGroup = _userProfile?.bloodGroup ?? 'A+';
    String selectedRole = _userProfile?.userRole ?? 'CITIZEN';

    const bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    if (!bloodGroups.contains(selectedBloodGroup)) {
      selectedBloodGroup = 'A+';
    }

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.edit_outlined, color: AppColors.brandBlue),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Edit Profile & Role'),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Name is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        validator: (val) {
                          if (val != null && val.trim().isNotEmpty) {
                            if (!RegExp(r'^\+?[0-9]{8,15}$').hasMatch(val.trim())) {
                              return 'Enter a valid phone number';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedBloodGroup,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Blood Group',
                          prefixIcon: Icon(Icons.bloodtype_outlined),
                        ),
                        items: bloodGroups.map((bg) {
                          return DropdownMenuItem(value: bg, child: Text(bg));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedBloodGroup = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Responder Role',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'CITIZEN',
                            child: Text('👤 Citizen / Volunteer'),
                          ),
                          DropdownMenuItem(
                            value: 'AMBULANCE_DRIVER',
                            child: Text('🚑 Ambulance Driver'),
                          ),
                          DropdownMenuItem(
                            value: 'POLICE_PCR',
                            child: Text('🚓 Police Patrol / PCR Van'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedRole = val);
                        },
                      ),
                      if (selectedRole != 'CITIZEN') ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: vehicleController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: selectedRole == 'AMBULANCE_DRIVER'
                                ? 'Ambulance Vehicle Number'
                                : 'PCR Van / Patrol Unit Number',
                            prefixIcon: Icon(
                              selectedRole == 'AMBULANCE_DRIVER'
                                  ? Icons.local_hospital_outlined
                                  : Icons.local_police_outlined,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepNavy,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(110, 44),
                  ),
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      final nav = Navigator.of(dialogContext);
                      await _authService.updateUserProfile(
                        name: nameController.text.trim(),
                        phoneNumber: phoneController.text.trim(),
                        bloodGroup: selectedBloodGroup,
                        userRole: selectedRole,
                        vehicleNumber: selectedRole != 'CITIZEN' ? vehicleController.text.trim() : null,
                      );
                      if (!mounted) return;
                      nav.pop();
                      _loadProfile();
                      if (mounted) {
                        AppSnackbar.showSuccess(context, 'Profile updated.');
                      }
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleSignOut() async {
    final confirm = await AppDialogs.showDestructiveConfirmDialog(
      context: context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out of Vita ResQ?',
      cancelLabel: 'Cancel',
      confirmLabel: 'Sign Out',
      isDangerous: true,
    );

    if (confirm == true && mounted) {
      await _authService.signOut();
      if (mounted) {
        AppNavigator.navigateToLogin(context);
      }
    }
  }

  Widget _buildRoleBadge(String? role, String? vehicle) {
    IconData icon;
    String label;
    Color iconColor;

    if (role == 'AMBULANCE_DRIVER') {
      icon = Icons.local_hospital_outlined;
      label = 'Ambulance Driver${vehicle != null && vehicle.isNotEmpty ? ' ($vehicle)' : ''}';
      iconColor = AppColors.emergencyRed;
    } else if (role == 'POLICE_PCR') {
      icon = Icons.local_police_outlined;
      label = 'Police Patrol PCR${vehicle != null && vehicle.isNotEmpty ? ' ($vehicle)' : ''}';
      iconColor = AppColors.brandBlue;
    } else {
      icon = Icons.verified_user_outlined;
      label = 'Citizen Volunteer';
      iconColor = AppColors.navy700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.subtleBlueGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.deepNavy,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 20.0),
      child: Text(
        title,
        style: AppTypography.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildSettingsRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.subtleBlueGray,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
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
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.bodySecondary.copyWith(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    String name = _userProfile?.name ?? user?.displayName ?? 'Community Volunteer';
    String email = _userProfile?.email ?? user?.email ?? 'user@vita-resq.org';
    String phone = _userProfile?.phoneNumber ?? 'No phone listed';
    String blood = _userProfile?.bloodGroup ?? 'Not set';
    String role = _userProfile?.userRole ?? 'CITIZEN';
    String? vehicle = _userProfile?.vehicleNumber;

    return Scaffold(
      backgroundColor: AppColors.warmOffWhite,
      appBar: AppBar(
        backgroundColor: AppColors.warmOffWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.deepNavy),
          tooltip: 'Back',
          onPressed: () {
            if (widget.onBackPressed != null) {
              widget.onBackPressed!();
            } else if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              AppNavigator.navigateToHome(context);
            }
          },
        ),
        title: Text(
          'Profile',
          style: AppTypography.sectionHeading.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.deepNavy,
          ),
        ),
        centerTitle: false,
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) {
            if (widget.onBackPressed != null) {
              widget.onBackPressed!();
            } else {
              AppNavigator.navigateToHome(context);
            }
          } else if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EmergencyHistoryScreen()),
            );
          }
        },
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. PERSONAL PROFILE HEADER
              Center(
                child: Column(
                  children: [
                    InkWell(
                      onTap: _showEditProfileDialog,
                      borderRadius: BorderRadius.circular(40),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: AppColors.subtleBlueGray,
                            child: Icon(
                              role == 'AMBULANCE_DRIVER'
                                  ? Icons.local_hospital_rounded
                                  : role == 'POLICE_PCR'
                                      ? Icons.local_police_rounded
                                      : Icons.person_rounded,
                              size: 36,
                              color: role == 'AMBULANCE_DRIVER'
                                  ? AppColors.emergencyRed
                                  : role == 'POLICE_PCR'
                                      ? AppColors.brandBlue
                                      : AppColors.navy700,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.surfacePureWhite,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.borderSubtle, width: 1),
                            ),
                            child: const Icon(
                              Icons.edit_outlined,
                              size: 13,
                              color: AppColors.deepNavy,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      name,
                      style: AppTypography.pageHeading.copyWith(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: AppTypography.caption.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildRoleBadge(role, vehicle),
                  ],
                ),
              ),

              // 2. ACCOUNT INFORMATION SECTION
              _buildSectionHeader('ACCOUNT'),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfacePureWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle, width: 1.0),
                ),
                child: Column(
                  children: [
                    _buildSettingsRow(
                      icon: Icons.person_outline_rounded,
                      iconColor: AppColors.navy700,
                      title: 'Personal Information',
                      subtitle: '$phone • Blood: $blood',
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
                      onTap: _showEditProfileDialog,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.borderSubtle),
                    _buildSettingsRow(
                      icon: Icons.phone_outlined,
                      iconColor: AppColors.navy700,
                      title: 'Phone Number',
                      subtitle: phone,
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
                      onTap: _showEditProfileDialog,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.borderSubtle),
                    _buildSettingsRow(
                      icon: Icons.bloodtype_outlined,
                      iconColor: AppColors.emergencyRed,
                      title: 'Blood Group',
                      subtitle: blood.contains('O') ? '$blood (Universal Donor)' : '$blood (Medical ID)',
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
                      onTap: _showEditProfileDialog,
                    ),
                    if (vehicle != null && vehicle.isNotEmpty) ...[
                      const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.borderSubtle),
                      _buildSettingsRow(
                        icon: Icons.directions_car_outlined,
                        iconColor: AppColors.brandBlue,
                        title: 'Vehicle Number',
                        subtitle: vehicle,
                        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
                        onTap: _showEditProfileDialog,
                      ),
                    ],
                    const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.borderSubtle),
                    _buildSettingsRow(
                      icon: Icons.badge_outlined,
                      iconColor: AppColors.navy700,
                      title: 'Edit Profile & Role',
                      subtitle: 'Update phone number, blood group, or vehicle ID',
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
                      onTap: _showEditProfileDialog,
                    ),
                  ],
                ),
              ),

              // 3. ACCOUNT ACTIONS SECTION
              _buildSectionHeader('ACCOUNT ACTIONS'),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfacePureWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle, width: 1.0),
                ),
                child: _buildSettingsRow(
                  icon: Icons.logout_rounded,
                  iconColor: AppColors.emergencyRed,
                  title: 'Sign Out',
                  subtitle: 'Sign out of your Vita ResQ account',
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.emergencyRed, size: 20),
                  onTap: _handleSignOut,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
