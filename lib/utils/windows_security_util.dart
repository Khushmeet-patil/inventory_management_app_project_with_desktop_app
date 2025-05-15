import 'dart:io';
import 'package:flutter/foundation.dart';
import '../utils/toast_util.dart';

/// Utility class for Windows-specific security features
class WindowsSecurityUtil {
  /// Check if the app is running on Windows
  static bool get isWindows => Platform.isWindows;
  
  /// Show a message about firewall permissions
  static void showFirewallMessage() {
    if (!isWindows) return;
    
    try {
      ToastUtil.showInfo(
        'If prompted, please allow Inventory Management to access your network through Windows Firewall',
      );
    } catch (e) {
      debugPrint('Error showing firewall message: $e');
    }
  }
  
  /// Show a message about antivirus software
  static void showAntivirusMessage() {
    if (!isWindows) return;
    
    try {
      ToastUtil.showInfo(
        'This app uses local network for syncing. If your antivirus flags it, please add it to exceptions.',
      );
    } catch (e) {
      debugPrint('Error showing antivirus message: $e');
    }
  }
  
  /// Show a message about app security
  static void showSecurityMessage() {
    if (!isWindows) return;
    
    try {
      ToastUtil.showInfo(
        'This app only communicates on your local network and does not access the internet.',
      );
    } catch (e) {
      debugPrint('Error showing security message: $e');
    }
  }
}
