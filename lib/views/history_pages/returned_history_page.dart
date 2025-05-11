import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/product_controller.dart';

class ReturnHistoryPage extends StatelessWidget {
  final ProductController _controller = Get.find();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Return History')),
      body: Obx(() => ListView.builder(
        itemCount: _controller.returnHistory.length,
        itemBuilder: (context, index) {
          final history = _controller.returnHistory[index];
          return Card(
            child: ListTile(
              leading: Icon(Icons.assignment_return, color: Colors.teal),
              title: Text(history.productName),
              subtitle: Text(
                  'Barcode: ${history.barcode}\nQty: ${history.quantity}, By: ${history.givenTo}, Agency: ${history.agency ?? 'N/A'}, Notes: ${history.notes ?? 'N/A'}'),
              trailing: Text(history.createdAt.toString().substring(0, 16)),
            ),
          );
        },
      )),
    );
  }
}