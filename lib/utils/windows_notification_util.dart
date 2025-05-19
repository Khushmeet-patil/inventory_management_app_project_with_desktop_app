import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Utility class for Windows-specific notifications
class WindowsNotificationUtil {
  /// Check if the app is running on Windows
  static bool get isWindows => Platform.isWindows;
  
  /// Show a blue snackbar notification on Windows
  static void showNotification(String title, String message, {IconData? icon}) {
    if (!isWindows) return;
    
    try {
      // Close any existing snackbars first
      Get.closeAllSnackbars();
      
      // Show a blue snackbar
      Get.snackbar(
        title,
        message,
        backgroundColor: Colors.blue.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
        margin: const EdgeInsets.all(16),
        borderRadius: 8,
        isDismissible: true,
        forwardAnimationCurve: Curves.easeOutCirc,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        snackStyle: SnackStyle.FLOATING,
        overlayBlur: 0.0,
        overlayColor: Colors.black.withOpacity(0.2),
        barBlur: 0.0,
        animationDuration: const Duration(milliseconds: 500),
        icon: Icon(
          icon ?? Icons.info,
          color: Colors.white,
          size: 28,
        ),
      );
    } catch (e) {
      debugPrint('Error showing Windows notification: $e');
    }
  }
  
  /// Show a product added notification
  static void showProductAdded(String productName, int quantity) {
    if (!isWindows) return;
    showNotification(
      'Product Added',
      'Added $quantity units of $productName',
      icon: Icons.add_circle,
    );
  }
  
  /// Show a product rented notification
  static void showProductRented(String productName, int quantity, String person) {
    if (!isWindows) return;
    showNotification(
      'Product Rented',
      '$quantity units of $productName rented to $person',
      icon: Icons.shopping_cart,
    );
  }
  
  /// Show a product returned notification
  static void showProductReturned(String productName, int quantity, String person) {
    if (!isWindows) return;
    showNotification(
      'Product Returned',
      '$quantity units of $productName returned by $person',
      icon: Icons.assignment_return,
    );
  }
  
  /// Show a server connection notification
  static void showServerConnected(String serverName, String serverIp) {
    if (!isWindows) return;
    showNotification(
      'Server Connected',
      'Connected to server: $serverName ($serverIp)',
      icon: Icons.link,
    );
  }
  
  /// Show a device connected notification
  static void showDeviceConnected(String deviceName, String deviceIp) {
    if (!isWindows) return;
    showNotification(
      'Device Connected',
      'Device connected: $deviceName ($deviceIp)',
      icon: Icons.devices,
    );
  }
  
  /// Show a sync completed notification
  static void showSyncCompleted(int itemCount) {
    if (!isWindows) return;
    showNotification(
      'Sync Completed',
      'Successfully synced $itemCount items',
      icon: Icons.sync,
    );
  }
}
