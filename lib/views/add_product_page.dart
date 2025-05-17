import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../controllers/product_controller.dart';
import '../models/product_model.dart';
import '../utils/toast_util.dart';
import '../utils/image_picker_util.dart';

class AddProductPage extends StatefulWidget {
  @override
  _AddProductPageState createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final ProductController _controller = Get.find();
  bool _isExisting = false;
  final _barcodeController = TextEditingController();
  final _nameController = TextEditingController();
  // Removed quantity controller as we're using number of units instead
  final _priceController = TextEditingController();
  final _unitTypeController = TextEditingController();
  final _numberOfUnitsController = TextEditingController();
  final _sizeWidth = TextEditingController();
  final _sizeHeight = TextEditingController();
  final _sizeUnitController = TextEditingController();
  final _colorController = TextEditingController();
  final _materialController = TextEditingController();
  final _weightController = TextEditingController();
  final _rentPriceController = TextEditingController();
  String? _photoPath;

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    // Removed quantity controller disposal
    _priceController.dispose();
    _unitTypeController.dispose();
    _numberOfUnitsController.dispose();
    _sizeWidth.dispose();
    _sizeHeight.dispose();
    _sizeUnitController.dispose();
    _colorController.dispose();
    _materialController.dispose();
    _weightController.dispose();
    _rentPriceController.dispose();
    super.dispose();
  }

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
              if (_isExisting) ...[
                // Number of units field for existing products
                TextField(
                  controller: _numberOfUnitsController,
                  decoration: InputDecoration(labelText: 'number_of_units'.tr),
                  keyboardType: TextInputType.number,
                ),
              ],
              if (!_isExisting) ...[
                // Product image
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 150,
                    margin: EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _photoPath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_photoPath!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey));
                              },
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('tap_to_add_photo'.tr, style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                  ),
                ),

                TextField(controller: _nameController, decoration: InputDecoration(labelText: 'name'.tr)),

                // Unit type dropdown
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(labelText: 'unit_type'.tr),
                  value: _unitTypeController.text.isEmpty ? null : _unitTypeController.text,
                  items: ['pcs', 'set'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _unitTypeController.text = newValue!;
                    });
                  },
                ),

                TextField(
                  controller: _numberOfUnitsController,
                  decoration: InputDecoration(labelText: 'number_of_units'.tr),
                  keyboardType: TextInputType.number,
                ),

                // Size with dimensions and unit
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _sizeWidth,
                        decoration: InputDecoration(labelText: 'width'.tr),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('x', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _sizeHeight,
                        decoration: InputDecoration(labelText: 'height'.tr),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(labelText: 'unit'.tr),
                        value: _sizeUnitController.text.isEmpty ? null : _sizeUnitController.text,
                        items: ['cm', 'inch', 'mm', 'm'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _sizeUnitController.text = newValue!;
                          });
                        },
                      ),
                    ),
                  ],
                ),

                TextField(
                  controller: _colorController,
                  decoration: InputDecoration(labelText: 'color'.tr),
                ),

                TextField(
                  controller: _materialController,
                  decoration: InputDecoration(labelText: 'material'.tr),
                ),

                TextField(
                  controller: _weightController,
                  decoration: InputDecoration(labelText: 'weight'.tr),
                ),

                TextField(
                  controller: _priceController,
                  decoration: InputDecoration(labelText: 'price_per_quantity'.tr),
                  keyboardType: TextInputType.number,
                ),

                TextField(
                  controller: _rentPriceController,
                  decoration: InputDecoration(labelText: 'rent_price'.tr),
                  keyboardType: TextInputType.number,
                ),
              ],

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

  void _pickImage() async {
    final imagePath = await ImagePickerUtil.showImagePickerDialog(context);
    if (imagePath != null) {
      setState(() {
        _photoPath = imagePath;
      });
    }
  }

  void _submit() async {
    if (_barcodeController.text.isEmpty) {
      try {
        ToastUtil.showError('fill_required_fields'.tr);
      } catch (e) {
        print('Error showing toast: $e');
      }
      return;
    }

    if (_isExisting) {
      // Get number of units from the controller, default to 1 if empty
      final units = int.tryParse(_numberOfUnitsController.text) ?? 1;
      await _controller.addExistingStock(_barcodeController.text, units);
    } else {
      if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
        try {
          ToastUtil.showError('fill_all_fields_new_product'.tr);
        } catch (e) {
          print('Error showing toast: $e');
        }
        return;
      }
      // Get number of units from the controller, default to 1 if empty
      final units = int.tryParse(_numberOfUnitsController.text) ?? 1;

      final product = Product(
        id: 0,
        barcode: _barcodeController.text,
        name: _nameController.text,
        quantity: units, // Use the number of units as the quantity
        pricePerQuantity: double.tryParse(_priceController.text) ?? 0.0,
        photo: _photoPath,
        unitType: _unitTypeController.text.isEmpty ? null : _unitTypeController.text,
        size: (_sizeWidth.text.isNotEmpty && _sizeHeight.text.isNotEmpty && _sizeUnitController.text.isNotEmpty)
            ? '${_sizeWidth.text}x${_sizeHeight.text} ${_sizeUnitController.text}'
            : null,
        color: _colorController.text.isEmpty ? null : _colorController.text,
        material: _materialController.text.isEmpty ? null : _materialController.text,
        weight: _weightController.text.isEmpty ? null : _weightController.text,
        rentPrice: double.tryParse(_rentPriceController.text),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _controller.addNewProduct(product);
    }
    Get.back();
  }
}