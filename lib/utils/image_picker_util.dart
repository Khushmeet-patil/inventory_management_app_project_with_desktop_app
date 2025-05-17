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

  // Get image widget from path with caching
  static Widget getImageWidget(String? imagePath, {double width = 100, double height = 100}) {
    if (imagePath == null || imagePath.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey[300],
        child: Icon(Icons.image_not_supported, color: Colors.grey[600]),
      );
    }

    try {
      // Check if the file exists locally
      final file = File(imagePath);
      if (file.existsSync()) {
        // Use cached image provider for better performance
        return Image.file(
          file,
          width: width,
          height: height,
          fit: BoxFit.cover,
          cacheWidth: width.toInt() * 2, // Cache at 2x display size for better quality
          errorBuilder: (context, error, stackTrace) {
            print('Error loading image: $error');
            return Container(
              width: width,
              height: height,
              color: Colors.grey[300],
              child: Icon(Icons.broken_image, color: Colors.grey[600]),
            );
          },
        );
      } else {
        // If file doesn't exist locally, try to load from cache
        return FutureBuilder<File>(
          future: DefaultCacheManager().getSingleFile(imagePath),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done &&
                snapshot.hasData) {
              return Image.file(
                snapshot.data!,
                width: width,
                height: height,
                fit: BoxFit.cover,
                cacheWidth: width.toInt() * 2,
              );
            } else {
              return Container(
                width: width,
                height: height,
                color: Colors.grey[300],
                child: Icon(Icons.hourglass_empty, color: Colors.grey[600]),
              );
            }
          },
        );
      }
    } catch (e) {
      print('Error creating image widget: $e');
      return Container(
        width: width,
        height: height,
        color: Colors.grey[300],
        child: Icon(Icons.error, color: Colors.grey[600]),
      );
    }
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
