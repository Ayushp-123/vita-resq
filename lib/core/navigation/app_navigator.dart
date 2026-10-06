import 'package:flutter/material.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/emergency/emergency_details_screen.dart';
import '../../screens/emergency/emergency_map_screen.dart';
import '../../screens/history/emergency_history_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/responder/responder_dashboard_screen.dart';
import '../../screens/emergency_contacts/emergency_contacts_screen.dart';
import '../../screens/safety/crash_detection_screen.dart';
import '../../screens/impact/impact_rewards_screen.dart';
import '../../screens/impact/certificates_screen.dart';
import '../../screens/demo/accident_detection_demo_screen.dart';

class AppNavigator {
  static void navigateToHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  static void navigateToLogin(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  static void navigateToRegister(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  static void navigateToHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EmergencyHistoryScreen()),
    );
  }

  static void navigateToProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  static void navigateToEmergencyDetails(BuildContext context, String emergencyId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmergencyDetailsScreen(emergencyId: emergencyId),
      ),
    );
  }

  static void replaceWithEmergencyMap(BuildContext context, String emergencyId) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => EmergencyMapScreen(emergencyId: emergencyId),
      ),
    );
  }

  static void navigateToEmergencyMap(BuildContext context, String emergencyId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmergencyMapScreen(emergencyId: emergencyId),
      ),
    );
  }

  static void navigateToResponderDashboard(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ResponderDashboardScreen(),
      ),
    );
  }

  static void navigateToEmergencyContacts(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const EmergencyContactsScreen(),
      ),
    );
  }

  static void navigateToCrashDetection(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CrashDetectionScreen(),
      ),
    );
  }

  static void navigateToImpactRewards(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ImpactRewardsScreen(),
      ),
    );
  }

  static void navigateToCertificates(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CertificatesScreen(),
      ),
    );
  }

  static void navigateToAccidentDetectionDemo(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AccidentDetectionDemoScreen(),
      ),
    );
  }
}
