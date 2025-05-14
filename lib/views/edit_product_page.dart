import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../controllers/product_controller.dart';
import '../models/product_model.dart';
import '../utils/toast_util.dart';
import '../utils/image_picker_util.dart';

class EditProductPage extends StatefulWidget {
  final Product product;

  EditProductPage({required this.product});

  @override
  _EditProductPageState createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final ProductController _controller = Get.find();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _unitTypeController = TextEditingController();

  final _sizeWidth = TextEditingController();
  final _sizeHeight = TextEditingController();
  final _sizeUnitController = TextEditingController();
  final _colorController = TextEditingController();
  final _materialController = TextEditingController();
  final _weightController = TextEditingController();
  final _rentPriceController = TextEditingController();
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with product data
    _nameController.text = widget.product.name;
    _priceController.text = widget.product.pricePerQuantity.toString();
    _unitTypeController.text = widget.product.unitType ?? '';

    _colorController.text = widget.product.color ?? '';
    _materialController.text = widget.product.material ?? '';
    _weightController.text = widget.product.weight ?? '';
    _rentPriceController.text = widget.product.rentPrice?.toString() ?? '';
    _photoPath = widget.product.photo;

    // Parse size if available (format: "widthxheight unit")
    if (widget.product.size != null) {
      final sizeParts = widget.product.size!.split(' ');
      if (sizeParts.length >= 2) {
        _sizeUnitController.text = sizeParts[1];
        final dimensions = sizeParts[0].split('x');
        if (dimensions.length == 2) {
          _sizeWidth.text = dimensions[0];
          _sizeHeight.text = dimensions[1];
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('edit_product'.tr)),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Display barcode (non-editable)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Text('Barcode: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(widget.product.barcode),
                  ],
                ),
              ),

              // Product image
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 150,
                  height: 150,
                  margin: EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _photoPath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_photoPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                              );
                            },
                          ),
                        )
                      : Center(
                          child: Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                        ),
                ),
              ),

              // Product details form
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'name'.tr),
              ),

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



              // Size fields
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
                  Text('x'),
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
                      items: ['cm', 'mm', 'in', 'm'].map((String value) {
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

              SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(Icons.save),
                label: Text('save_changes'.tr),
                onPressed: _updateProduct,
              ),
            ],
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

  void _updateProduct() async {
    // Validate required fields
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      ToastUtil.showError('fill_required_fields'.tr);
      return;
    }

    try {
      // Create updated product
      final updatedProduct = widget.product.copyWith(
        name: _nameController.text,
        pricePerQuantity: double.tryParse(_priceController.text) ?? widget.product.pricePerQuantity,
        photo: _photoPath,
        unitType: _unitTypeController.text.isEmpty ? null : _unitTypeController.text,

        size: (_sizeWidth.text.isNotEmpty && _sizeHeight.text.isNotEmpty && _sizeUnitController.text.isNotEmpty)
            ? '${_sizeWidth.text}x${_sizeHeight.text} ${_sizeUnitController.text}'
            : null,
        color: _colorController.text.isEmpty ? null : _colorController.text,
        material: _materialController.text.isEmpty ? null : _materialController.text,
        weight: _weightController.text.isEmpty ? null : _weightController.text,
        rentPrice: double.tryParse(_rentPriceController.text),
        updatedAt: DateTime.now(),
      );

      // Update the product
      await _controller.updateProduct(updatedProduct);

      // Return to previous screen
      Get.back();
    } catch (e) {
      ToastUtil.showError('update_failed'.tr + ': $e');
    }
  }
}
