import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:file_selector/file_selector.dart';
import 'image_optimizer_util.dart';

class ImagePickerUtil {
  static final ImagePicker _picker = ImagePicker();

  // Pick an image from camera
  static Future<String?> pickImageFromCamera() async {
    try {
      XFile? image;

      // Use different approach for Windows
      if (Platform.isWindows) {
        try {
          // First try to use the camera_windows plugin via image_picker
          image = await _picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 80,
          );

          // If that fails, fall back to file selector
          if (image == null) {
            print('Windows camera via image_picker failed, using file selector as fallback');
            final typeGroup = XTypeGroup(label: 'images', extensions: ['jpg', 'jpeg', 'png']);
            image = await openFile(acceptedTypeGroups: [typeGroup]);
          }
        } catch (e) {
          print('Windows camera error: $e');
          // Fallback to gallery picker
          return await pickImageFromGallery();
        }
      } else {
        // For other platforms, use the image_picker
        image = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80, // Reduce image quality to save space
        );
      }

      if (image != null) {
        return await _saveImageToAppDirectory(image);
      }
      return null;
    } catch (e) {
      print('Error picking image from camera: $e');
      return null;
    }
  }

  // Pick an image from gallery
  static Future<String?> pickImageFromGallery() async {
    try {
      XFile? image;

      // Use different approach for Windows
      if (Platform.isWindows) {
        // On Windows, use file_selector
        final typeGroup = XTypeGroup(label: 'images', extensions: ['jpg', 'jpeg', 'png']);
        image = await openFile(acceptedTypeGroups: [typeGroup]);
      } else {
        // For other platforms, use the image_picker
        image = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80, // Reduce image quality to save space
        );
      }

      if (image != null) {
        return await _saveImageToAppDirectory(image);
      }
      return null;
    } catch (e) {
      print('Error picking image from gallery: $e');
      return null;
    }
  }

  // Save image to app directory and return the path
  static Future<String> _saveImageToAppDirectory(XFile image) async {
    try {
      // Get app documents directory
      final Directory appDir = await getApplicationDocumentsDirectory();

      // Create a directory for product images if it doesn't exist
      final String productImagesDir = path.join(appDir.path, 'product_images');
      await Directory(productImagesDir).create(recursive: true);

      // Generate a unique filename
      final String fileName = '${const Uuid().v4()}${path.extension(image.path)}';
      final String savedPath = path.join(productImagesDir, fileName);

      // Copy the image to the app directory
      final File savedImage = File(savedPath);
      await savedImage.writeAsBytes(await image.readAsBytes());

      print('Image saved to: $savedPath');

      // Optimize the image
      final String? optimizedPath = await ImageOptimizerUtil.compressAndSaveImage(savedPath);
      if (optimizedPath != null) {
        print('Image optimized: $optimizedPath');
        return optimizedPath;
      }

      return savedPath;
    } catch (e) {
      print('Error saving image: $e');
      // Return the original path if saving fails
      return image.path;
    }
  }

  // Cached image instances to avoid rebuilding
  static final Map<String, Widget> _cachedImages = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheDuration = Duration(minutes: 10);

  // Fallback widget for when image loading fails
  static Widget _getFallbackWidget(double width, double height, {IconData icon = Icons.image_not_supported}) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: Icon(icon, color: Colors.grey[600]),
    );
  }

  // Get image widget from path with caching
  static Widget getImageWidget(String? imagePath, {double width = 100, double height = 100}) {
    // Return fallback widget if path is null or empty
    if (imagePath == null || imagePath.isEmpty) {
      return _getFallbackWidget(width, height);
    }

    // Create a cache key based on path and dimensions
    final cacheKey = '${imagePath}_${width.toInt()}_${height.toInt()}';

    // Check if we have a valid cached image
    final now = DateTime.now();
    if (_cachedImages.containsKey(cacheKey) &&
        _cacheTimestamps.containsKey(cacheKey) &&
        now.difference(_cacheTimestamps[cacheKey]!) < _cacheDuration) {
      return _cachedImages[cacheKey]!;
    }

    try {
      // Check if the file exists locally
      final file = File(imagePath);
      Widget imageWidget;

      if (file.existsSync()) {
        // Check file size to avoid loading corrupted images
        final fileSize = file.lengthSync();
        if (fileSize <= 0) {
          return _getFallbackWidget(width, height, icon: Icons.broken_image);
        }

        // Use memory efficient image loading
        imageWidget = Image.file(
          file,
          width: width,
          height: height,
          fit: BoxFit.cover,
          cacheWidth: width.toInt() * 2, // Cache at 2x display size for better quality
          gaplessPlayback: true, // Prevent flickering during image loading
          filterQuality: FilterQuality.medium, // Balance between quality and performance
          errorBuilder: (context, error, stackTrace) {
            print('Error loading image: $error');
            return _getFallbackWidget(width, height, icon: Icons.broken_image);
          },
        );

        // Cache the image widget
        _cachedImages[cacheKey] = imageWidget;
        _cacheTimestamps[cacheKey] = now;

        return imageWidget;
      } else {
        // If file doesn't exist locally, return fallback immediately
        // This is more efficient than trying to load from cache which might fail
        return _getFallbackWidget(width, height, icon: Icons.image_not_supported);
      }
    } catch (e) {
      print('Error creating image widget: $e');
      return _getFallbackWidget(width, height, icon: Icons.error);
    }
  }

  // Clear the image cache
  static void clearImageCache() {
    _cachedImages.clear();
    _cacheTimestamps.clear();
  }

  // Show image picker dialog
  static Future<String?> showImagePickerDialog(BuildContext context) async {
    return await showDialog<String?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Image Source'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                GestureDetector(
                  child: ListTile(
                    leading: Icon(Icons.camera_alt),
                    title: Text(Platform.isWindows ? 'Camera/File' : 'Camera'),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop(await pickImageFromCamera());
                  },
                ),
                GestureDetector(
                  child: ListTile(
                    leading: Icon(Icons.photo_library),
                    title: Text('Gallery'),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop(await pickImageFromGallery());
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
