import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/product_controller.dart';

class ViewStockPage extends StatelessWidget {
  final ProductController _controller = Get.find();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('View Stock')),
      body: Obx(() => ListView.builder(
        itemCount: _controller.products.length,
        itemBuilder: (context, index) {
          final product = _controller.products[index];
          return Card(
            child: ListTile(
              leading: Icon(Icons.inventory, color: Colors.teal),
              title: Text(product.name),
              subtitle: Text('Qty: ${product.quantity}, Barcode: ${product.barcode}'),
            ),
          );
        },
      )),
    );
  }
}