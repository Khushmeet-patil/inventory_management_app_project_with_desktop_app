import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/product_controller.dart';
import '../../services/sync_service.dart';
import '../../models/history_model.dart';

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
        'notes': firstItem.notes,
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
      body: Obx(() {
        // Group the history items by transaction ID
        final groupedHistory = _groupHistoryByTransaction(_controller.returnHistory);

        return RefreshIndicator(
          onRefresh: _refreshData,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: groupedHistory.length,
            itemBuilder: (context, index) {
              final group = groupedHistory[index];
              final items = group['items'] as List<ProductHistory>;

              // If there's only one item in the group, display it as before
              if (items.length == 1) {
                final history = items.first;
                return Card(
                  child: ListTile(
                    leading: Icon(Icons.assignment_return, color: Colors.teal),
                    title: Text(history.productName),
                    subtitle: Text(
                        'Barcode: ${history.barcode}\nQty: ${history.quantity}, By: ${history.givenTo}, Agency: ${history.agency ?? 'N/A'}, Notes: ${history.notes ?? 'N/A'}'),
                    trailing: Text(history.createdAt.toString().substring(0, 16)),
                  ),
                );
              }
              // If there are multiple items, display them in a single card
              else {
                return Card(
                  child: ExpansionTile(
                    leading: Icon(Icons.assignment_return, color: Colors.teal),
                    title: Text('Multiple Products (${items.length})'),
                    subtitle: Text(
                        'By: ${group['givenTo']}, Agency: ${group['agency'] ?? 'N/A'}, Notes: ${group['notes'] ?? 'N/A'}'),
                    trailing: Text(group['createdAt'].toString().substring(0, 16)),
                    children: items.map((item) => ListTile(
                      contentPadding: EdgeInsets.only(left: 32.0, right: 16.0),
                      title: Text(item.productName),
                      subtitle: Text('Barcode: ${item.barcode}, Qty: ${item.quantity}'),
                    )).toList(),
                  ),
                );
              }
            },
          ),
        );
      }),
    );
  }
}