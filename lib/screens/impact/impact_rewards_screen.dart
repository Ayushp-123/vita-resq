import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../models/impact_model.dart';
import '../../services/impact_reward_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../widgets/community_certificate_dialog.dart';

/// Dedicated Civic Impact & Rewards Screen (Phase 11 Information Architecture).
///
/// Focuses purely on community service recognition:
/// - Recognition Level & Title
/// - Verified Community Assists & Reliability Score
/// - Unlocked Civic Badges
/// - Impact verification explanations
class ImpactRewardsScreen extends StatefulWidget {
  final UserImpactProfile? initialImpactProfile;
  final List<ImpactBadge>? initialBadges;

  const ImpactRewardsScreen({
    super.key,
    this.initialImpactProfile,
    this.initialBadges,
  });

  @override
  State<ImpactRewardsScreen> createState() => _ImpactRewardsScreenState();
}

class _ImpactRewardsScreenState extends State<ImpactRewardsScreen> {
  final AuthService _authService = AuthService();
  final ImpactRewardService _impactService = ImpactRewardService();

  UserImpactProfile _impactProfile = const UserImpactProfile();
  List<ImpactBadge> _badges = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialImpactProfile != null) {
      _impactProfile = widget.initialImpactProfile!;
    }
    if (widget.initialBadges != null) {
      _badges = widget.initialBadges!;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    final user = _authService.currentUser;
    final profile = await _impactService.getImpactProfile(user?.uid);
    final badges = await _impactService.getBadgesWithState(user?.uid);

    if (mounted) {
      setState(() {
        if (profile.impactPoints > 0 || widget.initialImpactProfile == null) {
          _impactProfile = profile;
        }
        if (badges.isNotEmpty) {
          _badges = badges;
        } else if (_badges.isEmpty) {
          _badges = ImpactRewardService.allBadgeDefinitions.map((def) {
            final isUnlocked = _impactProfile.unlockedBadgeIds.contains(def.id);
            return ImpactBadge(
              id: def.id,
              title: def.title,
              description: def.description,
              icon: def.icon,
              color: def.color,
              isUnlocked: isUnlocked,
            );
          }).toList();
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final displayName = user?.displayName ?? 'Community Volunteer';
    final level = _impactProfile.currentLevel;

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
          'Impact & Rewards',
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
                    // Recognition Level Hero Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.deepNavy, Color(0xFF1E293B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.deepNavy.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'LEVEL ${level.levelNumber}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  '${_impactProfile.impactPoints} Impact Pts',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFFFD700),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            level.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Recognized for exceptional civic dedication and bystander emergency assistance.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.white.withValues(alpha: 0.8),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Verified Metrics Strip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildMetricColumn(
                                    'Verified Assists',
                                    '${_impactProfile.verifiedAssists}',
                                    Icons.volunteer_activism_rounded,
                                  ),
                                ),
                                Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.15)),
                                Expanded(
                                  child: _buildMetricColumn(
                                    'Reliability',
                                    '${_impactProfile.reliabilityScore.toStringAsFixed(0)}%',
                                    Icons.verified_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Civic Badges Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'CIVIC BADGES & HONORS',
                            style: AppTypography.caption.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_impactProfile.unlockedBadgeIds.length} of ${_badges.length} Unlocked',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.deepNavy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfacePureWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.5,
                        ),
                        itemCount: _badges.length,
                        itemBuilder: (context, idx) {
                          final b = _badges[idx];
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: b.isUnlocked ? AppColors.subtleBlueGray : AppColors.warmOffWhite,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: b.isUnlocked ? AppColors.borderSubtle : AppColors.borderSubtle.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      b.icon,
                                      color: b.isUnlocked ? AppColors.deepNavy : AppColors.textMuted,
                                      size: 22,
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: b.isUnlocked
                                            ? AppColors.emeraldGreen.withValues(alpha: 0.12)
                                            : AppColors.textMuted.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        b.isUnlocked ? 'EARNED' : 'LOCKED',
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                          color: b.isUnlocked ? AppColors.emeraldGreen : AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  b.title,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: b.isUnlocked ? AppColors.deepNavy : AppColors.textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  b.description,
                                  style: AppTypography.bodySecondary.copyWith(
                                    fontSize: 10,
                                    color: b.isUnlocked ? AppColors.textSecondary : AppColors.textMuted,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Quick Certificate Callout
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
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.workspace_premium_rounded,
                              color: Color(0xFFD4AF37),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Official Responder Certificate',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.deepNavy,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Generated with verified timestamp & civic credential.',
                                  style: AppTypography.bodySecondary.copyWith(fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => CommunityCertificateDialog.show(
                              context,
                              userName: displayName,
                              impactProfile: _impactProfile,
                            ),
                            child: const Text('VIEW', style: TextStyle(fontWeight: FontWeight.w800)),
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

  Widget _buildMetricColumn(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
