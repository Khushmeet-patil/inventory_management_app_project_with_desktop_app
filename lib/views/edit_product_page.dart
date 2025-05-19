import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
  bool _isLoading = false;
  final ProductController _controller = Get.find();
  final _nameController = TextEditingController();
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
  void initState() {
    super.initState();
    // Initialize controllers with product data
    _nameController.text = widget.product.name;
    _priceController.text = widget.product.pricePerQuantity.toString();
    _unitTypeController.text = widget.product.unitType ?? '';
    _numberOfUnitsController.text = (widget.product.quantity ?? 0).toString();

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
  void dispose() {
    _nameController.dispose();
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
      appBar: AppBar(
        title: Text('edit_product'.tr),
        backgroundColor: const Color(0xFFdb8970),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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

              // Number of units field
              TextField(
                controller: _numberOfUnitsController,
                decoration: InputDecoration(labelText: 'number_of_units'.tr),
                keyboardType: TextInputType.number,
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
                      value: _sizeUnitController.text.isEmpty ? 'cm' : _sizeUnitController.text,
                      items: ['cm', 'mm', 'inch', 'm'].map((String value) {
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
              _isLoading
                ? Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
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
    print('Update product button pressed');
    // Validate required fields
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      print('Validation failed: Name or price is empty');
      ToastUtil.showError('fill_required_fields'.tr);
      return;
    }

    // Show loading indicator
    setState(() {
      _isLoading = true;
    });

    try {
      print('Creating updated product object');
      // Normalize photo path for Windows if needed
      String? normalizedPhotoPath = _photoPath;
      if (normalizedPhotoPath != null && Platform.isWindows) {
        normalizedPhotoPath = normalizedPhotoPath.replaceAll('\\', '/');
        print('Normalized photo path: $normalizedPhotoPath');
      }

      // Create updated product
      final updatedProduct = widget.product.copyWith(
        name: _nameController.text,
        quantity: int.tryParse(_numberOfUnitsController.text) ?? widget.product.quantity,
        pricePerQuantity: double.tryParse(_priceController.text) ?? widget.product.pricePerQuantity,
        photo: normalizedPhotoPath,
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

      print('Calling controller to update product: ID=${updatedProduct.id}, Name=${updatedProduct.name}');
      // Update the product
      await _controller.updateProduct(updatedProduct);
      print('Product updated successfully');

      // Return to previous screen - use Navigator.pop for desktop platforms
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        print('Using Navigator.pop for desktop platform');
        Navigator.of(context).pop();
      } else {
        print('Using Get.back for mobile platform');
        Get.back();
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Product updated successfully')),
      );
    } catch (e) {
      print('Error updating product: $e');
      print('Stack trace: ${StackTrace.current}');
      // Show error in both toast and snackbar for reliability
      ToastUtil.showError('update_failed'.tr + ': $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update product: $e')),
      );
    } finally {
      // Hide loading indicator if we're still on this screen
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
