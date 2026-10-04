import 'package:flutter/material.dart';
import '../models/impact_model.dart';
import '../core/theme/app_theme.dart';

/// Modal dialog displaying official Vita ResQ Community Responder Certificate
class CommunityCertificateDialog extends StatelessWidget {
  final String userName;
  final UserImpactProfile impactProfile;

  const CommunityCertificateDialog({
    super.key,
    required this.userName,
    required this.impactProfile,
  });

  static void show(BuildContext context, {required String userName, required UserImpactProfile impactProfile}) {
    showDialog(
      context: context,
      builder: (ctx) => CommunityCertificateDialog(
        userName: userName,
        impactProfile: impactProfile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final level = impactProfile.currentLevel;
    final now = DateTime.now();
    final certId = 'JS-CERT-${impactProfile.impactPoints.toString().padLeft(4, '0')}-${now.year}';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Certificate Container
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFDFBF7), // Parchment / Warm White
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFD4AF37), width: 3), // Gold border
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top National & Brand Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryRed.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shield_rounded, color: AppTheme.primaryRed, size: 28),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'VITA RESQ NETWORK',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            'COMMUNITY EMERGENCY RESPONSE NETWORK',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Decorative Divider
                  Container(
                    height: 2,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF9933), Color(0xFFFFFFFF), Color(0xFF138808)], // Tiranga colors
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'COMMUNITY RESPONDER CERTIFICATE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: Color(0xFFB45309), // Amber Gold
                    ),
                  ),
                  const SizedBox(height: 8),

                  const Text(
                    'This certificate proudly recognizes and honors',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Candidate Name
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      userName.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'for active civic emergency participation and completing verified community life-saving responses with ${impactProfile.reliabilityScore.toStringAsFixed(0)}% reliability.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Metrics Badges
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetricTile(
                          icon: Icons.star_rounded,
                          color: const Color(0xFFF59E0B),
                          label: 'IMPACT SCORE',
                          value: '${impactProfile.impactPoints}',
                        ),
                        Container(width: 1, height: 32, color: const Color(0xFFCBD5E1)),
                        _buildMetricTile(
                          icon: Icons.volunteer_activism_rounded,
                          color: const Color(0xFF10B981),
                          label: 'VERIFIED ASSISTS',
                          value: '${impactProfile.verifiedAssists}',
                        ),
                        Container(width: 1, height: 32, color: const Color(0xFFCBD5E1)),
                        _buildMetricTile(
                          icon: Icons.workspace_premium_rounded,
                          color: level.color,
                          label: 'RANK TIER',
                          value: level.badgeName,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Certificate ID & Date Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CERTIFICATE ID', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                          Text(certId, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('DATE OF ISSUE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                          Text('${now.day}/${now.month}/${now.year}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('CLOSE'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37), // Gold
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('SHARE CERTIFICATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Color(0xFF10B981),
                          content: Text('Certificate copied & ready to share!'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}
