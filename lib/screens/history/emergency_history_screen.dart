import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_status.dart';
import '../../core/navigation/app_navigator.dart';
import '../../services/local_database_service.dart';
import '../../models/emergency_model.dart';
import '../../widgets/common/app_bottom_nav_bar.dart';
import '../../widgets/common/app_status_badge.dart';

class EmergencyHistoryFilter {
  static List<EmergencyModel> filterHelpAsked(List<EmergencyModel> emergencies, String currentUserId) {
    if (currentUserId.isEmpty) return [];
    final list = emergencies.where((e) => e.victimId == currentUserId).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static List<EmergencyModel> filterVictimsHelped(List<EmergencyModel> emergencies, String currentUserId) {
    if (currentUserId.isEmpty) return [];
    final list = emergencies.where((e) {
      if (e.victimId == currentUserId) return false;
      return e.helperId == currentUserId || e.responders.containsKey(currentUserId);
    }).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }
}

class EmergencyHistoryScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;
  final int initialTabIndex;
  final String? initialUserId;
  final List<EmergencyModel>? initialEmergencies;

  const EmergencyHistoryScreen({
    super.key,
    this.onBackPressed,
    this.initialTabIndex = 0,
    this.initialUserId,
    this.initialEmergencies,
  });

  @override
  State<EmergencyHistoryScreen> createState() => _EmergencyHistoryScreenState();
}

class _EmergencyHistoryScreenState extends State<EmergencyHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildStatusBadge(String status) {
    final upper = status.toUpperCase();
    AppStatusType statusType;
    if (upper == 'COMPLETED' || upper == 'RESOLVED' || upper == 'ENDED') {
      statusType = AppStatusType.completed;
    } else if (upper == 'ARRIVED') {
      statusType = AppStatusType.success;
    } else if (upper == 'SEARCHING') {
      statusType = AppStatusType.emergency;
    } else if (upper == 'ASSIGNED' || upper == 'APPROACHING') {
      statusType = AppStatusType.warning;
    } else if (upper == 'CANCELLED' || upper == 'CANCELED') {
      statusType = AppStatusType.normal;
    } else {
      statusType = AppStatusType.normal;
    }

