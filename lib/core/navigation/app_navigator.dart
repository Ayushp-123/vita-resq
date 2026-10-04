import 'package:flutter/material.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/emergency/emergency_details_screen.dart';
import '../../screens/emergency/emergency_map_screen.dart';
import '../../screens/profile/profile_screen.dart';

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
}
