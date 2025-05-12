import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../controllers/product_controller.dart';
import '../utils/toast_util.dart';

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
        title: Text('add_product_to_return'.tr),
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
              decoration: InputDecoration(labelText: 'quantity'.tr),
              keyboardType: TextInputType.number,
              onChanged: (value) => quantity = int.tryParse(value) ?? 0,
            ),
            TextField(
              decoration: InputDecoration(labelText: 'notes_optional'.tr),
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
                ToastUtil.showError('fill_barcode_quantity'.tr);
              }
            },
            child: Text('add'.tr),
          ),
        ],
      ),
    );
  }

  void _confirmReturn() async {
    if (_personController.text.isEmpty) {
      ToastUtil.showError('enter_person_name'.tr);
      return;
    }
    if (_returnList.isEmpty) {
      ToastUtil.showError('no_products_to_return'.tr);
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
      appBar: AppBar(title: Text('return_products'.tr)),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _personController,
              decoration: InputDecoration(labelText: 'returned_by'.tr, prefixIcon: Icon(Icons.person)),
            ),
            TextField(
              controller: _agencyController,
              decoration: InputDecoration(labelText: 'agency_name_optional'.tr, prefixIcon: Icon(Icons.business)),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _returnList.length,
                itemBuilder: (context, index) {
                  final item = _returnList[index];
                  return Card(
                    child: ListTile(
                      title: Text('barcode'.tr + ': ${item['barcode']}'),
                      subtitle: Text('qty'.tr + ': ${item['quantity']}, ' + 'notes'.tr + ': ${item['notes'].isEmpty ? 'n_a'.tr : item['notes']}'),
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
                  label: Text('add_product'.tr),
                  onPressed: _addProduct,
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.check),
                  label: Text('confirm_return'.tr),
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