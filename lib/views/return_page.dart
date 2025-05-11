import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../controllers/product_controller.dart';

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
        title: Text('Add Product to Return'),
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
              decoration: InputDecoration(labelText: 'Notes (Optional)'),
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
                Get.snackbar('Error', 'Please fill barcode and quantity');
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  void _confirmReturn() async {
    if (_personController.text.isEmpty) {
      Get.snackbar('Error', 'Please enter the person\'s name');
      return;
    }
    if (_returnList.isEmpty) {
      Get.snackbar('Error', 'No products added to return');
      return;
    }
    for (var item in _returnList) {
      await _controller.returnProduct(
        item['barcode'],
        item['quantity'],
        _personController.text,
        agency: _agencyController.text.isNotEmpty ? _agencyController.text : null,
        notes: item['notes'].isNotEmpty ? item['notes'] : null,
      );
    }
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Return Products')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _personController,
              decoration: InputDecoration(labelText: 'Returned By', prefixIcon: Icon(Icons.person)),
            ),
            TextField(
              controller: _agencyController,
              decoration: InputDecoration(labelText: 'Agency Name (Optional)', prefixIcon: Icon(Icons.business)),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _returnList.length,
                itemBuilder: (context, index) {
                  final item = _returnList[index];
                  return Card(
                    child: ListTile(
                      title: Text('Barcode: ${item['barcode']}'),
                      subtitle: Text('Qty: ${item['quantity']}, Notes: ${item['notes'].isEmpty ? 'N/A' : item['notes']}'),
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
                  label: Text('Add Product'),
                  onPressed: _addProduct,
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.check),
                  label: Text('Confirm Return'),
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