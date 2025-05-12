import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/product_controller.dart';
import '../../services/sync_service.dart';

class ReturnHistoryPage extends StatelessWidget {
  final ProductController _controller = Get.find();

  Future<void> _refreshData() async {
    try {
      // Show syncing indicator
      Get.snackbar('Syncing', 'Syncing data with server...', duration: Duration(seconds: 1));

      // Sync with server and reload data
      await _controller.syncAndReload();

      // Show success message
      Get.snackbar('Sync Complete', 'Data has been updated', duration: Duration(seconds: 1));
    } catch (e) {
      Get.snackbar('Sync Error', 'Failed to sync: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('return_history'.tr),
        actions: [
          // Add a manual refresh button in the app bar
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'sync_now'.tr,
          ),
        ],
      ),
      body: Obx(() => RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
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
        ),
      )),
    );
  }
}