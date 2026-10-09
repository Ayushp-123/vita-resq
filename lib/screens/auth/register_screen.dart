import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../services/app_permissions_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/navigation/app_navigator.dart';
import '../../widgets/common/app_feedback.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController(text: '+91 ');
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _authService = AuthService();

  String _selectedRole = 'CITIZEN'; // 'CITIZEN', 'AMBULANCE_DRIVER', 'POLICE_PCR'
  String _selectedBloodGroup = 'O+';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  Future<void> _requestPermissions() async {
    await AppPermissionsService().requestAllPermissions();
  }

  void _register() async {
    String name = _nameController.text.trim();
    String email = _emailController.text.trim();
    String phone = _phoneController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();
    String vehicleNumber = _vehicleNumberController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      AppSnackbar.showWarning(context, 'Please complete all required fields.');
      return;
    }

    if (!email.contains('@')) {
      AppSnackbar.showWarning(context, 'Please enter a valid email address.');
      return;
    }

    if (password.length < 6) {
      AppSnackbar.showWarning(context, 'Password must be at least 6 characters.');
      return;
    }

    if (password != confirmPassword) {
      AppSnackbar.showWarning(context, 'Passwords do not match.');
      return;
    }

    if (_selectedRole != 'CITIZEN' && vehicleNumber.isEmpty) {
      AppSnackbar.showWarning(context, 'Please enter your Vehicle or Patrol Unit number.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.registerWithEmailAndPassword(
        name: name,
        email: email,
        password: password,
        phoneNumber: phone.length > 4 ? phone : null,
        bloodGroup: _selectedBloodGroup,
        userRole: _selectedRole,
        vehicleNumber: _selectedRole != 'CITIZEN' ? vehicleNumber : null,
      );

      await _requestPermissions();

      if (!mounted) return;
      AppNavigator.navigateToHome(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email address is already registered. Please sign in instead.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address format.';
          break;
        case 'weak-password':
          message = 'The password is too weak. Please use at least 6 characters.';
          break;
        case 'network-request-failed':
          message = 'Network unavailable. Please check your internet connection.';
          break;
        default:
          message = 'Unable to create account. Please check your details and try again.';
      }
      AppSnackbar.showError(context, message);
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.showError(
        context,
        'Unable to create account. Please check your details and try again.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _vehicleNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryRed),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              AppNavigator.navigateToLogin(context);
            }
          },
        ),
        title: const Text('CREATE ACCOUNT'),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.surfaceLight, AppTheme.surfaceContainer],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  elevation: 8,
                  shadowColor: Colors.black.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Badge
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryContainerRed,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shield_outlined,
                              size: 36,
                              color: AppTheme.onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'VITA RESQ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.onSurface,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Join the Community Emergency Response Network',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Full Name
                        const Text('Full Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Rahul Sharma',
                            prefixIcon: Icon(Icons.person_outline, color: AppTheme.outlineColor),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Email Address
                        const Text('Email Address', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'rahul@example.com',
                            prefixIcon: Icon(Icons.mail_outline, color: AppTheme.outlineColor),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Phone Number
                        const Text('Mobile Number (Optional / Emergency SMS)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            hintText: '+91 98765 43210',
                            prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.outlineColor),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Role Selector
                        const Text('Responder Role', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedRole,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.outlineColor),
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
                            if (val != null) setState(() => _selectedRole = val);
                          },
                        ),
                        if (_selectedRole != 'CITIZEN') ...[
                          const SizedBox(height: 16),
                          Text(
                            _selectedRole == 'AMBULANCE_DRIVER'
                                ? 'Ambulance Vehicle Number'
                                : 'PCR Van / Patrol Unit Number',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _vehicleNumberController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: _selectedRole == 'AMBULANCE_DRIVER' ? 'e.g. DL-04-AMB' : 'e.g. PCR-12',
                              prefixIcon: Icon(
                                _selectedRole == 'AMBULANCE_DRIVER' ? Icons.local_hospital : Icons.local_police,
                                color: AppTheme.primaryRed,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Blood Group
                        const Text('Blood Group (Optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedBloodGroup,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.bloodtype_outlined, color: AppTheme.primaryRed),
                          ),
                          items: _bloodGroups.map((bg) => DropdownMenuItem(value: bg, child: Text(bg))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedBloodGroup = val);
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password
                        const Text('Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.outlineColor),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: AppTheme.outlineColor,
                              ),
                              onPressed: () {
                                setState(() => _obscurePassword = !_obscurePassword);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Confirm Password
                        const Text('Confirm Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: const Icon(Icons.lock_reset, color: AppTheme.outlineColor),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: AppTheme.outlineColor,
                              ),
                              onPressed: () {
                                setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Submit Button (Fixed height prevents layout collapse during loading)
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('CREATE ACCOUNT'),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Login Link (Wrap prevents overflow on compact screens)
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'Already registered?',
                              style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 14),
                            ),
                            TextButton(
                              onPressed: () {
                                AppNavigator.navigateToLogin(context);
                              },
                              child: const Text(
                                'Sign In',
                                style: TextStyle(
                                  color: AppTheme.primaryRed,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
