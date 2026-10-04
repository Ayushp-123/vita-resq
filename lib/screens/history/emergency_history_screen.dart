import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../core/navigation/app_navigator.dart';
import '../../services/local_database_service.dart';

import '../../models/emergency_model.dart';

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
  const EmergencyHistoryScreen({super.key, this.onBackPressed});

  @override
  State<EmergencyHistoryScreen> createState() => _EmergencyHistoryScreenState();
}

class _EmergencyHistoryScreenState extends State<EmergencyHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildStatusChip(String status) {
    String upper = status.toUpperCase();
    bool isCompleted = upper == 'COMPLETED' || upper == 'RESOLVED' || upper == 'ENDED' || upper == 'ARRIVED';
    bool isCancelled = upper == 'CANCELLED';
    bool isSearching = upper == 'SEARCHING';

    Color bgColor = isCompleted
        ? const Color(0xFFD1FAE5)
        : isCancelled
            ? const Color(0xFFF1F5F9)
            : isSearching
                ? const Color(0xFFFEF2F2)
                : const Color(0xFFEFF6FF);
    Color textColor = isCompleted
        ? const Color(0xFF065F46)
        : isCancelled
            ? const Color(0xFF64748B)
            : isSearching
                ? AppTheme.emergencyRed
                : AppTheme.brandBlue;
    Color dotColor = isCompleted
        ? AppTheme.emeraldGreen
        : isCancelled
            ? const Color(0xFF94A3B8)
            : isSearching
                ? AppTheme.emergencyRed
                : AppTheme.brandBlue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            upper,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
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
    String dateStr =
        '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year} • ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            AppNavigator.navigateToEmergencyDetails(context, id);
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _buildStatusChip(status),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isHelpAsked
                            ? AppTheme.primaryRed.withValues(alpha: 0.1)
                            : AppTheme.secondaryBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isHelpAsked ? Icons.emergency_rounded : Icons.volunteer_activism_rounded,
                        color: isHelpAsked ? AppTheme.primaryRed : AppTheme.secondaryBlue,
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.onSurface,
                            ),
                          ),
                          if (roleText != null && roleText.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Role: $roleText',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.secondaryBlue,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pin_drop_rounded, size: 14, color: AppTheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)} (GPS Coordinates)',
                          style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          id.startsWith('JS-OFF-') ? Icons.wifi_off : Icons.cloud_done_outlined,
                          size: 14,
                          color: AppTheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          id.startsWith('JS-OFF-') ? 'Offline P2P' : 'Cloud Network',
                          style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const Row(
                      children: [
                        Text(
                          'View Details',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryRed,
                          ),
                        ),
                        Icon(Icons.chevron_right, size: 16, color: AppTheme.primaryRed),
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
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppTheme.surfaceLow,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppTheme.outlineColor.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant, height: 1.3),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    String uid = authUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
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
        title: const Text(
          'EMERGENCY HISTORY',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 0.8,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppTheme.brandBlue,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.brandBlue.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF94A3B8),
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Help Asked (SOS)'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.volunteer_activism_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Victims Helped'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: uid.isEmpty
            ? TabBarView(
                controller: _tabController,
                children: [
                  _buildEmptyState(
                    icon: Icons.shield_outlined,
                    title: 'No SOS Requests Made',
                    subtitle: 'Sign in to access your personal emergency dispatch records.',
                  ),
                  _buildEmptyState(
                    icon: Icons.volunteer_activism_outlined,
                    title: 'No Rescue Logs Yet',
                    subtitle: 'Sign in to track emergencies where you assist as a responder.',
                  ),
                ],
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  // TAB 1: HELP ASKED (User was Victim)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('emergencies')
                        .where('victimId', isEqualTo: uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator(color: AppTheme.brandBlue));
                      }

                      var docs = List<QueryDocumentSnapshot>.from(snapshot.data?.docs ?? []);
                      if (docs.isEmpty || snapshot.hasError) {
                        return FutureBuilder<List<EmergencyModel>>(
                          future: LocalDatabaseService().getAllLocalEmergencies(),
                          builder: (context, localSnapshot) {
                            var localList = EmergencyHistoryFilter.filterHelpAsked(
                              localSnapshot.data ?? [],
                              uid,
                            );

                            if (localList.isEmpty) {
                              return _buildEmptyState(
                                icon: Icons.shield_outlined,
                                title: 'No SOS Requests Made',
                                subtitle: 'Any emergency alerts you trigger will appear in this log.',
                              );
                            }

                            return ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: localList.length,
                              itemBuilder: (context, index) {
                                var emergency = localList[index];
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
                      }

                      // Sort online docs by createdAt descending
                      docs.sort((a, b) {
                        var aMap = a.data() as Map<String, dynamic>;
                        var bMap = b.data() as Map<String, dynamic>;
                        var aDate = EmergencyModel.parseDate(aMap['createdAt']);
                        var bDate = EmergencyModel.parseDate(bMap['createdAt']);
                        return bDate.compareTo(aDate);
                      });

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          var data = docs[index].data() as Map<String, dynamic>;
                          String docId = docs[index].id;
                          DateTime createdAt = EmergencyModel.parseDate(data['createdAt']);
                          String status = (data['status'] ?? 'COMPLETED').toString();
                          String type = (data['type'] ?? 'Medical').toString();
                          double lat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
                          double lon = (data['longitude'] as num?)?.toDouble() ?? 0.0;

                          return _buildEmergencyCard(
                            context: context,
                            id: docId,
                            type: type,
                            status: status,
                            latitude: lat,
                            longitude: lon,
                            createdAt: createdAt,
                            isHelpAsked: true,
                          );
                        },
                      );
                    },
                  ),

                  // TAB 2: VICTIMS HELPED (User was Responder)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('emergencies')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator(color: AppTheme.brandBlue));
                      }

                      var allDocs = snapshot.data?.docs ?? [];
                      var helpedDocs = allDocs.where((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        String victimId = data['victimId'] ?? '';
                        if (victimId == uid) return false; // Never show own emergency

                        String helperId = data['helperId'] ?? '';
                        Map<String, dynamic> responders = Map<String, dynamic>.from(data['responders'] ?? {});
                        return helperId == uid || responders.containsKey(uid);
                      }).toList();

                      if (helpedDocs.isEmpty) {
                        return FutureBuilder<List<EmergencyModel>>(
                          future: LocalDatabaseService().getAllLocalEmergencies(),
                          builder: (context, localSnapshot) {
                            var localList = EmergencyHistoryFilter.filterVictimsHelped(
                              localSnapshot.data ?? [],
                              uid,
                            );

                            if (localList.isEmpty) {
                              return _buildEmptyState(
                                icon: Icons.volunteer_activism_outlined,
                                title: 'No Rescue Logs Yet',
                                subtitle: 'Emergencies where you respond and assist as a volunteer will appear here.',
                              );
                            }

                            return ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: localList.length,
                              itemBuilder: (context, index) {
                                var emergency = localList[index];
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
                      }

                      // Sort helped docs by createdAt descending
                      helpedDocs.sort((a, b) {
                        var aMap = a.data() as Map<String, dynamic>;
                        var bMap = b.data() as Map<String, dynamic>;
                        var aDate = EmergencyModel.parseDate(aMap['createdAt']);
                        var bDate = EmergencyModel.parseDate(bMap['createdAt']);
                        return bDate.compareTo(aDate);
                      });

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: helpedDocs.length,
                        itemBuilder: (context, index) {
                          var data = helpedDocs[index].data() as Map<String, dynamic>;
                          String docId = helpedDocs[index].id;
                          DateTime createdAt = EmergencyModel.parseDate(data['createdAt']);
                          String status = (data['status'] ?? 'COMPLETED').toString();
                          String type = (data['type'] ?? 'Medical').toString();
                          double lat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
                          double lon = (data['longitude'] as num?)?.toDouble() ?? 0.0;

                          Map<String, dynamic> responders = Map<String, dynamic>.from(data['responders'] ?? {});
                          String? roleText;
                          if (responders.containsKey(uid)) {
                            roleText = (responders[uid] as Map<String, dynamic>)['role']?.toString();
                          }

                          return _buildEmergencyCard(
                            context: context,
                            id: docId,
                            type: type,
                            status: status,
                            latitude: lat,
                            longitude: lon,
                            createdAt: createdAt,
                            isHelpAsked: false,
                            roleText: roleText,
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }
}
