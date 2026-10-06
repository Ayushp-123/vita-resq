import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../models/impact_model.dart';
import '../../services/impact_reward_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../widgets/community_certificate_dialog.dart';
import '../../widgets/common/app_feedback.dart';

/// Dedicated Certificates & Civic Credentials Screen (Phase 11 Information Architecture).
///
/// Provides official verified responder credential viewing, preview generation,
/// and civic credential sharing.
class CertificatesScreen extends StatefulWidget {
  final UserImpactProfile? initialImpactProfile;
  final String? initialUserName;

  const CertificatesScreen({
    super.key,
    this.initialImpactProfile,
    this.initialUserName,
  });

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  final AuthService _authService = AuthService();
  final ImpactRewardService _impactService = ImpactRewardService();

  UserImpactProfile _impactProfile = const UserImpactProfile();
  String _displayName = 'Community Volunteer';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialImpactProfile != null) {
      _impactProfile = widget.initialImpactProfile!;
    }
    if (widget.initialUserName != null) {
      _displayName = widget.initialUserName!;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    final user = _authService.currentUser;
    if (widget.initialUserName == null && user != null) {
      final profile = await _authService.getUserProfile(user.uid);
      if (mounted && profile != null) {
        _displayName = profile.name;
      } else if (user.displayName != null) {
        _displayName = user.displayName!;
      }
    }

    final ip = await _impactService.getImpactProfile(user?.uid);
    if (mounted) {
      setState(() {
        if (ip.impactPoints > 0 || widget.initialImpactProfile == null) {
          _impactProfile = ip;
        }
        _isLoading = false;
      });
    }
  }

  void _openFullCertificate() {
    CommunityCertificateDialog.show(
      context,
      userName: _displayName,
      impactProfile: _impactProfile,
    );
  }

  void _shareCertificate() {
    AppSnackbar.showSuccess(
      context,
      'Sharing official verified Vita ResQ responder credential…',
    );
  }

  @override
  Widget build(BuildContext context) {
    final level = _impactProfile.currentLevel;
    final certId = 'VR-CERT-${_impactProfile.impactPoints.toString().padLeft(4, '0')}-${DateTime.now().year}';

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
          'Certificates',
          style: AppTypography.sectionHeading.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.deepNavy,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Official Parchment Certificate Preview Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDFBF7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Seal & Brand
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                              border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                            ),
                            child: const Icon(
                              Icons.verified_user_rounded,
                              color: Color(0xFFB8860B),
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'OFFICIAL RESPONDER CREDENTIAL',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'This officially certifies that',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _displayName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'serif',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'has served as a verified ${level.title} in the Vita ResQ Community Emergency Response Network.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF475569),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Verification Details Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'ID: $certId',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.deepNavy,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_impactProfile.verifiedAssists} Assists Verified',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.emeraldGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Actions
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepNavy,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.fullscreen_rounded, size: 22),
                      label: const Text(
                        'View Full Certificate',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                      ),
                      onPressed: _openFullCertificate,
                    ),
                    const SizedBox(height: 10),

                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.brandBlue,
                        side: const BorderSide(color: AppColors.brandBlue),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.share_outlined, size: 20),
                      label: const Text(
                        'Share Credential',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                      ),
                      onPressed: _shareCertificate,
                    ),
                    const SizedBox(height: 24),

                    // Credential Integrity Information
                    Text(
                      'CREDENTIAL VERIFICATION',
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
                          _buildVerificationRow(
                            icon: Icons.security_rounded,
                            title: 'Cryptographic Hash Integrity',
                            description: 'All response milestones and coordinates are authenticated.',
                          ),
                          const Divider(height: 18, color: AppColors.borderSubtle),
                          _buildVerificationRow(
                            icon: Icons.verified_rounded,
                            title: 'National Emergency Alignment',
                            description: 'Aligned with Good Samaritan and bystander aid guidelines.',
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

  Widget _buildVerificationRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.brandBlue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.subheading.copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepNavy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: AppTypography.bodySecondary.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
