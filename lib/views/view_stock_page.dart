import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../controllers/product_controller.dart';
import '../services/sync_service.dart';
import '../utils/image_picker_util.dart';
import '../models/product_model.dart';
import '../views/edit_product_page.dart';
import '../utils/desktop_scroll_behavior.dart';
import '../utils/memory_management_util.dart';

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

  // Optimized filtering with debounce
  final _debouncer = Debouncer(milliseconds: 300);

  void _filterProducts(String query) {
    // Use debouncer to prevent excessive filtering operations
    _debouncer.run(() {
      if (query.isEmpty) {
        _filteredProducts.value = _controller.products;
      } else {
        final lowercaseQuery = query.toLowerCase();
        // Use compute for filtering on a separate isolate if the list is large
        if (_controller.products.length > 100) {
          compute(_filterProductsIsolate, {
            'products': _controller.products,
            'query': lowercaseQuery
          }).then((result) {
            _filteredProducts.value = result;
          });
        } else {
          // For smaller lists, filter directly
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
    });
  }

  // Static method for isolate computation
  static List<Product> _filterProductsIsolate(Map<String, dynamic> params) {
    final List<Product> products = params['products'];
    final String query = params['query'];

    return products.where((product) {
      return product.name.toLowerCase().contains(query) ||
             product.barcode.toLowerCase().contains(query) ||
             (product.color != null && product.color!.toLowerCase().contains(query)) ||
             (product.material != null && product.material!.toLowerCase().contains(query)) ||
             (product.size != null && product.size!.toLowerCase().contains(query)) ||
             (product.unitType != null && product.unitType!.toLowerCase().contains(query));
    }).toList();
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),

                // Product image
                if (product.photo != null && product.photo!.isNotEmpty)
                  Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      margin: EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ImagePickerUtil.getImageWidget(
                          product.photo!,
                          width: 200,
                          height: 200,
                        ),
                      ),
                    ),
                  ),

                // Product name
                Center(
                  child: Text(
                    product.name,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 20),

                // Product details
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailRow('Barcode', product.barcode),
                      _detailRow('Number of Units', '${product.quantity ?? 0}'),
                      _detailRow('Price', '₹${product.pricePerQuantity.toStringAsFixed(2)}'),
                      if (product.rentPrice != null) _detailRow('Rent Price', '₹${product.rentPrice!.toStringAsFixed(2)}'),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                // Additional details
                if (product.unitType != null || product.size != null || product.color != null || product.material != null || product.weight != null)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    padding: EdgeInsets.all(16),
                    margin: EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Additional Details',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        if (product.unitType != null) _detailRow('Unit Type', product.unitType!),
                        if (product.size != null) _detailRow('Size', product.size!),
                        if (product.color != null) _detailRow('Color', product.color!),
                        if (product.material != null) _detailRow('Material', product.material!),
                        if (product.weight != null) _detailRow('Weight', product.weight!),
                      ],
                    ),
                  ),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: Icon(Icons.edit),
                      label: Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFdb8970),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () {
                        print('Edit button clicked in product details bottom sheet');
                        Navigator.of(context).pop();
                        _editProduct(context, product);
                      },
                    ),
                    ElevatedButton.icon(
                      icon: Icon(Icons.close),
                      label: Text('Close'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.black87,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
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
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text('$label:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
          Expanded(child: Text(value, style: TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }

  // Memoized widgets for better performance
  final _appBarTitle = 'view_stock'.tr;
  final _searchHintText = 'search_products'.tr;
  final _noProductsFoundText = 'no_products_found'.tr;
  final _cancelSearchText = 'cancel_search'.tr;
  final _searchText = 'search'.tr;

  // Constant widgets that don't need to be rebuilt
  final _emptyStateIcon = const Icon(Icons.search_off, size: 64, color: Colors.grey);
  final _editIcon = const Icon(Icons.edit, color: Colors.white);
  final _deleteIcon = const Icon(Icons.delete, color: Colors.white);
  final _inventoryIcon = const Icon(Icons.inventory, color: Color(0xFFdb8970));

  @override
  Widget build(BuildContext context) {
    // Optimize memory before building the UI
    MemoryManagementUtil.optimizeBeforeHeavyOperation();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFdb8970),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Obx(() => _isSearching.value
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: _searchHintText,
                hintStyle: const TextStyle(color: Colors.white70),
                border: InputBorder.none,
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: _filterProducts,
            )
          : Text(_appBarTitle, style: const TextStyle(color: Colors.white))
        ),
        actions: [
          // Search button
          Obx(() => IconButton(
            icon: Icon(_isSearching.value ? Icons.close : Icons.search, color: Colors.white),
            onPressed: () {
              _isSearching.value = !_isSearching.value;
              if (!_isSearching.value) {
                _searchController.clear();
                _filterProducts('');
              }
            },
            tooltip: _isSearching.value ? _cancelSearchText : _searchText,
          )),
        ],
      ),
      body: ScrollConfiguration(
        // Use custom scroll behavior for better desktop scrolling
        behavior: DesktopScrollBehavior(),
        child: Obx(() => RefreshIndicator(
          onRefresh: _refreshData,
          child: _filteredProducts.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _emptyStateIcon,
                    const SizedBox(height: 16),
                    Text(
                      _noProductsFoundText,
                      style: const TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _filteredProducts.length,
                // Add cacheExtent for smoother scrolling
                cacheExtent: 200,
                itemBuilder: (context, index) {
                final product = _filteredProducts[index];
                return Dismissible(
                  key: Key(product.id.toString()),
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.only(left: 20),
                    color: Color(0xFFdb8970),
                    child: Icon(Icons.edit, color: Colors.white),
                  ),
                  secondaryBackground: Container(
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.only(right: 20),
                    color: Colors.red,
                    child: Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.endToStart) {
                      // Delete action
                      return await showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Confirm Delete'),
                            content: Text('Are you sure you want to delete ${product.name}?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          );
                        },
                      );
                    } else {
                      // Edit action
                      _editProduct(context, product);
                      return false; // Don't dismiss the item
                    }
                  },
                  onDismissed: (direction) {
                    if (direction == DismissDirection.endToStart) {
                      // Delete the product
                      _controller.deleteProduct(product);
                    }
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: InkWell(
                      onTap: () => _showProductDetails(context, product),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            // Product image
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: product.photo != null && product.photo!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: ImagePickerUtil.getImageWidget(
                                        product.photo!,
                                        width: 70,
                                        height: 70,
                                      ),
                                    )
                                  : Center(child: _inventoryIcon),
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
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Barcode: ${product.barcode}',
                                    style: TextStyle(fontSize: 13, color: Colors.black87),
                                  ),
                                  Text(
                                    'Number of Units: ${product.quantity ?? 0}',
                                    style: TextStyle(fontSize: 13, color: Colors.black87),
                                  ),
                                  if (product.unitType != null) Text(
                                    'Unit Type: ${product.unitType}',
                                    style: TextStyle(fontSize: 13, color: Colors.black87),
                                  ),
                                  if (product.rentPrice != null) Text(
                                    'Rent: ₹${product.rentPrice!.toStringAsFixed(2)}',
                                    style: TextStyle(fontSize: 13, color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      )),
    ),
    );
  }
}

// Debouncer class to prevent excessive filtering operations
class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  run(VoidCallback action) {
    if (_timer != null) {
      _timer!.cancel();
    }
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}