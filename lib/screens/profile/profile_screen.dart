import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../services/auth_service.dart';
import '../../services/accident_detection_service.dart';
import '../../services/emergency_service.dart';
import '../../services/location_service.dart';
import '../../models/user_model.dart';
import '../../models/impact_model.dart';
import '../../services/impact_reward_service.dart';
import '../../widgets/community_certificate_dialog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/navigation/app_navigator.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;
  const ProfileScreen({super.key, this.onBackPressed});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final AccidentDetectionService _accidentService = AccidentDetectionService();
  final EmergencyContactsService _contactsService = EmergencyContactsService();
  final LocationService _locationService = LocationService();
  final ImpactRewardService _impactService = ImpactRewardService();

  bool _locationPermissionEnabled = true;
  bool _notificationsEnabled = true;
  bool _accidentDetectionEnabled = true;
  UserModel? _userProfile;
  UserImpactProfile _impactProfile = const UserImpactProfile();
  List<ImpactBadge> _badges = [];
  List<EmergencyContact> _emergencyContacts = [];

  @override
  void initState() {
    super.initState();
    _accidentDetectionEnabled = _accidentService.isEnabled;
    _loadProfile();
    _loadContacts();
    _loadImpactData();
  }

  Future<void> _loadImpactData() async {
    final user = _authService.currentUser;
    final profile = await _impactService.getImpactProfile(user?.uid);
    final badges = await _impactService.getBadgesWithState(user?.uid);
    if (mounted) {
      setState(() {
        _impactProfile = profile;
        _badges = badges;
      });
    }
  }

  Future<void> _loadContacts() async {
    final contacts = await _contactsService.getContacts();
    if (mounted) {
      setState(() {
        _emergencyContacts = contacts;
      });
    }
  }

  Future<void> _loadProfile() async {
    final user = _authService.currentUser;
    if (user != null) {
      UserModel? profile = await _authService.getUserProfile(user.uid);
      if (mounted) {
        setState(() {
          _userProfile = profile;
          if (profile != null) {
            _impactProfile = profile.impactProfile;
          }
        });
      }
    }
    _loadImpactData();
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
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(
                children: [
                  Icon(Icons.edit, color: AppTheme.secondaryBlue),
                  SizedBox(width: 10),
                  Text('Edit Profile & Role'),
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
                          prefixIcon: Icon(Icons.person),
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
                          prefixIcon: Icon(Icons.phone),
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
                        decoration: const InputDecoration(
                          labelText: 'Blood Group',
                          prefixIcon: Icon(Icons.bloodtype),
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
                        decoration: const InputDecoration(
                          labelText: 'Responder Role',
                          prefixIcon: Icon(Icons.badge),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'CITIZEN',
                            child: Text('👤 Citizen / Volunteer'),
                          ),
                          DropdownMenuItem(
                            value: 'AMBULANCE_DRIVER',
                            child: Text('🚑 108 Ambulance Driver'),
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
                              selectedRole == 'AMBULANCE_DRIVER' ? Icons.local_hospital : Icons.local_police,
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
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryBlue,
                    minimumSize: const Size(120, 48),
                  ),
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      final nav = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
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
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Profile updated successfully.')),
                      );
                    }
                  },
                  child: const Text('SAVE'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddContactDialog({EmergencyContact? existingContact, int? index}) {
    final nameController = TextEditingController(text: existingContact?.name ?? '');
    final phoneController = TextEditingController(text: existingContact?.phoneNumber ?? '');
    String relationship = existingContact?.relationship ?? 'Family';
    const relations = ['Family', 'Parent', 'Spouse', 'Friend', 'Doctor', 'Colleague'];

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  const Icon(Icons.contact_phone, color: AppTheme.primaryRed),
                  const SizedBox(width: 10),
                  Text(existingContact != null ? 'Edit Contact' : 'Add Emergency Contact'),
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
                          labelText: 'Contact Name',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Name required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          hintText: 'e.g. 9876543210 or +91 9876543210',
                          helperText: 'Auto-formatted with +91 for direct SMS & WhatsApp',
                          prefixIcon: Icon(Icons.phone),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Phone required';
                          String digits = val.replaceAll(RegExp(r'[^0-9]'), '');
                          if (digits.length < 10) {
                            return 'Enter at least 10-digit mobile number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: relationship,
                        decoration: const InputDecoration(
                          labelText: 'Relationship',
                          prefixIcon: Icon(Icons.people_outline),
                        ),
                        items: relations.map((rel) => DropdownMenuItem(value: rel, child: Text(rel))).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => relationship = val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed,
                    minimumSize: const Size(120, 48),
                  ),
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      String formattedPhone = EmergencyContactsService.normalizePhoneNumber(phoneController.text.trim());
                      final newContact = EmergencyContact(
                        name: nameController.text.trim(),
                        phoneNumber: formattedPhone,
                        relationship: relationship,
                      );

                      List<EmergencyContact> updated = List.from(_emergencyContacts);
                      if (index != null && index >= 0 && index < updated.length) {
                        updated[index] = newContact;
                      } else {
                        if (updated.length >= 3) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Maximum 3 emergency contacts allowed.')),
                          );
                          Navigator.of(context).pop();
                          return;
                        }
                        updated.add(newContact);
                      }

                      final nav = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      await _contactsService.saveContacts(updated);
                      if (!mounted) return;
                      nav.pop();
                      _loadContacts();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Emergency contact saved successfully.')),
                      );
                    }
                  },
                  child: const Text('SAVE'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteContact(int index) async {
    List<EmergencyContact> updated = List.from(_emergencyContacts);
    if (index >= 0 && index < updated.length) {
      updated.removeAt(index);
      await _contactsService.saveContacts(updated);
      _loadContacts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Emergency contact removed.')),
        );
      }
    }
  }

  void _testSendSMS() async {
    if (_emergencyContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least 1 emergency contact first.')),
      );
      return;
    }

    final pos = await _locationService.getCurrentLocation();
    double lat = pos?.latitude ?? 21.2253;
    double lon = pos?.longitude ?? 81.3107;

    bool sent = await _contactsService.sendEmergencySMS(
      latitude: lat,
      longitude: lon,
      type: 'TEST EMERGENCY',
    );

    if (mounted) {
      if (sent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening SMS app with live coordinates for your contacts...'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch SMS. Check phone number format.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    String name = _userProfile?.name ?? user?.displayName ?? 'Community Volunteer';
    String email = _userProfile?.email ?? user?.email ?? 'user@vita-resq.org';
    String phone = _userProfile?.phoneNumber ?? 'No phone listed';
    String blood = _userProfile?.bloodGroup ?? 'Not set';

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
          'PROFILE & MEDICAL ID',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 0.8,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bento Profile Header Card (Tappable Avatar for Editing)
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.cardGlassGradient,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Tappable Avatar with Camera Indicator
                    InkWell(
                      onTap: _showEditProfileDialog,
                      borderRadius: BorderRadius.circular(50),
                      child: Tooltip(
                        message: 'Tap to Edit Profile',
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 92,
                              height: 92,
                              decoration: BoxDecoration(
                                gradient: _userProfile?.userRole == 'AMBULANCE_DRIVER'
                                    ? AppTheme.emergencyGradient
                                    : _userProfile?.userRole == 'POLICE_PCR'
                                        ? AppTheme.cyberBlueGradient
                                        : const LinearGradient(colors: [Color(0xFF64748B), Color(0xFF334155)]),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (_userProfile?.userRole == 'AMBULANCE_DRIVER'
                                            ? AppTheme.primaryRed
                                            : _userProfile?.userRole == 'POLICE_PCR'
                                                ? AppTheme.secondaryBlue
                                                : Colors.black)
                                        .withValues(alpha: 0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  _userProfile?.userRole == 'AMBULANCE_DRIVER'
                                      ? Icons.local_hospital_rounded
                                      : _userProfile?.userRole == 'POLICE_PCR'
                                          ? Icons.local_police_rounded
                                          : Icons.person_rounded,
                                  size: 48,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.edit_rounded, size: 14, color: AppTheme.onSurface),
                            ),
                          ],
                        ),
                      ),
                    ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.onSurface,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.secondaryBlue),
                            onPressed: _showEditProfileDialog,
                          ),
                        ],
                      ),
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // User Info Metadata Badges (Blood Group & Phone)
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bloodtype, size: 14, color: AppTheme.primaryRed),
                                const SizedBox(width: 4),
                                Text(
                                  'Blood Group: $blood',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.phone, size: 14, color: AppTheme.secondaryBlue),
                                const SizedBox(width: 4),
                                Text(
                                  phone,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.secondaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Responder Role Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _userProfile?.userRole == 'AMBULANCE_DRIVER'
                              ? AppTheme.primaryRed.withValues(alpha: 0.1)
                              : _userProfile?.userRole == 'POLICE_PCR'
                                  ? AppTheme.secondaryBlue.withValues(alpha: 0.1)
                                  : AppTheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _userProfile?.userRole == 'AMBULANCE_DRIVER'
                                ? AppTheme.primaryRed
                                : _userProfile?.userRole == 'POLICE_PCR'
                                    ? AppTheme.secondaryBlue
                                    : AppTheme.outlineColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _userProfile?.userRole == 'AMBULANCE_DRIVER'
                                  ? Icons.local_hospital
                                  : _userProfile?.userRole == 'POLICE_PCR'
                                      ? Icons.local_police
                                      : Icons.verified_user_outlined,
                              size: 16,
                              color: _userProfile?.userRole == 'AMBULANCE_DRIVER'
                                  ? AppTheme.primaryRed
                                  : _userProfile?.userRole == 'POLICE_PCR'
                                      ? AppTheme.secondaryBlue
                                      : AppTheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _userProfile?.userRole == 'AMBULANCE_DRIVER'
                                  ? '🚑 108 AMBULANCE (${_userProfile?.vehicleNumber ?? 'DL-04-108'})'
                                  : _userProfile?.userRole == 'POLICE_PCR'
                                      ? '🚓 POLICE PATROL / PCR (${_userProfile?.vehicleNumber ?? 'PCR-12'})'
                                      : '👤 CITIZEN VOLUNTEER',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _userProfile?.userRole == 'AMBULANCE_DRIVER'
                                    ? AppTheme.primaryRed
                                    : _userProfile?.userRole == 'POLICE_PCR'
                                        ? AppTheme.secondaryBlue
                                        : AppTheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Connection: Online',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.my_location, size: 12, color: AppTheme.secondaryBlue),
                                const SizedBox(width: 6),
                                Text(
                                  'GPS: Active',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Community Impact & Civic Recognition Section
              _buildCommunityImpactSection(name),

              // Emergency Contacts (Auto-SMS Fallback) Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      'EMERGENCY CONTACTS (AUTO-SMS)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryRed,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (_emergencyContacts.length < 3)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.add, size: 16, color: AppTheme.primaryRed),
                      label: const Text(
                        'ADD CONTACT',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryRed),
                      ),
                      onPressed: () => _showAddContactDialog(),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'If no nearby responders connect within 60s, Vita ResQ automatically prepares an emergency SMS with your live GPS location for these 3 contacts.',
                        style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      if (_emergencyContacts.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Column(
                              children: [
                                Icon(Icons.contact_emergency, size: 36, color: AppTheme.outlineColor.withValues(alpha: 0.5)),
                                const SizedBox(height: 8),
                                const Text(
                                  'No Emergency Contacts Added',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Add up to 3 trusted family members or friends.',
                                  style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(160, 40),
                                    foregroundColor: AppTheme.primaryRed,
                                    side: const BorderSide(color: AppTheme.primaryRed),
                                  ),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add Contact Now'),
                                  onPressed: () => _showAddContactDialog(),
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _emergencyContacts.length,
                          separatorBuilder: (_, __) => const Divider(height: 16),
                          itemBuilder: (context, idx) {
                            final c = _emergencyContacts[idx];
                            return Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryRed.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.person, color: AppTheme.primaryRed, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            c.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.surfaceContainer,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              c.relationship,
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.onSurfaceVariant),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        c.phoneNumber,
                                        style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.secondaryBlue),
                                  onPressed: () => _showAddContactDialog(existingContact: c, index: idx),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.errorRed),
                                  onPressed: () => _deleteContact(idx),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 42),
                                  foregroundColor: AppTheme.secondaryBlue,
                                  side: const BorderSide(color: AppTheme.secondaryBlue),
                                ),
                                icon: const Icon(Icons.sms_outlined, size: 16),
                                label: const Text('🧪 Test Emergency SMS'),
                                onPressed: _testSendSMS,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Settings & Permissions Section
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  'SETTINGS & PERMISSIONS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryRed.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.car_crash_outlined, color: AppTheme.primaryRed, size: 20),
                      ),
                      title: const Text('Automatic Accident Detection', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Auto-triggers SOS upon crash impact', style: TextStyle(fontSize: 12)),
                      value: _accidentDetectionEnabled,
                      activeThumbColor: AppTheme.primaryRed,
                      onChanged: (val) async {
                        setState(() => _accidentDetectionEnabled = val);
                        await _accidentService.setEnabled(val);
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on, color: AppTheme.secondaryBlue, size: 20),
                      ),
                      title: const Text('Location Access', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Required for emergency routing', style: TextStyle(fontSize: 12)),
                      value: _locationPermissionEnabled,
                      activeThumbColor: AppTheme.secondaryBlue,
                      onChanged: (val) => setState(() => _locationPermissionEnabled = val),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.tertiaryAmber.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notifications, color: AppTheme.tertiaryAmber, size: 20),
                      ),
                      title: const Text('Push Notifications', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Alerts for critical incidents', style: TextStyle(fontSize: 12)),
                      value: _notificationsEnabled,
                      activeThumbColor: AppTheme.tertiaryAmber,
                      onChanged: (val) => setState(() => _notificationsEnabled = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Developer / Demo Controls (Hidden in Release Builds)
              if (!kReleaseMode) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    'DEVELOPER / DEMO CONTROLS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.tertiaryAmber,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  color: AppTheme.surfaceLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppTheme.tertiaryAmber, width: 1.5),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppTheme.tertiaryContainerAmber,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.science, color: Colors.white, size: 20),
                    ),
                    title: const Text(
                      '🧪 Test Accident Detection',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                    ),
                    subtitle: const Text(
                      'Injects simulated crash sensor data to test SOS countdown flow safely.',
                      style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                    ),
                    onTap: () {
                      _accidentService.simulateAccidentEvent();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Simulated crash sensor event injected. Switch to Home Screen to view countdown.'),
                          backgroundColor: AppTheme.tertiaryAmber,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Log Out Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
                icon: const Icon(Icons.logout, size: 20),
                label: const Text('LOG OUT'),
                onPressed: () async {
                  await _authService.signOut();
                  if (context.mounted) {
                    AppNavigator.navigateToLogin(context);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommunityImpactSection(String userName) {
    final level = _impactProfile.currentLevel;
    final progress = level.getProgress(_impactProfile.impactPoints);
    final ptsToNext = level.getPointsToNext(_impactProfile.impactPoints);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                'YOUR COMMUNITY IMPACT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.secondaryBlue,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            InkWell(
              onTap: () => CommunityCertificateDialog.show(
                context,
                userName: userName,
                impactProfile: _impactProfile,
              ),
              child: const Row(
                children: [
                  Icon(Icons.workspace_premium_rounded, size: 16, color: Color(0xFFD4AF37)),
                  SizedBox(width: 4),
                  Text(
                    'CERTIFICATE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Bento Card 1: Level Banner & Points Progress
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: level.color.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(level.icon, color: level.color, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            level.title.toUpperCase(),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: level.color,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const Text(
                            'Civic Emergency Rank',
                            style: TextStyle(fontSize: 11, color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      'LVL ${level.levelNumber}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Points & Progress Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_impactProfile.impactPoints} Impact Points',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    ptsToNext > 0 ? '$ptsToNext pts to next rank' : 'Max Rank Achieved 🎉',
                    style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(level.color),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Bento 4-Tile Grid
        Row(
          children: [
            Expanded(
              child: _buildImpactMetricTile(
                icon: Icons.volunteer_activism_rounded,
                iconColor: const Color(0xFF10B981),
                label: 'Verified Assists',
                value: '${_impactProfile.verifiedAssists}',
                subtext: 'Responses completed',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildImpactMetricTile(
                icon: Icons.location_on_rounded,
                iconColor: AppTheme.secondaryBlue,
                label: 'Victims Reached',
                value: '${_impactProfile.victimsReached}',
                subtext: 'Scene verified <100m',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildImpactMetricTile(
                icon: Icons.verified_user_rounded,
                iconColor: const Color(0xFF8B5CF6),
                label: 'Reliability Score',
                value: '${_impactProfile.reliabilityScore.toStringAsFixed(0)}%',
                subtext: 'Follow-through rate',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildImpactMetricTile(
                icon: Icons.military_tech_rounded,
                iconColor: const Color(0xFFF59E0B),
                label: 'Badges Earned',
                value: '${_impactProfile.unlockedBadgeIds.length} / ${_badges.length}',
                subtext: 'Civic honors',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Badges Gallery
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
          child: Text(
            'CIVIC RECOGNITION BADGES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 115,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _badges.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final b = _badges[index];
              return _buildBadgeCard(b);
            },
          ),
        ),
        const SizedBox(height: 16),

        // Digital Certificate Trigger Card
        InkWell(
          onTap: () => CommunityCertificateDialog.show(
            context,
            userName: userName,
            impactProfile: _impactProfile,
          ),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFD4AF37),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.workspace_premium, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vita ResQ Responder Certificate',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'View & share your verified community certificate',
                        style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF92400E)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildImpactMetricTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtext,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: iconColor, size: 20),
              Text(
                value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard(ImpactBadge badge) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: badge.isUnlocked ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: badge.isUnlocked ? badge.color.withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
          width: badge.isUnlocked ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: badge.isUnlocked ? badge.color.withValues(alpha: 0.1) : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              badge.icon,
              color: badge.isUnlocked ? badge.color : Colors.grey.shade400,
              size: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            badge.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: badge.isUnlocked ? const Color(0xFF0F172A) : Colors.grey.shade500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            badge.isUnlocked ? 'UNLOCKED' : 'LOCKED',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: badge.isUnlocked ? badge.color : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}
