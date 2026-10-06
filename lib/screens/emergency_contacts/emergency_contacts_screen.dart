import 'package:flutter/material.dart';
import '../../services/emergency_service.dart';
import '../../services/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../widgets/common/app_feedback.dart';
import '../../widgets/app_dialogs.dart';

/// Dedicated Emergency Contacts Screen (Phase 11 Information Architecture).
///
/// Manages up to 3 trusted emergency contacts for automated SMS dispatch
/// and fallback escalation when nearby responders do not connect within 60s.
class EmergencyContactsScreen extends StatefulWidget {
  final List<EmergencyContact>? initialContacts;

  const EmergencyContactsScreen({
    super.key,
    this.initialContacts,
  });

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final EmergencyContactsService _contactsService = EmergencyContactsService();
  final LocationService _locationService = LocationService();

  List<EmergencyContact> _emergencyContacts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialContacts != null) {
      _emergencyContacts = widget.initialContacts!;
    }
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final contacts = await _contactsService.getContacts();
    if (mounted) {
      setState(() {
        if (contacts.isNotEmpty) {
          _emergencyContacts = contacts;
        } else if (widget.initialContacts != null) {
          _emergencyContacts = widget.initialContacts!;
        }
        _isLoading = false;
      });
    }
  }

  void _showAddEditContactDialog({EmergencyContact? existingContact, int? index}) {
    final nameController = TextEditingController(text: existingContact?.name ?? '');
    final phoneController = TextEditingController(text: existingContact?.phoneNumber ?? '');
    String relationship = existingContact?.relationship ?? 'Family';
    const relations = ['Family', 'Parent', 'Spouse', 'Friend', 'Doctor', 'Colleague'];

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.contact_phone_outlined, color: AppColors.emergencyRed),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      existingContact != null ? 'Edit Contact' : 'Add Emergency Contact',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
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
                          labelText: 'Contact Name',
                          prefixIcon: Icon(Icons.person_outline),
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
                          helperText: 'Auto-formatted with +91 for direct SMS',
                          prefixIcon: Icon(Icons.phone_outlined),
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
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emergencyRed,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(110, 44),
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
                          AppSnackbar.showWarning(context, 'Maximum 3 emergency contacts allowed.');
                          Navigator.of(dialogCtx).pop();
                          return;
                        }
                        updated.add(newContact);
                      }

                      final nav = Navigator.of(dialogCtx);
                      await _contactsService.saveContacts(updated);
                      if (!mounted) return;
                      nav.pop();
                      _loadContacts();
                      if (mounted) {
                        AppSnackbar.showSuccess(context, 'Emergency contact saved.');
                      }
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
    final confirm = await AppDialogs.showDestructiveConfirmDialog(
      context: context,
      title: 'Remove contact?',
      message: 'This contact will no longer receive emergency alerts.',
      cancelLabel: 'Keep Contact',
      confirmLabel: 'Remove Contact',
      isDangerous: true,
    );
    if (confirm != true || !mounted) return;

    List<EmergencyContact> updated = List.from(_emergencyContacts);
    if (index >= 0 && index < updated.length) {
      updated.removeAt(index);
      await _contactsService.saveContacts(updated);
      _loadContacts();
      if (mounted) {
        AppSnackbar.showSuccess(context, 'Emergency contact removed.');
      }
    }
  }

  void _testSendSMS() async {
    if (_emergencyContacts.isEmpty) {
      AppSnackbar.showWarning(context, 'Please add at least 1 emergency contact first.');
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
        AppSnackbar.showSuccess(
          context,
          'Opening SMS app with coordinates for your contacts…',
        );
      } else {
        AppSnackbar.showError(
          context,
          'Could not launch SMS. Check phone number format.',
        );
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
          'Emergency Contacts',
          style: AppTypography.sectionHeading.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.deepNavy,
          ),
        ),
        centerTitle: false,
        actions: [
          if (_emergencyContacts.length < 3)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.emergencyRed,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('ADD', style: TextStyle(fontWeight: FontWeight.w800)),
                onPressed: () => _showAddEditContactDialog(),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Info Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfacePureWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.emergencyRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.shield_outlined, color: AppColors.emergencyRed, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Automated SMS Escalation',
                                  style: AppTypography.subheading.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.deepNavy,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'If no nearby responders connect within 60s during an active SOS, Vita ResQ dispatches direct SMS alerts containing your live coordinates to these trusted contacts.',
                                  style: AppTypography.bodySecondary.copyWith(fontSize: 12, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TRUSTED CONTACTS (${_emergencyContacts.length}/3)',
                          style: AppTypography.caption.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_emergencyContacts.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
                        decoration: BoxDecoration(
                          color: AppColors.surfacePureWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.subtleBlueGray,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.contact_phone_outlined,
                                size: 28,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'No Emergency Contacts Added',
                              style: AppTypography.subheading.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.deepNavy,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Add up to 3 trusted family members or friends to ensure someone is always notified when you need help.',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodySecondary.copyWith(fontSize: 12.5, height: 1.4),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.emergencyRed,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(180, 46),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Contact Now', style: TextStyle(fontWeight: FontWeight.w700)),
                              onPressed: () => _showAddEditContactDialog(),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfacePureWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _emergencyContacts.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.borderSubtle),
                          itemBuilder: (context, idx) {
                            final c = _emergencyContacts[idx];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.emergencyLightRed,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.person_outline,
                                      color: AppColors.emergencyRed,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                c.name,
                                                style: AppTypography.subheading.copyWith(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.deepNavy,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.subtleBlueGray,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                c.relationship,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          c.phoneNumber,
                                          style: AppTypography.bodySecondary.copyWith(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 19, color: AppColors.brandBlue),
                                    tooltip: 'Edit',
                                    onPressed: () => _showAddEditContactDialog(existingContact: c, index: idx),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 19, color: AppColors.emergencyRed),
                                    tooltip: 'Delete',
                                    onPressed: () => _deleteContact(idx),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                    if (_emergencyContacts.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          foregroundColor: AppColors.brandBlue,
                          side: const BorderSide(color: AppColors.brandBlue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.sms_outlined, size: 18),
                        label: const Text(
                          'Test Emergency SMS to Contacts',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onPressed: _testSendSMS,
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
