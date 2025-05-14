import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/product_controller.dart';
import '../services/sync_service.dart';
import '../utils/image_picker_util.dart';
import '../models/product_model.dart';

class ViewStockPage extends StatelessWidget {
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

  void _showProductDetails(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product image
                if (product.photo != null && product.photo!.isNotEmpty)
                  Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(product.photo!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey));
                          },
                        ),
                      ),
                    ),
                  ),

                // Product details
                _detailRow('Name', product.name),
                _detailRow('Barcode', product.barcode),
                _detailRow('Price', '₹${product.pricePerQuantity.toStringAsFixed(2)}'),
                if (product.rentPrice != null) _detailRow('Rent Price', '₹${product.rentPrice!.toStringAsFixed(2)}'),
                if (product.unitType != null) _detailRow('Unit Type', product.unitType!),
                if (product.size != null) _detailRow('Size', product.size!),
                if (product.color != null) _detailRow('Color', product.color!),
                if (product.material != null) _detailRow('Material', product.material!),
                if (product.weight != null) _detailRow('Weight', product.weight!),

                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: Icon(Icons.edit),
                      label: Text('Edit'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _editProduct(context, product);
                      },
                    ),
                    SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _editProduct(BuildContext context, Product product) {
    Get.toNamed('/edit-product', arguments: product);
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text('$label:', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('view_stock'.tr),
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
          itemCount: _controller.products.length,
          itemBuilder: (context, index) {
            final product = _controller.products[index];
            return Card(
              child: InkWell(
                onTap: () => _showProductDetails(context, product),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      // Product image
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: product.photo != null && product.photo!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(product.photo!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(child: Icon(Icons.inventory, color: Colors.teal));
                                  },
                                ),
                              )
                            : Center(child: Icon(Icons.inventory, color: Colors.teal)),
                      ),
                      SizedBox(width: 16),
                      // Product details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            SizedBox(height: 4),
                            Text('Barcode: ${product.barcode}'),
                            if (product.unitType != null) Text('Unit Type: ${product.unitType}'),
                            if (product.rentPrice != null) Text('Rent: ₹${product.rentPrice!.toStringAsFixed(2)}'),
                          ],
                        ),
                      ),
                      // Edit button
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.teal),
                        onPressed: () => _editProduct(context, product),
                        tooltip: 'edit_product'.tr,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      )),
    );
  }
}