    return AppStatusBadge(
      status: statusType,
      customLabel: upper,
      isCompact: true,
    );
  }

  Widget _buildEmergencyCard({
    required BuildContext context,
    required String id,
    required String type,
    required String status,
    required double latitude,
    required double longitude,
    required DateTime createdAt,
    required bool isHelpAsked,
    String? roleText,
  }) {
    final dateStr =
        '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year} • ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    final isOffline = id.startsWith('JS-OFF-');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfacePureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            AppNavigator.navigateToEmergencyDetails(context, id);
          },
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Date/Time + Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        dateStr,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(status),
                  ],
                ),
                const SizedBox(height: 12),

                // Main Identity Row: Icon + Type Title + Optional Role
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isHelpAsked
                            ? AppColors.emergencyLightRed
                            : AppColors.softBlueLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isHelpAsked
                            ? Icons.emergency_outlined
                            : Icons.volunteer_activism_outlined,
                        color: isHelpAsked
                            ? AppColors.emergencyRed
                            : AppColors.softBlueDark,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isHelpAsked ? '$type Emergency SOS' : 'Assisted in $type Emergency',
                            style: AppTypography.subheading.copyWith(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.deepNavy,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (roleText != null && roleText.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Role: $roleText',
                              style: AppTypography.caption.copyWith(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.softBlueDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Context Location Container
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.subtleBlueGray,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)} (GPS Coordinates)',
                          style: AppTypography.caption.copyWith(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Footer Row: Transport channel + View Details action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOffline ? Icons.wifi_off_rounded : Icons.cloud_done_outlined,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              isOffline ? 'Offline P2P' : 'Cloud Network',
                              style: AppTypography.caption.copyWith(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View Details',
                          style: AppTypography.caption.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.emergencyRed,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.emergencyRed,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.subtleBlueGray,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSubtle, width: 1.0),
              ),
              child: Icon(icon, size: 32, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTypography.subheading.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.deepNavy,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: AppTypography.bodySecondary.copyWith(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpAskedList(String uid) {
    if (widget.initialEmergencies != null) {
      final list = EmergencyHistoryFilter.filterHelpAsked(widget.initialEmergencies!, uid);
      if (list.isEmpty) {
        return _buildEmptyState(
          icon: Icons.shield_outlined,
          title: 'No SOS requests yet',
          subtitle: 'Any emergency alerts you trigger will appear in this log.',
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final emergency = list[index];
          return _buildEmergencyCard(
            context: context,
            id: emergency.id,
            type: emergency.type,
            status: emergency.status.name,
            latitude: emergency.latitude,
            longitude: emergency.longitude,
            createdAt: emergency.createdAt,
            isHelpAsked: true,
          );
        },
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('emergencies')
          .where('victimId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.brandBlue));
        }

        return FutureBuilder<List<EmergencyModel>>(
          future: LocalDatabaseService().getAllLocalEmergencies(),
          builder: (context, localSnapshot) {
            Map<String, EmergencyModel> merged = {};

            // 1. Add local records (including offline JS-OFF- alerts)
            final localList = EmergencyHistoryFilter.filterHelpAsked(
              localSnapshot.data ?? [],
              uid,
            );
            for (var em in localList) {
              merged[em.id] = em;
            }

            // 2. Merge Firestore documents
            var docs = List<QueryDocumentSnapshot>.from(snapshot.data?.docs ?? []);
            for (var doc in docs) {
              var data = doc.data() as Map<String, dynamic>;
              var cloudEm = EmergencyModel.fromMap(data, doc.id);
              if (merged.containsKey(doc.id)) {
                var localEm = merged[doc.id]!;
                // If local emergency is terminal and cloud is still SEARCHING, local terminal status is authoritative!
                if (localEm.isTerminal && !cloudEm.isTerminal) {
                  merged[doc.id] = localEm;
                } else if (cloudEm.isTerminal && !localEm.isTerminal) {
                  merged[doc.id] = cloudEm;
                } else if (cloudEm.updatedAt.isAfter(localEm.updatedAt)) {
                  merged[doc.id] = cloudEm;
                }
              } else {
                merged[doc.id] = cloudEm;
              }
            }

            var list = merged.values.toList();
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            if (list.isEmpty) {
              return _buildEmptyState(
                icon: Icons.shield_outlined,
                title: 'No SOS requests yet',
                subtitle: 'Any emergency alerts you trigger will appear in this log.',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, index) {
                var emergency = list[index];
                return _buildEmergencyCard(
                  context: context,
                  id: emergency.id,
                  type: emergency.type,
                  status: emergency.status.name,
                  latitude: emergency.latitude,
                  longitude: emergency.longitude,
                  createdAt: emergency.createdAt,
                  isHelpAsked: true,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildVictimsHelpedList(String uid) {
    if (widget.initialEmergencies != null) {
      final list = EmergencyHistoryFilter.filterVictimsHelped(widget.initialEmergencies!, uid);
      if (list.isEmpty) {
        return _buildEmptyState(
          icon: Icons.volunteer_activism_outlined,
          title: 'No rescues yet',
          subtitle: 'Emergencies where you respond and assist will appear here.',
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final emergency = list[index];
          String? roleStr;
          if (emergency.responders.containsKey(uid)) {
            roleStr = emergency.responders[uid]!.role.name;
          }
          return _buildEmergencyCard(
            context: context,
            id: emergency.id,
            type: emergency.type,
            status: emergency.status.name,
            latitude: emergency.latitude,
            longitude: emergency.longitude,
            createdAt: emergency.createdAt,
            isHelpAsked: false,
            roleText: roleStr,
          );
        },
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('emergencies')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.brandBlue));
        }

        return FutureBuilder<List<EmergencyModel>>(
          future: LocalDatabaseService().getAllLocalEmergencies(),
          builder: (context, localSnapshot) {
            Map<String, EmergencyModel> merged = {};

            // 1. Add local records (including offline JS-OFF- alerts)
            final localList = EmergencyHistoryFilter.filterVictimsHelped(
              localSnapshot.data ?? [],
              uid,
            );
            for (var em in localList) {
              merged[em.id] = em;
            }

            // 2. Merge Firestore documents
            var allDocs = snapshot.data?.docs ?? [];
            for (var doc in allDocs) {
              var data = doc.data() as Map<String, dynamic>;
              String victimId = data['victimId'] ?? '';
              if (victimId == uid) continue;

              String helperId = data['helperId'] ?? '';
              Map<String, dynamic> responders = Map<String, dynamic>.from(data['responders'] ?? {});
              if (helperId == uid || responders.containsKey(uid)) {
                var cloudEm = EmergencyModel.fromMap(data, doc.id);
                if (merged.containsKey(doc.id)) {
                  var localEm = merged[doc.id]!;
                  if (localEm.isTerminal && !cloudEm.isTerminal) {
                    merged[doc.id] = localEm;
                  } else if (cloudEm.isTerminal && !localEm.isTerminal) {
                    merged[doc.id] = cloudEm;
                  } else if (cloudEm.updatedAt.isAfter(localEm.updatedAt)) {
                    merged[doc.id] = cloudEm;
                  }
                } else {
                  merged[doc.id] = cloudEm;
                }
              }
            }

            var list = merged.values.toList();
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            if (list.isEmpty) {
              return _buildEmptyState(
                icon: Icons.volunteer_activism_outlined,
                title: 'No rescues yet',
                subtitle: 'Emergencies where you respond and assist will appear here.',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, index) {
                var emergency = list[index];
                String? roleStr;
                if (emergency.responders.containsKey(uid)) {
                  roleStr = emergency.responders[uid]!.role.name;
                }
                return _buildEmergencyCard(
                  context: context,
                  id: emergency.id,
                  type: emergency.type,
                  status: emergency.status.name,
                  latitude: emergency.latitude,
                  longitude: emergency.longitude,
                  createdAt: emergency.createdAt,
                  isHelpAsked: false,
                  roleText: roleStr,
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String uid = widget.initialUserId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

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
          'Emergency History',
          style: AppTypography.sectionHeading.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.deepNavy,
          ),
        ),
        centerTitle: false,
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            if (widget.onBackPressed != null) {
              widget.onBackPressed!();
            } else {
              AppNavigator.navigateToHome(context);
            }
          } else if (index == 2) {
            AppNavigator.navigateToProfile(context);
          }
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Segmented pill tab switcher
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.subtleBlueGray,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle, width: 1.0),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.surfacePureWhite,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A0F172A),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                labelColor: AppColors.deepNavy,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                unselectedLabelStyle: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelPadding: EdgeInsets.zero,
                splashFactory: NoSplash.splashFactory,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                tabs: const [
                  Tab(
                    height: 38,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_outlined, size: 16),
                          SizedBox(width: 5),
                          Text('Help Asked'),
                        ],
                      ),
                    ),
                  ),
                  Tab(
                    height: 38,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.volunteer_activism_outlined, size: 16),
                          SizedBox(width: 5),
                          Text('Victims Helped'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: uid.isEmpty
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _buildEmptyState(
                          icon: Icons.shield_outlined,
                          title: 'No SOS requests yet',
                          subtitle: 'Sign in to access your personal emergency dispatch records.',
                        ),
                        _buildEmptyState(
                          icon: Icons.volunteer_activism_outlined,
                          title: 'No rescues yet',
                          subtitle: 'Sign in to track emergencies where you assist as a responder.',
                        ),
                      ],
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildHelpAskedList(uid),
                        _buildVictimsHelpedList(uid),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
