import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/product_controller.dart';
import '../services/sync_service.dart';
import '../utils/image_picker_util.dart';
import '../models/product_model.dart';
import '../views/edit_product_page.dart';

class ViewStockPage extends StatefulWidget {
  @override
  _ViewStockPageState createState() => _ViewStockPageState();
}

class _ViewStockPageState extends State<ViewStockPage> {
  final ProductController _controller = Get.find();
  final TextEditingController _searchController = TextEditingController();
  final RxList<Product> _filteredProducts = <Product>[].obs;
  final RxBool _isSearching = false.obs;

  @override
  void initState() {
    super.initState();
    // Initialize filtered products with all products
    _filteredProducts.value = _controller.products;

    // Listen to changes in the product list
    ever(_controller.products, (_) {
      _filterProducts(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterProducts(String query) {
    if (query.isEmpty) {
      _filteredProducts.value = _controller.products;
    } else {
      final lowercaseQuery = query.toLowerCase();
      _filteredProducts.value = _controller.products.where((product) {
        return product.name.toLowerCase().contains(lowercaseQuery) ||
               product.barcode.toLowerCase().contains(lowercaseQuery) ||
               (product.color != null && product.color!.toLowerCase().contains(lowercaseQuery)) ||
               (product.material != null && product.material!.toLowerCase().contains(lowercaseQuery)) ||
               (product.size != null && product.size!.toLowerCase().contains(lowercaseQuery)) ||
               (product.unitType != null && product.unitType!.toLowerCase().contains(lowercaseQuery));
      }).toList();
    }
  }


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
                _detailRow('Number of Units', '${product.quantity ?? 0}'),
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
                        print('Edit button clicked in product details dialog');
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
    print('Editing product: ID=${product.id}, Name=${product.name}');
    try {
      // For desktop platforms, use a more reliable navigation approach
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        print('Using desktop-specific navigation');
        // First create the page with the product
        final page = EditProductPage(product: product);
        // Then navigate to it using Navigator instead of GetX
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => page),
        );
      } else {
        // For mobile, continue using GetX routing
        print('Using GetX navigation for mobile');
        Get.toNamed('/edit-product', arguments: product);
      }
    } catch (e) {
      print('Error navigating to edit product page: $e');
      // Fallback to direct navigation if GetX fails
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => EditProductPage(product: product)),
      );
    }
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
        title: Obx(() => _isSearching.value
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'search_products'.tr,
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
              ),
              style: TextStyle(color: Colors.white),
              onChanged: _filterProducts,
            )
          : Text('view_stock'.tr)
        ),
        actions: [
          // Search button
          Obx(() => IconButton(
            icon: Icon(_isSearching.value ? Icons.close : Icons.search),
            onPressed: () {
              _isSearching.value = !_isSearching.value;
              if (!_isSearching.value) {
                _searchController.clear();
                _filterProducts('');
              }
            },
            tooltip: _isSearching.value ? 'cancel_search'.tr : 'search'.tr,
          )),
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
        child: _filteredProducts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'no_products_found'.tr,
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _filteredProducts.length,
              itemBuilder: (context, index) {
                final product = _filteredProducts[index];
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
                                Text('Number of Units: ${product.quantity ?? 0}'),
                                if (product.unitType != null) Text('Unit Type: ${product.unitType}'),
                                if (product.rentPrice != null) Text('Rent: ₹${product.rentPrice!.toStringAsFixed(2)}'),
                              ],
                            ),
                          ),
                          // Edit button
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.teal),
                            onPressed: () {
                              print('Edit icon clicked in product list');
                              _editProduct(context, product);
                            },
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