import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../controllers/product_controller.dart';

class RentPage extends StatefulWidget {
  @override
  _RentPageState createState() => _RentPageState();
}

class _RentPageState extends State<RentPage> {
  final ProductController _controller = Get.find();
  final _personController = TextEditingController();
  final _agencyController = TextEditingController();
  List<Map<String, dynamic>> _rentList = [];

  void _addProduct() {
    String barcode = '';
    int quantity = 0;
    int rentalDays = 0;

    Get.dialog(
      AlertDialog(
        title: Text('Add Product to Rent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(labelText: 'Barcode'),
                    onChanged: (value) => barcode = value,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.qr_code_scanner),
                  onPressed: () async {
                    await Get.dialog(
                      Dialog(
                        child: Container(
                          height: 300,
                          child: MobileScanner(
                            onDetect: (capture) {
                              final scannedBarcode = capture.barcodes.first.rawValue;
                              if (scannedBarcode != null) {
                                barcode = scannedBarcode;
                                Get.back();
                              }
                            },
                          ),
                        ),
                      ),
                    );
                    setState(() {});
                  },
                ),
              ],
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
              onChanged: (value) => quantity = int.tryParse(value) ?? 0,
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Rental Days'),
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
                Get.snackbar('Error', 'Please fill all fields correctly');
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  void _confirmRent() async {
    if (_personController.text.isEmpty) {
      Get.snackbar('Error', 'Please enter the person\'s name');
      return;
    }
    if (_rentList.isEmpty) {
      Get.snackbar('Error', 'No products added to rent');
      return;
    }
    for (var item in _rentList) {
      await _controller.rentProduct(
        item['barcode'],
        item['quantity'],
        _personController.text,
        item['rentalDays'],
        agency: _agencyController.text.isNotEmpty ? _agencyController.text : null,
      );
    }
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Rent Products')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _personController,
              decoration: InputDecoration(labelText: 'Person\'s Name', prefixIcon: Icon(Icons.person)),
            ),
            TextField(
              controller: _agencyController,
              decoration: InputDecoration(labelText: 'Agency Name (Optional)', prefixIcon: Icon(Icons.business)),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _rentList.length,
                itemBuilder: (context, index) {
                  final item = _rentList[index];
                  return Card(
                    child: ListTile(
                      title: Text('Barcode: ${item['barcode']}'),
                      subtitle: Text('Qty: ${item['quantity']}, Days: ${item['rentalDays']}'),
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
                  label: Text('Add Product'),
                  onPressed: _addProduct,
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.check),
                  label: Text('Confirm Rent'),
                  onPressed: _confirmRent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}