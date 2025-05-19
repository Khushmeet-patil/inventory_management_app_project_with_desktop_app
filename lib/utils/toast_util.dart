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
      print('Showing success toast: $message');
      // Use GetX snackbar for Windows platform
      if (Platform.isWindows) {
        print('Using Windows toast implementation');
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
      print('Toast error: $e');
      try {
        if (Platform.isIOS || Platform.isWindows) {
          print('Using fallback toast implementation');
          _showFallbackToast(message, Colors.green);
        }
      } catch (fallbackError) {
        print('Fallback toast also failed: $fallbackError');
      }
    }
  }

  static void showError(String message) {
    try {
      print('Showing error toast: $message');
      // Use GetX snackbar for Windows platform
      if (Platform.isWindows) {
        print('Using Windows toast implementation');
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
      print('Toast error: $e');
      try {
        if (Platform.isIOS || Platform.isWindows) {
          print('Using fallback toast implementation');
          _showFallbackToast(message, Colors.red);
        }
      } catch (fallbackError) {
        print('Fallback toast also failed: $fallbackError');
      }
    }
  }

  static void showWarning(String message) {
    try {
      print('Showing warning toast: $message');
      // Use GetX snackbar for Windows platform
      if (Platform.isWindows) {
        print('Using Windows toast implementation');
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
      print('Toast error: $e');
      try {
        if (Platform.isIOS || Platform.isWindows) {
          print('Using fallback toast implementation');
          _showFallbackToast(message, Colors.orange);
        }
      } catch (fallbackError) {
        print('Fallback toast also failed: $fallbackError');
      }
    }
  }

  static void showInfo(String message) {
    try {
      print('Showing info toast: $message');
      // Use GetX snackbar for Windows platform
      if (Platform.isWindows) {
        print('Using Windows toast implementation');
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
      print('Toast error: $e');
      try {
        if (Platform.isIOS || Platform.isWindows) {
          print('Using fallback toast implementation');
          _showFallbackToast(message, Colors.blue);
        }
      } catch (fallbackError) {
        print('Fallback toast also failed: $fallbackError');
      }
    }
  }

  // Fallback method for iOS and Windows if the regular toast fails
  static void _showFallbackToast(String message, Color backgroundColor) {
    // Use a more reliable implementation as fallback
    try {
      // Close any existing snackbars first
      Get.closeAllSnackbars();

      // Show a simple alert dialog that auto-dismisses
      final context = navigatorKey.currentContext;
      if (context != null) {
        // Use a dialog that auto-dismisses after 2 seconds
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) {
            // Auto-dismiss after 2 seconds
            Future.delayed(Duration(seconds: 2), () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            });

            return AlertDialog(
              backgroundColor: backgroundColor,
              content: Text(
                message,
                style: TextStyle(color: Colors.white),
              ),
            );
          },
        );
      } else {
        // If context is not available, try GetX snackbar as last resort
        Get.snackbar(
          'Notification',
          message,
          backgroundColor: backgroundColor,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(16),
          borderRadius: 8,
          isDismissible: true,
        );
      }
    } catch (e) {
      print('Fallback toast also failed: $e');
      // At this point, we can't show any visual feedback
    }
  }

  // Windows-specific toast implementation using GetX
  static void _showWindowsToast(String message, Color backgroundColor) {
    // Use GetX snackbar for Windows with improved visibility
    Get.closeAllSnackbars(); // Close any existing snackbars first

    // Always use blue color for Windows platform as requested
    final Color blueColor = Colors.blue.shade700;

    Get.snackbar(
      'Notification',  // Title
      message,
      backgroundColor: blueColor,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 5),  // Longer duration for better visibility
      margin: const EdgeInsets.all(16),  // Larger margin
      borderRadius: 8,
      isDismissible: true,
      forwardAnimationCurve: Curves.easeOutCirc,
      // Make it more visible on Windows
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      snackStyle: SnackStyle.FLOATING,
      overlayBlur: 0.0,  // No blur
      overlayColor: Colors.black.withOpacity(0.2),  // Slight overlay for better visibility
      barBlur: 0.0,  // No blur on the snackbar itself
      animationDuration: const Duration(milliseconds: 500),  // Faster animation
      icon: Icon(  // Add an icon based on the type of message
        backgroundColor == Colors.green ? Icons.check_circle :
        backgroundColor == Colors.red ? Icons.error :
        backgroundColor == Colors.orange ? Icons.warning :
        Icons.info,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}
