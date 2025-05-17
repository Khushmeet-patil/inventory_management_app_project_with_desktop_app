import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'services/notification_service.dart';
import 'utils/toast_util.dart';

class TestNotificationPage extends StatelessWidget {
  final NotificationService _notificationService = NotificationService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Test Notifications'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                margin: EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Platform Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('Platform: ${Platform.operatingSystem}'),
                      Text('Version: ${Platform.operatingSystemVersion}'),
                      Text('Is Windows: ${Platform.isWindows}'),
                      Text('Is Mobile: ${Platform.isAndroid || Platform.isIOS}'),
                    ],
                  ),
                ),
              ),

              ElevatedButton(
                onPressed: () async {
                  try {
                    // Check notification permission status first
                    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
                    print('Notification permission status: $isAllowed');

                    if (!isAllowed) {
                      // Request permission if not granted
                      final permissionResult = await _notificationService.requestPermissions();
                      print('Permission request result: $permissionResult');
                      ToastUtil.showInfo('Permission request result: ${permissionResult ? 'Granted' : 'Denied'}');

                      if (!permissionResult) {
                        ToastUtil.showError('Notification permission denied');
                        return;
                      }
                    }

                    // Show notification
                    await _notificationService.showProductAddedNotification(
                      productName: 'Test Product',
                      quantity: 5,
                    );
                    ToastUtil.showInfo('Product added notification triggered');
                  } catch (e) {
                    print('Error in test notification: $e');
                    ToastUtil.showError('Error: $e');
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.green,
                ),
                child: Text('Test Product Added Notification'),
              ),

              SizedBox(height: 16),

              ElevatedButton(
                onPressed: () async {
                  try {
                    await _notificationService.showStockAddedNotification(
                      productName: 'Test Product',
                      quantity: 10,
                    );
                    ToastUtil.showInfo('Stock added notification triggered');
                  } catch (e) {
                    ToastUtil.showError('Error: $e');
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.blue,
                ),
                child: Text('Test Stock Added Notification'),
              ),

              SizedBox(height: 16),

              ElevatedButton(
                onPressed: () async {
                  try {
                    await _notificationService.showProductUpdatedNotification(
                      productName: 'Test Product',
                    );
                    ToastUtil.showInfo('Product updated notification triggered');
                  } catch (e) {
                    ToastUtil.showError('Error: $e');
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.orange,
                ),
                child: Text('Test Product Updated Notification'),
              ),

              SizedBox(height: 24),

              ElevatedButton(
                onPressed: () async {
                  try {
                    bool granted = await _notificationService.requestPermissions();
                    ToastUtil.showInfo('Permission request result: ${granted ? 'Granted' : 'Denied'}');
                  } catch (e) {
                    ToastUtil.showError('Error requesting permissions: $e');
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.purple,
                ),
                child: Text('Request Notification Permissions'),
              ),

              SizedBox(height: 16),

              ElevatedButton(
                onPressed: () {
                  ToastUtil.showSuccess('This is a success toast message');
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.teal,
                ),
                child: Text('Test Toast Message'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
