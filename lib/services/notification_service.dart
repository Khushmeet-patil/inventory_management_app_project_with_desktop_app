import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../utils/toast_util.dart';
import '../utils/windows_notification_util.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();

  NotificationService._init();

  // Simple initialization method that doesn't do anything now
  Future<void> initialize() async {
    print('Initializing notification service');
    // No initialization needed for toast notifications
  }

  // Show notification when a product is added
  Future<void> showProductAddedNotification({
    required String productName,
    required int quantity,
  }) async {
    print('Showing product added notification: $productName, quantity: $quantity');
    
    if (Platform.isWindows) {
      // Use Windows blue snackbar
      WindowsNotificationUtil.showProductAdded(productName, quantity);
    } else {
      // Use toast for other platforms
      ToastUtil.showSuccess('${'product_added'.tr}: $productName, ${'quantity'.tr}: $quantity');
    }
  }

  // Show notification when a product is updated
  Future<void> showProductUpdatedNotification({
    required String productName,
  }) async {
    print('Showing product updated notification: $productName');
    
    if (Platform.isWindows) {
      // Use Windows blue snackbar
      WindowsNotificationUtil.showNotification(
        'Product Updated',
        'Updated product: $productName',
        icon: Icons.edit,
      );
    } else {
      // Use toast for other platforms
      ToastUtil.showSuccess('${'product_updated'.tr}: $productName');
    }
  }

  // Show notification when stock is added
  Future<void> showStockAddedNotification({
    required String productName,
    required int quantity,
  }) async {
    print('Showing stock added notification: $productName, quantity: $quantity');
    
    if (Platform.isWindows) {
      // Use Windows blue snackbar
      WindowsNotificationUtil.showNotification(
        'Stock Added',
        'Added $quantity units of $productName',
        icon: Icons.add_box,
      );
    } else {
      // Use toast for other platforms
      ToastUtil.showSuccess('${'added'.tr} $quantity ${'units_of'.tr} $productName');
    }
  }
  
  // Show notification when products are rented
  Future<void> showProductRentedNotification({
    required String productName,
    required int quantity,
    required String person,
  }) async {
    print('Showing product rented notification: $productName, quantity: $quantity, person: $person');
    
    if (Platform.isWindows) {
      // Use Windows blue snackbar
      WindowsNotificationUtil.showProductRented(productName, quantity, person);
    } else {
      // Use toast for other platforms
      ToastUtil.showSuccess('${'rented'.tr} $quantity ${'units_of'.tr} $productName ${'to'.tr} $person');
    }
  }
  
  // Show notification when products are returned
  Future<void> showProductReturnedNotification({
    required String productName,
    required int quantity,
    required String person,
  }) async {
    print('Showing product returned notification: $productName, quantity: $quantity, person: $person');
    
    if (Platform.isWindows) {
      // Use Windows blue snackbar
      WindowsNotificationUtil.showProductReturned(productName, quantity, person);
    } else {
      // Use toast for other platforms
      ToastUtil.showSuccess('${'returned'.tr} $quantity ${'units_of'.tr} $productName ${'by'.tr} $person');
    }
  }
}
