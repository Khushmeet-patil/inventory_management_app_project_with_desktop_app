import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io';
import '../../controllers/product_controller.dart';
import '../../services/sync_service.dart';
import '../../models/history_model.dart';
import 'package:intl/intl.dart';

class RentalHistoryPage extends StatelessWidget {
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

  // Group history items by transaction ID
  List<Map<String, dynamic>> _groupHistoryByTransaction(List<ProductHistory> history) {
    // First, group items by transaction ID
    Map<String?, List<ProductHistory>> groupedItems = {};

    for (var item in history) {
      String key = item.transactionId ?? 'single_${item.id}';
      if (!groupedItems.containsKey(key)) {
        groupedItems[key] = [];
      }
      groupedItems[key]!.add(item);
    }

    // Convert to a list of grouped items
    List<Map<String, dynamic>> result = [];

    groupedItems.forEach((transactionId, items) {
      // Sort items by product name for consistent display
      items.sort((a, b) => a.productName.compareTo(b.productName));

      // Use the first item's data for common fields
      final firstItem = items.first;

      result.add({
        'transactionId': transactionId,
        'items': items,
        'givenTo': firstItem.givenTo,
        'agency': firstItem.agency,
        'rentalDays': firstItem.rentalDays,
        'createdAt': firstItem.createdAt,
      });
    });

    // Sort by creation date, newest first
    result.sort((a, b) => (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFdb8970),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text('rental_history'.tr, style: TextStyle(color: Colors.white)),
      ),
      body: Obx(() {
        // Group the history items by transaction ID
        final groupedHistory = _groupHistoryByTransaction(_controller.rentalHistory);

        return RefreshIndicator(
          onRefresh: _refreshData,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: groupedHistory.length,
            itemBuilder: (context, index) {
              final group = groupedHistory[index];
              final items = group['items'] as List<ProductHistory>;
              final DateTime createdAt = group['createdAt'] as DateTime;
              final String formattedDate = DateFormat('MMM dd, yyyy').format(createdAt);
              final String formattedTime = DateFormat('HH:mm').format(createdAt);

              // Determine if we should show agency or person name
              final String agency = group['agency'] as String? ?? '';
              final String personName = group['givenTo'] as String? ?? '';
              final String displayName = agency.isNotEmpty ? agency : personName;
              final bool hasAgency = agency.isNotEmpty;

              return Card(
                margin: EdgeInsets.symmetric(vertical: 4),
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                child: ExpansionTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Color(0xFFdb8970).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.shopping_cart, color: Color(0xFFdb8970)),
                  ),
                  title: Text(
                    displayName,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 4),
                      // If we're showing agency, also show person name as secondary info
                      if (hasAgency)
                        Text(
                          'Person: $personName',
                          style: TextStyle(fontSize: 12),
                        ),
                      SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                          SizedBox(width: 4),
                          Text(
                            '$formattedDate at $formattedTime',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(0xFFdb8970).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                      style: TextStyle(color: Color(0xFFdb8970), fontWeight: FontWeight.bold),
                    ),
                  ),
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(height: 1, thickness: 1),
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Products',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        ...items.map((item) => _buildProductItem(item)).toList(),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }),
    );
  }

  // Get product photo path by product ID
  String? _getProductPhotoById(int productId) {
    try {
      final product = _controller.products.firstWhere((p) => p.id == productId);
      return product.photo;
    } catch (e) {
      print('Product not found for ID: $productId');
      return null;
    }
  }

  // Build individual product item widget
  Widget _buildProductItem(ProductHistory item) {
    // Get product photo
    final String? photoPath = _getProductPhotoById(item.productId);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Color(0xFFdb8970).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: photoPath != null && photoPath.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(photoPath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(child: Icon(Icons.inventory, color: Color(0xFFdb8970)));
                    },
                  ),
                )
              : Center(child: Icon(Icons.inventory, color: Color(0xFFdb8970))),
          ),
          SizedBox(width: 12),
          // Product details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.productName,
                        style: TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Color(0xFFdb8970),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Qty: ${item.quantity}',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.qr_code, size: 14, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(
                      'Barcode: ${item.barcode}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.timer, size: 14, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(
                      'Duration: ${item.rentalDays} days',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}