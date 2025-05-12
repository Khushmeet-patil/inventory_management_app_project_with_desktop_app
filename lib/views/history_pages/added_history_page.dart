import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/product_controller.dart';
import '../../services/sync_service.dart';

class AddedProductHistoryPage extends StatelessWidget {
  final ProductController _controller = Get.find();

  Future<void> _refreshData() async {
    try {
      // Show syncing indicator
      Get.snackbar('syncing'.tr, 'syncing_message'.tr, duration: Duration(seconds: 1));

      // Sync with server and reload data
      await _controller.syncAndReload();

      // Show success message
      Get.snackbar('sync_complete'.tr, 'data_updated'.tr, duration: Duration(seconds: 1));
    } catch (e) {
      Get.snackbar('sync_error'.tr, 'sync_failed'.tr + ': $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('added_history'.tr),
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
        ),
      )),
    );
  }
}