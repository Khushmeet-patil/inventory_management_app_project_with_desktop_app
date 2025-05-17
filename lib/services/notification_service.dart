import 'dart:io';
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:get/get.dart';
import '../utils/toast_util.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();

  NotificationService._init();

  Future<void> initialize() async {
    try {
      print('Initializing awesome notifications...');

      // Set default icon based on platform
      String defaultIcon = 'resource://drawable/ic_notification';
      if (Platform.isWindows) {
        // For Windows, use a null icon as fallback
        defaultIcon = '@mipmap/ic_launcher';
        print('Using Windows-specific icon: $defaultIcon');
      }

      print('Creating notification channel...');
      final result = await AwesomeNotifications().initialize(
        defaultIcon,
        [
          NotificationChannel(
            channelKey: 'product_channel',
            channelName: 'Product Notifications',
            channelDescription: 'Notifications for product operations',
            defaultColor: Colors.teal,
            ledColor: Colors.teal,
            importance: NotificationImportance.High,
            playSound: true,
            enableVibration: true,
          ),
        ],
      );

      print('Awesome notifications initialization result: $result');

      // Request notification permissions
      final permissionResult = await requestPermissions();
      print('Notification permission result: $permissionResult');

      print('Awesome notifications initialized successfully');
    } catch (e, stackTrace) {
      print('Error initializing awesome notifications: $e');
      print('Stack trace: $stackTrace');

      // Show fallback toast on Windows if notifications fail
      if (Platform.isWindows) {
        ToastUtil.showInfo('Notifications may not work properly on this device.');
      }
    }
  }

  Future<bool> requestPermissions() async {
    try {
      print('Requesting notification permissions...');
      final result = await AwesomeNotifications().requestPermissionToSendNotifications();
      print('Permission request result: $result');
      return result;
    } catch (e, stackTrace) {
      print('Error requesting notification permissions: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  Future<bool> isNotificationAllowed() async {
    try {
      final result = await AwesomeNotifications().isNotificationAllowed();
      print('Notification permission status: $result');
      return result;
    } catch (e) {
      print('Error checking notification permission: $e');
      return false;
    }
  }

  Future<void> showProductAddedNotification({
    required String productName,
    required int quantity,
  }) async {
    try {
      print('Showing product added notification: $productName, quantity: $quantity');

      // Create a unique ID for the notification
      final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      print('Notification ID: $notificationId');

      // Create notification content
      final notificationContent = NotificationContent(
        id: notificationId,
        channelKey: 'product_channel',
        title: 'product_added'.tr,
        body: '${'product'.tr}: $productName, ${'quantity'.tr}: $quantity',
        notificationLayout: NotificationLayout.Default,
        color: Colors.green,
        // Add platform-specific settings
        category: NotificationCategory.Status,
      );

      print('Creating notification with content: ${notificationContent.toMap()}');

      // Create the notification
      final result = await AwesomeNotifications().createNotification(
        content: notificationContent,
      );

      print('Notification creation result: $result');

      // Always show toast on Windows for better feedback
      if (Platform.isWindows) {
        ToastUtil.showSuccess('${'product_added'.tr}: $productName, ${'quantity'.tr}: $quantity');
      }
    } catch (e, stackTrace) {
      print('Error showing product added notification: $e');
      print('Stack trace: $stackTrace');
      // Fallback to toast
      ToastUtil.showSuccess('${'product_added'.tr}: $productName, ${'quantity'.tr}: $quantity');
    }
  }

  Future<void> showProductUpdatedNotification({
    required String productName,
  }) async {
    try {
      print('Showing product updated notification: $productName');

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: 'product_channel',
          title: 'product_updated'.tr,
          body: '${'product'.tr}: $productName',
          notificationLayout: NotificationLayout.Default,
          color: Colors.blue,
        ),
      );

      // Fallback for Windows if notification fails
      if (Platform.isWindows) {
        ToastUtil.showSuccess('${'product_updated'.tr}: $productName');
      }
    } catch (e) {
      print('Error showing product updated notification: $e');
      // Fallback to toast
      ToastUtil.showSuccess('${'product_updated'.tr}: $productName');
    }
  }

  Future<void> showStockAddedNotification({
    required String productName,
    required int quantity,
  }) async {
    try {
      print('Showing stock added notification: $productName, quantity: $quantity');

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: 'product_channel',
          title: 'stock_added'.tr,
          body: '${'added'.tr} $quantity ${'units_of'.tr} $productName',
          notificationLayout: NotificationLayout.Default,
          color: Colors.green,
        ),
      );

      // Fallback for Windows if notification fails
      if (Platform.isWindows) {
        ToastUtil.showSuccess('${'added'.tr} $quantity ${'units_of'.tr} $productName');
      }
    } catch (e) {
      print('Error showing stock added notification: $e');
      // Fallback to toast
      ToastUtil.showSuccess('${'added'.tr} $quantity ${'units_of'.tr} $productName');
    }
  }

  // Method to handle notification actions
  @pragma('vm:entry-point')
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    try {
      print('Received notification action: ${receivedAction.toMap()}');

      // Handle notification actions if needed
      if (receivedAction.channelKey == 'product_channel') {
        print('Product channel notification action received');
        // Navigate to a specific page or perform an action
        if (receivedAction.buttonKeyPressed == 'VIEW_PRODUCT') {
          // Navigate to product details page
          print('View product button pressed');
        }
      }
    } catch (e, stackTrace) {
      print('Error handling notification action: $e');
      print('Stack trace: $stackTrace');
    }
  }
}
