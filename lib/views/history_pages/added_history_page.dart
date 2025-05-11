import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/product_controller.dart';

class AddedProductHistoryPage extends StatelessWidget {
  final ProductController _controller = Get.find();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Added Product History')),
      body: Obx(() => ListView.builder(
        itemCount: _controller.addedProductHistory.length,
        itemBuilder: (context, index) {
          final history = _controller.addedProductHistory[index];
          return Card(
            child: ListTile(
              leading: Icon(Icons.add_box, color: Colors.teal),
              title: Text(history.productName),
              subtitle: Text('Barcode: ${history.barcode}\nQty: ${history.quantity}'),
              trailing: Text(history.createdAt.toString().substring(0, 16)),
            ),
          );
        },
      )),
    );
  }
}