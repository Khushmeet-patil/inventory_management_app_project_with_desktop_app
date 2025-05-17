import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../controllers/product_controller.dart';
import '../utils/toast_util.dart';
import '../utils/barcode_scanner_util.dart';

class ReturnPage extends StatefulWidget {
  @override
  _ReturnPageState createState() => _ReturnPageState();
}

class _ReturnPageState extends State<ReturnPage> {
  final ProductController _controller = Get.find();
  final _personController = TextEditingController();
  final _agencyController = TextEditingController();
  List<Map<String, dynamic>> _returnList = [];

  void _addProduct() {
    String barcode = '';
    int quantity = 0;
    String notes = '';

    Get.dialog(
      AlertDialog(
        title: Text('add_product_to_return'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(labelText: 'barcode'.tr),
                    onChanged: (value) => barcode = value,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.qr_code_scanner),
                  onPressed: () async {
                    final scannedBarcode = await BarcodeScannerUtil.scanBarcode(context);
                    if (scannedBarcode != null) {
                      barcode = scannedBarcode;
                      setState(() {});
                    }
                  },
                ),
              ],
            ),
            TextField(
              decoration: InputDecoration(labelText: 'number_of_units'.tr),
              keyboardType: TextInputType.number,
              onChanged: (value) => quantity = int.tryParse(value) ?? 0,
            ),
            TextField(
              decoration: InputDecoration(labelText: 'notes_optional'.tr),
              onChanged: (value) => notes = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (barcode.isNotEmpty && quantity > 0) {
                setState(() {
                  _returnList.add({
                    'barcode': barcode,
                    'quantity': quantity,
                    'notes': notes,
                  });
                });
                Get.back();
              } else {
                try {
                  ToastUtil.showError('fill_barcode_units'.tr);
                } catch (e) {
                  print('Error showing toast: $e');
                }
              }
            },
            child: Text('add'.tr),
          ),
        ],
      ),
    );
  }

  void _confirmReturn() async {
    print('Confirm return button pressed');
    if (_personController.text.isEmpty) {
      print('Error: Person name is empty');
      try {
        ToastUtil.showError('enter_person_name'.tr);
      } catch (e) {
        print('Error showing toast: $e');
      }
      return;
    }
    if (_returnList.isEmpty) {
      print('Error: No products to return');
      try {
        ToastUtil.showError('no_products_to_return'.tr);
      } catch (e) {
        print('Error showing toast: $e');
      }
      return;
    }

    // Show loading indicator
    final loadingDialog = showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('processing_return'.tr),
            ],
          ),
        );
      },
    );

    try {
      print('Calling batch return products method');
      // Use the optimized batch return method for better performance
      await _controller.batchReturnProducts(
        _returnList,
        _personController.text,
        agency: _agencyController.text.isNotEmpty ? _agencyController.text : null,
      );
      print('Batch return completed successfully');

      // Close loading dialog
      Navigator.of(context).pop();

      // Return to previous screen
      Get.back();
    } catch (e) {
      // Close loading dialog on error
      Navigator.of(context).pop();
      print('Error in batch return: $e');
      ToastUtil.showError('Error: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('return_products'.tr)),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _personController,
              decoration: InputDecoration(labelText: 'returned_by'.tr, prefixIcon: Icon(Icons.person)),
            ),
            TextField(
              controller: _agencyController,
              decoration: InputDecoration(labelText: 'agency_name_optional'.tr, prefixIcon: Icon(Icons.business)),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _returnList.length,
                itemBuilder: (context, index) {
                  final item = _returnList[index];
                  return Card(
                    child: ListTile(
                      title: Text('barcode'.tr + ': ${item['barcode']}'),
                      subtitle: Text('units'.tr + ': ${item['quantity']}, ' + 'notes'.tr + ': ${item['notes'].isEmpty ? 'n_a'.tr : item['notes']}'),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => setState(() => _returnList.removeAt(index)),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.add),
                  label: Text('add_product'.tr),
                  onPressed: _addProduct,
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.check),
                  label: Text('confirm_return'.tr),
                  onPressed: _confirmReturn,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}