import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Utility class for barcode scanning across different platforms
class BarcodeScannerUtil {
  /// Show a barcode scanner dialog and return the scanned barcode
  static Future<String?> scanBarcode(BuildContext context) async {
    String? result;
    
    // Show a dialog with the barcode scanner
    await Get.dialog(
      Dialog(
        child: Container(
          height: 300,
          width: 300,
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: MobileScanner(
                    onDetect: (capture) {
                      final barcode = capture.barcodes.first.rawValue;
                      if (barcode != null) {
                        result = barcode;
                        Get.back();
                      }
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'scan_barcode'.tr,
                  style: TextStyle(fontSize: 16),
                ),
              ),
              if (Platform.isWindows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: TextButton.icon(
                    icon: Icon(Icons.keyboard),
                    label: Text('manual_entry'.tr),
                    onPressed: () {
                      _showManualBarcodeEntryDialog(context).then((value) {
                        if (value != null && value.isNotEmpty) {
                          result = value;
                          Get.back();
                        }
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    
    return result;
  }
  
  /// Show a dialog for manual barcode entry (useful for Windows if camera doesn't work)
  static Future<String?> _showManualBarcodeEntryDialog(BuildContext context) async {
    final TextEditingController controller = TextEditingController();
    
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('enter_barcode_manually'.tr),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'barcode'.tr,
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text('confirm'.tr),
          ),
        ],
      ),
    );
  }
}
