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

  void _addProduct() {
    String barcode = '';
    int quantity = 0;
    int rentalDays = 0;

    Get.dialog(
      AlertDialog(
        title: Text('add_product_to_rent'.tr),
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
              decoration: InputDecoration(labelText: 'rental_days'.tr),
              keyboardType: TextInputType.number,
              onChanged: (value) => rentalDays = int.tryParse(value) ?? 0,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (barcode.isNotEmpty && quantity > 0 && rentalDays > 0) {
                setState(() {
                  _rentList.add({
                    'barcode': barcode,
                    'quantity': quantity,
                    'rentalDays': rentalDays,
                  });
                });
                Get.back();
              } else {
                try {
                  ToastUtil.showError('fill_all_fields_correctly'.tr);
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