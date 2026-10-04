import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class AppPermissionsService {
  static final AppPermissionsService _instance = AppPermissionsService._internal();
  factory AppPermissionsService() => _instance;
  AppPermissionsService._internal();

  /// Check if essential emergency permissions (Location) are granted
  Future<bool> hasAllCriticalPermissions() async {
    LocationPermission geoPerm = await Geolocator.checkPermission();
    bool locationGranted = (geoPerm == LocationPermission.always || geoPerm == LocationPermission.whileInUse) ||
        await Permission.location.isGranted;
    return locationGranted;
  }

  /// Request all life-critical emergency permissions sequentially to trigger native OS popups
  Future<void> requestAllPermissions() async {
    try {
      // 1. Location Permission
      LocationPermission geoPerm = await Geolocator.checkPermission();
      if (geoPerm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      if (!await Permission.location.isGranted) {
        await Permission.location.request();
      }

      // 2. Notifications Permission (Android 13+)
      if (!await Permission.notification.isGranted) {
        await Permission.notification.request();
      }

      // 3. Nearby Bluetooth / Wi-Fi Devices (Android 12+)
      if (Platform.isAndroid) {
        if (!await Permission.bluetoothScan.isGranted) {
          await Permission.bluetoothScan.request();
        }
        if (!await Permission.bluetoothConnect.isGranted) {
          await Permission.bluetoothConnect.request();
        }
        if (!await Permission.nearbyWifiDevices.isGranted) {
          await Permission.nearbyWifiDevices.request();
        }
      }
    } catch (e) {
      if (kDebugMode) print('[PERMISSIONS ERROR] $e');
    }
  }

  /// Check individual permissions
  Future<bool> isLocationGranted() async {
    LocationPermission geoPerm = await Geolocator.checkPermission();
    return (geoPerm == LocationPermission.always || geoPerm == LocationPermission.whileInUse) ||
        await Permission.location.isGranted;
  }

  Future<bool> isNotificationGranted() async {
    return await Permission.notification.isGranted;
  }

  /// Intent-based SMS requires zero runtime permissions
  Future<bool> isSmsGranted() async {
    return true;
  }

  /// Open application settings if permissions were permanently denied
  Future<void> openSettings() async {
    await openAppSettings();
  }
}
