import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';

class ToastUtil {
  // Global navigator key to access context from anywhere
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static void showSuccess(String message) {
    try {
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
      // Fallback for iOS if toast fails
      if (Platform.isIOS) {
        _showFallbackToast(message, Colors.green);
      }
      print('Toast error: $e');
    }
  }

  static void showError(String message) {
    try {
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
      // Fallback for iOS if toast fails
      if (Platform.isIOS) {
        _showFallbackToast(message, Colors.red);
      }
      print('Toast error: $e');
    }
  }

  static void showWarning(String message) {
    try {
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
      // Fallback for iOS if toast fails
      if (Platform.isIOS) {
        _showFallbackToast(message, Colors.orange);
      }
      print('Toast error: $e');
    }
  }

  static void showInfo(String message) {
    try {
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
      // Fallback for iOS if toast fails
      if (Platform.isIOS) {
        _showFallbackToast(message, Colors.blue);
      }
      print('Toast error: $e');
    }
  }

  // Fallback method for iOS if the regular toast fails
  static void _showFallbackToast(String message, Color backgroundColor) {
    // Use GetX snackbar as a fallback for iOS
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
}
