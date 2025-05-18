import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../utils/toast_util.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();

  NotificationService._init();

  // Simple initialization method that doesn't do anything now
  Future<void> initialize() async {
    print('Initializing notification service (toast-only mode)');
    // No initialization needed for toast notifications
  }

  // Show notification when a product is added
  Future<void> showProductAddedNotification({
    required String productName,
    required int quantity,
  }) async {
    print('Showing product added toast: $productName, quantity: $quantity');
    ToastUtil.showSuccess('${'product_added'.tr}: $productName, ${'quantity'.tr}: $quantity');
  }

  // Show notification when a product is updated
  Future<void> showProductUpdatedNotification({
    required String productName,
  }) async {
    print('Showing product updated toast: $productName');
    ToastUtil.showSuccess('${'product_updated'.tr}: $productName');
  }

  // Show notification when stock is added
  Future<void> showStockAddedNotification({
    required String productName,
    required int quantity,
  }) async {
    print('Showing stock added toast: $productName, quantity: $quantity');
    ToastUtil.showSuccess('${'added'.tr} $quantity ${'units_of'.tr} $productName');
  }
}
