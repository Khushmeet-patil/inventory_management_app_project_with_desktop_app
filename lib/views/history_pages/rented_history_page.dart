import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/product_controller.dart';

class RentalHistoryPage extends StatelessWidget {
  final ProductController _controller = Get.find();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Rental History')),
      body: Obx(() => ListView.builder(
        itemCount: _controller.rentalHistory.length,
        itemBuilder: (context, index) {
          final history = _controller.rentalHistory[index];
          return Card(
            child: ListTile(
              leading: Icon(Icons.shopping_cart, color: Colors.teal),
              title: Text(history.productName),
              subtitle: Text(
                  'Barcode: ${history.barcode}\nQty: ${history.quantity}, To: ${history.givenTo}, Agency: ${history.agency ?? 'N/A'}, Days: ${history.rentalDays}'),
              trailing: Text(history.createdAt.toString().substring(0, 16)),
            ),
          );
        },
      )),
    );
  }
}