import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/product_controller.dart';
import '../widgets/custom_drawer.dart';
import '../services/sync_service.dart';

class HomePage extends StatelessWidget {
  final ProductController _controller = Get.find();
  final SyncService _syncService = SyncService.instance;

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
        title: Text('app_title'.tr),
        centerTitle: true,
        actions: [
          // Add a manual refresh button in the app bar
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'sync_now'.tr,
          ),
        ],
      ),
      drawer: CustomDrawer(),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
            Obx(() => Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory, color: Colors.teal),
                    SizedBox(width: 10),
                    Text(
                      'total_products'.tr + ': ${_controller.products.length}',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            )),
            SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _buildButton(context, 'add_product'.tr, Icons.add, () => Get.toNamed('/add')),
                _buildButton(context, 'rent_product'.tr, Icons.shopping_cart, () => Get.toNamed('/rent')),
                _buildButton(context, 'return_product'.tr, Icons.assignment_return, () => Get.toNamed('/return')),
                _buildButton(context, 'view_stock'.tr, Icons.inventory, () => Get.toNamed('/stock')),
              ],
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.teal),
            SizedBox(height: 10),
            Text(label, style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}