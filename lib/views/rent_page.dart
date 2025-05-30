import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../controllers/product_controller.dart';
import '../utils/toast_util.dart';
import '../utils/barcode_scanner_util.dart';

class RentPage extends StatefulWidget {
  @override
  _RentPageState createState() => _RentPageState();
}

class _RentPageState extends State<RentPage> {
  final ProductController _controller = Get.find();
  final _personController = TextEditingController();
  final _agencyController = TextEditingController();
  List<Map<String, dynamic>> _rentList = [];
  bool _isLoading = false;

  void _addProduct() async {
    // Check if person name is entered
    if (_personController.text.isEmpty) {
      ToastUtil.showError('enter_person_name_first'.tr);
      return;
    }

    // Variables for barcode entry
    String? barcode;
    final TextEditingController barcodeController = TextEditingController();

    // Show bottom sheet for barcode entry
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'add_product'.tr,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),

              // Barcode field with scan button
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'barcode'.tr,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => barcode = value,
                      autofocus: true,
                      controller: barcodeController,
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: Icon(Icons.qr_code_scanner),
                    label: Text('scan'.tr),
                    onPressed: () async {
                      // Scan barcode
                      final scannedBarcode = await BarcodeScannerUtil.scanBarcode(context);
                      if (scannedBarcode != null) {
                        // Update the text field with scanned barcode
                        setSheetState(() {
                          barcodeController.text = scannedBarcode;
                          barcode = scannedBarcode;
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFdb8970),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('cancel'.tr),
                  ),
                  SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Get the final value from the controller
                      final finalBarcode = barcodeController.text.isNotEmpty ?
                          barcodeController.text : barcode;

                      if (finalBarcode != null && finalBarcode.isNotEmpty) {
                        Navigator.pop(context, finalBarcode);
                      } else {
                        ToastUtil.showError('enter_barcode'.tr);
                      }
                    },
                    child: Text('next'.tr),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFdb8970),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ).then((result) async {
      // Handle result from first bottom sheet
      if (result == null) {
        return; // User cancelled
      }

      barcode = result; // User entered or scanned barcode

      // Variables for quantity and rental days
      int quantity = 0;
      int rentalDays = 0;
      final quantityController = TextEditingController();
      final rentalDaysController = TextEditingController();

      // Show second bottom sheet for quantity and rental days
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'product_details'.tr,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),

              // Display the barcode
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text('barcode'.tr + ': ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(barcode!)),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Quantity field
              TextField(
                controller: quantityController,
                decoration: InputDecoration(
                  labelText: 'number_of_units'.tr,
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
                onChanged: (value) => quantity = int.tryParse(value) ?? 0,
              ),

              SizedBox(height: 16),

              // Rental days field
              TextField(
                controller: rentalDaysController,
                decoration: InputDecoration(
                  labelText: 'rental_days'.tr,
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => rentalDays = int.tryParse(value) ?? 0,
              ),

              SizedBox(height: 24),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('cancel'.tr),
                  ),
                  SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (quantity > 0 && rentalDays > 0) {
                        setState(() {
                          _rentList.add({
                            'barcode': barcode!,
                            'quantity': quantity,
                            'rentalDays': rentalDays,
                          });
                        });
                        Navigator.pop(context);
                      } else {
                        try {
                          ToastUtil.showError('fill_all_fields_correctly'.tr);
                        } catch (e) {
                          print('Error showing toast: $e');
                        }
                      }
                    },
                    child: Text('add'.tr),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFdb8970),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      );
    });
  }

  void _confirmRent() async {
    print('Confirm rent button pressed');
    if (_personController.text.isEmpty) {
      print('Error: Person name is empty');
      try {
        ToastUtil.showError('enter_person_name'.tr);
      } catch (e) {
        print('Error showing toast: $e');
      }
      return;
    }
    if (_rentList.isEmpty) {
      print('Error: No products to rent');
      try {
        ToastUtil.showError('no_products_to_rent'.tr);
      } catch (e) {
        print('Error showing toast: $e');
      }
      return;
    }

    // Show loading indicator
    setState(() {
      _isLoading = true;
    });

    try {
      print('Calling batch rent products method');
      // Use the optimized batch rent method for better performance
      await _controller.batchRentProducts(
        _rentList,
        _personController.text,
        agency: _agencyController.text.isNotEmpty ? _agencyController.text : null,
      );
      print('Batch rent completed successfully');

      // Return to previous screen
      Get.back();
    } catch (e) {
      print('Error in batch rent: $e');
      ToastUtil.showError('Error: ${e.toString()}');

      // Hide loading indicator if we're still on this screen
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('rent_products'.tr),
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
            TextField(
              controller: _personController,
              decoration: InputDecoration(labelText: 'person_name'.tr, prefixIcon: Icon(Icons.person)),
            ),
            TextField(
              controller: _agencyController,
              decoration: InputDecoration(labelText: 'agency_name_optional'.tr, prefixIcon: Icon(Icons.business)),
            ),
            SizedBox(height: 20),
            Container(
              height: 300,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _rentList.length,
                itemBuilder: (context, index) {
                  final item = _rentList[index];
                  return Card(
                    child: ListTile(
                      title: Text('barcode'.tr + ': ${item['barcode']}'),
                      subtitle: Text('units'.tr + ': ${item['quantity']}, ' + 'days'.tr + ': ${item['rentalDays']}'),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => setState(() => _rentList.removeAt(index)),
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
                  label: Text('confirm_rent'.tr),
                  onPressed: _isLoading ? null : _confirmRent,
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}