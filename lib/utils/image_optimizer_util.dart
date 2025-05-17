import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class ImageOptimizerUtil {
  /// Compresses an image and saves it to a new file
  /// Returns the path to the compressed image, or null if compression failed
  static Future<String?> compressAndSaveImage(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      if (!imageFile.existsSync()) {
        print('Image file does not exist: $imagePath');
        return null;
      }

      // Get the directory of the original image
      final String dir = path.dirname(imagePath);
      final String ext = path.extension(imagePath);

      // Generate a unique filename for the compressed image
      final String compressedFileName = 'compressed_${const Uuid().v4()}$ext';
      final String compressedPath = path.join(dir, compressedFileName);

      // Compress the image
      final result = await FlutterImageCompress.compressAndGetFile(
        imagePath,
        compressedPath,
        quality: 70, // Adjust quality as needed (0-100)
        minWidth: 1024, // Adjust dimensions as needed
        minHeight: 1024,
      );

      if (result == null) {
        print('Compression failed for: $imagePath');
        return null;
      }

      // Check if compression actually reduced the file size
      final File compressedFile = File(compressedPath);
      final int originalSize = imageFile.lengthSync();
      final int compressedSize = compressedFile.lengthSync();

      if (compressedSize >= originalSize) {
        // If compression didn't reduce size, delete the compressed file and return original
        await compressedFile.delete();
        print('Compression did not reduce file size for: $imagePath');
        return imagePath;
      }

      print('Image compressed: $imagePath -> $compressedPath (${originalSize ~/ 1024}KB -> ${compressedSize ~/ 1024}KB)');
      return compressedPath;
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }
}