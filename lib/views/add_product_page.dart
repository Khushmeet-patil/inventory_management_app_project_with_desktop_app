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
      appBar: AppBar(title: Text('Add Product')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              SwitchListTile(
                title: Text('Add to Existing Product'),
                value: _isExisting,
                onChanged: (value) => setState(() => _isExisting = value),
                activeColor: Colors.teal,
              ),
              TextField(
                controller: _barcodeController,
                decoration: InputDecoration(
                  labelText: 'Barcode',
                  suffixIcon: IconButton(
                    icon: Icon(Icons.qr_code_scanner),
                    onPressed: _scanBarcode,
                  ),
                ),
              ),
              if (!_isExisting) ...[
                TextField(controller: _nameController, decoration: InputDecoration(labelText: 'Name')),
                TextField(
                  controller: _priceController,
                  decoration: InputDecoration(labelText: 'Price per Quantity'),
                  keyboardType: TextInputType.number,
                ),
              ],
              TextField(
                controller: _quantityController,
                decoration: InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(Icons.add),
                label: Text(_isExisting ? 'Add Stock' : 'Add New Product'),
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
      Get.snackbar('Error', 'Please fill all required fields');
      return;
    }
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    if (_isExisting) {
      await _controller.addExistingStock(_barcodeController.text, quantity);
    } else {
      if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
        Get.snackbar('Error', 'Please fill all fields for new product');
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