import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';

class ToastUtil {
  // Global navigator key to access context from anywhere
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static void showSuccess(String message) {
    try {
      // Use GetX snackbar for Windows platform
      if (Platform.isWindows) {
        _showWindowsToast(message, Colors.green);
        return;
      }

      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 2,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } catch (e) {
      // Fallback if toast fails
      if (Platform.isIOS || Platform.isWindows) {
        _showFallbackToast(message, Colors.green);
      }
      print('Toast error: $e');
    }
  }

  static void showError(String message) {
    try {
      // Use GetX snackbar for Windows platform
      if (Platform.isWindows) {
        _showWindowsToast(message, Colors.red);
        return;
      }

      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 2,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } catch (e) {
      // Fallback if toast fails
      if (Platform.isIOS || Platform.isWindows) {
        _showFallbackToast(message, Colors.red);
      }
      print('Toast error: $e');
    }
  }

  static void showWarning(String message) {
    try {
      // Use GetX snackbar for Windows platform
      if (Platform.isWindows) {
        _showWindowsToast(message, Colors.orange);
        return;
      }

      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 2,
        backgroundColor: Colors.orange,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } catch (e) {
      // Fallback if toast fails
      if (Platform.isIOS || Platform.isWindows) {
        _showFallbackToast(message, Colors.orange);
      }
      print('Toast error: $e');
    }
  }

  static void showInfo(String message) {
    try {
      // Use GetX snackbar for Windows platform
      if (Platform.isWindows) {
        _showWindowsToast(message, Colors.blue);
        return;
      }

      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 2,
        backgroundColor: Colors.blue,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } catch (e) {
      // Fallback if toast fails
      if (Platform.isIOS || Platform.isWindows) {
        _showFallbackToast(message, Colors.blue);
      }
      print('Toast error: $e');
    }
  }

  // Fallback method for iOS and Windows if the regular toast fails
  static void _showFallbackToast(String message, Color backgroundColor) {
    // Use GetX snackbar as a fallback
    Get.snackbar(
      '',
      message,
      backgroundColor: backgroundColor,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(8),
      borderRadius: 8,
      isDismissible: true,
      forwardAnimationCurve: Curves.easeOutCirc,
    );
  }

  // Windows-specific toast implementation using GetX
  static void _showWindowsToast(String message, Color backgroundColor) {
    // Use GetX snackbar for Windows
    Get.snackbar(
      '',
      message,
      backgroundColor: backgroundColor,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(10),
      borderRadius: 8,
      isDismissible: true,
      forwardAnimationCurve: Curves.easeOutCirc,
      // Make it more visible on Windows
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      snackStyle: SnackStyle.FLOATING,
    );
  }
}
