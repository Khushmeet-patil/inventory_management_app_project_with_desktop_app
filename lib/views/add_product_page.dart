import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../controllers/product_controller.dart';
import '../models/product_model.dart';

class AddProductPage extends StatefulWidget {
  @override
  _AddProductPageState createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final ProductController _controller = Get.find();
  bool _isExisting = false;
  final _barcodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('add_product'.tr)),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              SwitchListTile(
                title: Text('add_to_existing'.tr),
                value: _isExisting,
                onChanged: (value) => setState(() => _isExisting = value),
                activeColor: Colors.teal,
              ),
              TextField(
                controller: _barcodeController,
                decoration: InputDecoration(
                  labelText: 'barcode'.tr,
                  suffixIcon: IconButton(
                    icon: Icon(Icons.qr_code_scanner),
                    onPressed: _scanBarcode,
                  ),
                ),
              ),
              if (!_isExisting) ...[
                TextField(controller: _nameController, decoration: InputDecoration(labelText: 'name'.tr)),
                TextField(
                  controller: _priceController,
                  decoration: InputDecoration(labelText: 'price_per_quantity'.tr),
                  keyboardType: TextInputType.number,
                ),
              ],
              TextField(
                controller: _quantityController,
                decoration: InputDecoration(labelText: 'quantity'.tr),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(Icons.add),
                label: Text(_isExisting ? 'add_stock'.tr : 'add_new_product'.tr),
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _scanBarcode() {
    Get.dialog(
      Dialog(
        child: Container(
          height: 300,
          child: MobileScanner(
            onDetect: (capture) {
              final barcode = capture.barcodes.first.rawValue;
              if (barcode != null) {
                _barcodeController.text = barcode;
                Get.back();
              }
            },
          ),
        ),
      ),
    );
  }

  void _submit() async {
    if (_barcodeController.text.isEmpty || _quantityController.text.isEmpty) {
      Get.snackbar('error'.tr, 'fill_required_fields'.tr);
      return;
    }
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    if (_isExisting) {
      await _controller.addExistingStock(_barcodeController.text, quantity);
    } else {
      if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
        Get.snackbar('error'.tr, 'fill_all_fields_new_product'.tr);
        return;
      }
      final product = Product(
        id: 0,
        barcode: _barcodeController.text,
        name: _nameController.text,
        quantity: quantity,
        pricePerQuantity: double.tryParse(_priceController.text) ?? 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _controller.addNewProduct(product);
    }
    Get.back();
  }
}