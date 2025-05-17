import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/product_controller.dart';
import '../models/product_model.dart';
import '../utils/toast_util.dart';
import '../utils/image_picker_util.dart';
import '../utils/barcode_scanner_util.dart';

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

  void _scanBarcode() async {
    final barcode = await BarcodeScannerUtil.scanBarcode(context);
    if (barcode != null) {
      setState(() {
        _barcodeController.text = barcode;
      });
    }
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
    print('Submit button pressed');
    if (_barcodeController.text.isEmpty) {
      print('Error: Barcode is empty');
      try {
        ToastUtil.showError('fill_required_fields'.tr);
      } catch (e) {
        print('Error showing toast: $e');
        // Fallback message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Barcode cannot be empty')),
        );
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
              Text(_isExisting ? 'adding_stock'.tr : 'adding_product'.tr),
            ],
          ),
        );
      },
    );

    try {
      if (_isExisting) {
        print('Adding existing stock');
        // Get number of units from the controller, default to 1 if empty
        final units = int.tryParse(_numberOfUnitsController.text) ?? 1;
        await _controller.addExistingStock(_barcodeController.text, units);
      } else {
        print('Adding new product');
        if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
          // Close loading dialog
          Navigator.of(context).pop();
          print('Error: Name or price is empty');
          try {
            ToastUtil.showError('fill_all_fields_new_product'.tr);
          } catch (e) {
            print('Error showing toast: $e');
            // Fallback message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Please fill all required fields')),
            );
          }
          return;
        }
      // Get number of units from the controller, default to 1 if empty
      final units = int.tryParse(_numberOfUnitsController.text) ?? 1;

      print('Creating new product object');
      // Parse price values safely
      double? pricePerQuantity;
      try {
        pricePerQuantity = double.tryParse(_priceController.text);
        if (pricePerQuantity == null) {
          print('Warning: Could not parse price: ${_priceController.text}');
          pricePerQuantity = 0.0;
        }
      } catch (e) {
        print('Error parsing price: $e');
        pricePerQuantity = 0.0;
      }

      double? rentPrice;
      try {
        rentPrice = _rentPriceController.text.isNotEmpty ?
            double.tryParse(_rentPriceController.text) : null;
      } catch (e) {
        print('Error parsing rent price: $e');
        rentPrice = null;
      }

      // Format size string
      String? sizeStr;
      if (_sizeWidth.text.isNotEmpty && _sizeHeight.text.isNotEmpty && _sizeUnitController.text.isNotEmpty) {
        sizeStr = '${_sizeWidth.text}x${_sizeHeight.text} ${_sizeUnitController.text}';
      }

      try {
        // Create the product with proper error handling
        final product = Product(
          id: 0,
          barcode: _barcodeController.text,
          name: _nameController.text,
          quantity: units, // Use the number of units as the quantity
          pricePerQuantity: pricePerQuantity,
          photo: _photoPath,
          unitType: _unitTypeController.text.isEmpty ? null : _unitTypeController.text,
          size: sizeStr,
          color: _colorController.text.isEmpty ? null : _colorController.text,
          material: _materialController.text.isEmpty ? null : _materialController.text,
          weight: _weightController.text.isEmpty ? null : _weightController.text,
          rentPrice: rentPrice,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        print('Product object created successfully: ${product.name}, barcode: ${product.barcode}');
        print('Calling addNewProduct with product: ${product.toMap()}');

        // Add the product with a timeout to prevent hanging
        await _controller.addNewProduct(product).timeout(
          Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException('Adding product timed out after 30 seconds');
          },
        );

        print('Product added successfully');
      } catch (productError) {
        print('Error creating or adding product: $productError');
        throw productError; // Re-throw to be caught by the outer try-catch
      }
    }

    // Close loading dialog
    Navigator.of(context).pop();

    // Show success message
    try {
      ToastUtil.showSuccess(_isExisting ? 'Stock added successfully' : 'Product added successfully');
    } catch (toastError) {
      print('Error showing success toast: $toastError');
      // Fallback success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isExisting ? 'Stock added successfully' : 'Product added successfully')),
      );
    }

    // Return to previous screen
    Get.back();
    } catch (e) {
      // Close loading dialog on error
      try {
        Navigator.of(context).pop();
      } catch (navError) {
        print('Error closing dialog: $navError');
      }

      print('Error in submit: $e');

      // Show error message
      try {
        ToastUtil.showError('Error: ${e.toString()}');
      } catch (toastError) {
        print('Error showing error toast: $toastError');
        // Fallback error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
}