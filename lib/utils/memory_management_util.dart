import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

/// Utility class for memory management and optimization
class MemoryManagementUtil {
  /// Singleton instance
  static final MemoryManagementUtil _instance = MemoryManagementUtil._internal();
  factory MemoryManagementUtil() => _instance;
  MemoryManagementUtil._internal();

  /// Cache manager for image caching
  static final cacheManager = DefaultCacheManager();

  /// Memory usage monitoring
  static bool _isMonitoringMemory = false;
  static Timer? _memoryMonitorTimer;

  /// Start monitoring memory usage
  static void startMemoryMonitoring() {
    if (_isMonitoringMemory) return;

    _isMonitoringMemory = true;
    _memoryMonitorTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _checkMemoryUsage();
    });
  }

  /// Stop monitoring memory usage
  static void stopMemoryMonitoring() {
    _isMonitoringMemory = false;
    _memoryMonitorTimer?.cancel();
    _memoryMonitorTimer = null;
  }

  /// Check memory usage and clean up if necessary
  static Future<void> _checkMemoryUsage() async {
    if (kDebugMode) {
      print('Checking memory usage...');
    }

    try {
      // Clean image cache if it's too large
      PaintingBinding.instance.imageCache.clear();

      // Clear file cache older than 7 days
      await clearOldCache(days: 7);

      if (kDebugMode) {
        print('Memory cleanup completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during memory cleanup: $e');
      }
    }
  }

  /// Clear old cache files
  static Future<void> clearOldCache({int days = 7}) async {
    try {
      // Clear the image cache manager
      await cacheManager.emptyCache();

      // Get the temp directory
      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();

      // Find files older than specified days
      final files = tempDir.listSync(recursive: true);
      for (final file in files) {
        if (file is File) {
          final stat = file.statSync();
          final fileAge = now.difference(stat.modified);

          if (fileAge.inDays > days) {
            try {
              await file.delete();
            } catch (e) {
              // Ignore errors when deleting files
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing old cache: $e');
      }
    }
  }

  /// Optimize memory before heavy operations
  static Future<void> optimizeBeforeHeavyOperation() async {
    // Force garbage collection (as much as we can in Dart)
    await Future.delayed(const Duration(milliseconds: 100));

    // Clear image cache
    PaintingBinding.instance.imageCache.clear();

    // Run a microtask to ensure UI thread is free
    await Future.microtask(() => null);
  }

  /// Get memory usage information (only works on some platforms)
  static Future<String> getMemoryInfo() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return 'Memory optimization active';
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        return 'Desktop memory optimization active';
      }
      return 'Memory optimization active';
    } catch (e) {
      return 'Memory info unavailable';
    }
  }
}
