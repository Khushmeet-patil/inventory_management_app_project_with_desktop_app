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
        backgroundColor: const Color(0xFFdb8970),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('added_history'.tr),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
                leading: Icon(Icons.add_box, color: Theme.of(context).primaryColor),
                title: Text(history.productName),
                subtitle: Text('Barcode: ${history.barcode}\nUnits: ${history.quantity}'),
                trailing: Text(history.createdAt.toString().substring(0, 16)),
              ),
            );
          },
        ),
      )),
    );
  }
}