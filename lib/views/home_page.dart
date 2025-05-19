import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../controllers/product_controller.dart';
import '../widgets/custom_drawer.dart';
import '../services/sync_service.dart';
import '../models/transaction_model.dart';
import '../models/product_model.dart';
import '../models/history_model.dart';
import '../utils/image_picker_util.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ProductController _controller = Get.find();
  final SyncService _syncService = SyncService.instance;

  // Selected filter for transactions
  String _selectedFilter = 'All';

  // Products counts
  RxInt _availableProductsCount = 0.obs;

  // Rental statistics
  RxInt _rentedTotalQuantity = 0.obs;
  RxInt _rentedUniqueProducts = 0.obs;
  RxInt _rentedUniquePersons = 0.obs;

  // Return statistics
  RxInt _returnedTotalQuantity = 0.obs;
  RxInt _returnedUniqueProducts = 0.obs;
  RxInt _returnedUniquePersons = 0.obs;

  @override
  void initState() {
    super.initState();

    // Force reload data from database to ensure we have the latest data
    _controller.loadData().then((_) {
      _calculateTotalStocks();
      print('Data loaded from database and statistics calculated');
    });

    // Listen to changes in the product list
    ever(_controller.products, (_) {
      _calculateTotalStocks();
    });

    // Also listen to changes in rental and return history
    ever(_controller.rentalHistory, (_) {
      _calculateTotalStocks();
    });

    ever(_controller.returnHistory, (_) {
      _calculateTotalStocks();
    });
  }

  // Calculate total available products and detailed transaction statistics
  void _calculateTotalStocks() {
    // Count only products with quantity > 0
    int availableProductsCount = 0;
    for (var product in _controller.products) {
      if ((product.quantity ?? 0) > 0) {
        availableProductsCount++;
      }
    }
    _availableProductsCount.value = availableProductsCount;

    // Calculate rental statistics
    int totalRentalQuantity = 0;
    Set<int> uniqueRentedProducts = {};
    Set<String> uniqueRentalPersons = {};

    for (var history in _controller.rentalHistory) {
      totalRentalQuantity += history.quantity;
      uniqueRentedProducts.add(history.productId);

      // Add person or agency to unique persons set
      if (history.agency != null && history.agency!.isNotEmpty) {
        uniqueRentalPersons.add(history.agency!);
      } else if (history.givenTo != null && history.givenTo!.isNotEmpty) {
        uniqueRentalPersons.add(history.givenTo!);
      }
    }

    _rentedTotalQuantity.value = totalRentalQuantity;
    _rentedUniqueProducts.value = uniqueRentedProducts.length;
    _rentedUniquePersons.value = uniqueRentalPersons.length;

    // Calculate return statistics
    int totalReturnQuantity = 0;
    Set<int> uniqueReturnedProducts = {};
    Set<String> uniqueReturnPersons = {};

    for (var history in _controller.returnHistory) {
      totalReturnQuantity += history.quantity;
      uniqueReturnedProducts.add(history.productId);

      // Add person or agency to unique persons set
      if (history.agency != null && history.agency!.isNotEmpty) {
        uniqueReturnPersons.add(history.agency!);
      } else if (history.givenTo != null && history.givenTo!.isNotEmpty) {
        uniqueReturnPersons.add(history.givenTo!);
      }
    }

    _returnedTotalQuantity.value = totalReturnQuantity;
    _returnedUniqueProducts.value = uniqueReturnedProducts.length;
    _returnedUniquePersons.value = uniqueReturnPersons.length;

    // Debug prints to verify data is being loaded correctly
    print('STATISTICS DATA:');
    print('Available Products: ${_availableProductsCount.value}');
    print('Rental - Agencies/Persons: ${_rentedUniquePersons.value}');
    print('Rental - Unique Products: ${_rentedUniqueProducts.value}');
    print('Rental - Total Quantity: ${_rentedTotalQuantity.value}');
    print('Return - Agencies/Persons: ${_returnedUniquePersons.value}');
    print('Return - Unique Products: ${_returnedUniqueProducts.value}');
    print('Return - Total Quantity: ${_returnedTotalQuantity.value}');
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

  Future<void> _refreshData() async {
    try {
      // Show syncing indicator
      Get.snackbar('syncing'.tr, 'syncing_message'.tr, duration: Duration(seconds: 1));

      // Sync with server and reload data
      await _controller.syncAndReload();

      // Recalculate counts
      _calculateTotalStocks();

      // Show success message
      Get.snackbar('sync_complete'.tr, 'data_updated'.tr, duration: Duration(seconds: 1));
    } catch (e) {
      Get.snackbar('sync_error'.tr, 'sync_failed'.tr + ': $e');
    }
  }

  // Get filtered history based on selected filter
  List<ProductHistory> get _filteredHistory {
    if (_selectedFilter == 'Rent') {
      return _controller.rentalHistory.take(7).toList();
    } else if (_selectedFilter == 'Return') {
      return _controller.returnHistory.take(7).toList();
    }
    // For 'All', combine both lists and take the most recent 7
    final combined = [..._controller.rentalHistory, ..._controller.returnHistory];
    combined.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort by most recent
    return combined.take(7).toList();
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
        'type': firstItem.type,
      });
    });

    // Sort by creation date, newest first
    result.sort((a, b) => (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));

    // No need to limit here as we already limit in _filteredHistory

    return result;
  }

  // Format date to display
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck.isAtSameMomentAs(DateTime(now.year, now.month, now.day))) {
      return 'TODAY';
    } else if (dateToCheck.isAtSameMomentAs(yesterday)) {
      return 'YESTERDAY';
    } else {
      return DateFormat('MMM dd').format(date).toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: CustomDrawer(),
      appBar: AppBar(
        backgroundColor: Color(0xFFdb8970),
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              Get.snackbar('notifications'.tr, 'no_new_notifications'.tr,
                duration: Duration(seconds: 2));
            },
          ),
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white),
            onPressed: () => Get.toNamed('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Mobile-optimized statistics dashboard
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Color(0xFFdb8970), // Salmon/coral background
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Prevent overflow
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Available Stock Display
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2, color: Colors.white, size: 28),
                        SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AVAILABLE STOCK',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 4),
                            Obx(() => Text(
                              '${_availableProductsCount.value}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            )),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 12),

                  // Detailed Statistics Section
                  Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      'TRANSACTION STATISTICS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),

                  // Rental and Return Statistics
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rental Statistics
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Row(
                                children: [
                                  Icon(Icons.shopping_cart, color: Colors.white, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'RENTAL',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),
                              // Stats
                              _buildCompactStatItem(label: 'Agencies/Persons', count: _rentedUniquePersons),
                              SizedBox(height: 2),
                              _buildCompactStatItem(label: 'Products', count: _rentedUniqueProducts),
                              SizedBox(height: 2),
                              _buildCompactStatItem(label: 'Total Quantity', count: _rentedTotalQuantity, highlight: true),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      // Return Statistics
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Row(
                                children: [
                                  Icon(Icons.assignment_return, color: Colors.white, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'RETURN',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),
                              // Stats
                              _buildCompactStatItem(label: 'Agencies/Persons', count: _returnedUniquePersons),
                              SizedBox(height: 2),
                              _buildCompactStatItem(label: 'Products', count: _returnedUniqueProducts),
                              SizedBox(height: 2),
                              _buildCompactStatItem(label: 'Total Quantity', count: _returnedTotalQuantity, highlight: true),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            // Recent Transactions section
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  children: [
                    // Transactions header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Transactions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            // Navigate to history page
                            if (_selectedFilter == 'Rent') {
                              Get.toNamed('/rental-history');
                            } else if (_selectedFilter == 'Return') {
                              Get.toNamed('/return-history');
                            } else {
                              Get.toNamed('/history');
                            }
                          },
                          child: Text(
                            'See all',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFFdb8970),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    // Filter tabs
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All'),
                          SizedBox(width: 8),
                          _buildFilterChip('Rent', color: Colors.green.withOpacity(0.2), textColor: Colors.green),
                          SizedBox(width: 8),
                          _buildFilterChip('Return', color: Colors.red.withOpacity(0.2), textColor: Colors.red),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    // Transactions list grouped by date
                    Expanded(
                      child: _buildTransactionsList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // Build compact stat item for detailed statistics
  Widget _buildCompactStatItem({required String label, required RxInt count, bool highlight = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Obx(() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: highlight ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${count.value}',
              style: TextStyle(
                color: Colors.white,
                fontSize: highlight ? 16 : 14,
                fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      )),
    );
  }

  // Build filter chip widget optimized for mobile
  Widget _buildFilterChip(String label, {Color? color, Color? textColor}) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? Color(0xFFdb8970).withOpacity(0.1))
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: (textColor ?? Color(0xFFdb8970)).withOpacity(0.5), width: 1)
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? (textColor ?? Color(0xFFdb8970))
                : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // Build transactions list widget
  Widget _buildTransactionsList() {
    // Get history based on selected filter
    final history = _filteredHistory;

    // Group the history items by transaction ID
    final groupedHistory = _groupHistoryByTransaction(history);

    // Create a section title based on the selected filter
    String sectionTitle = 'RECENT ACTIVITY';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text(
            sectionTitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // History list
        Expanded(
          child: groupedHistory.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                onRefresh: _refreshData,
                child: ListView.builder(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(vertical: 8),
                  itemCount: groupedHistory.length + 1, // +1 for the View More button
                  itemBuilder: (context, index) {
                    // If we're at the last index, show the View More button
                    if (index == groupedHistory.length) {
                      return _buildViewMoreButton();
                    }
                    // Otherwise show the history item
                    return _buildGroupedHistoryItem(groupedHistory[index]);
                  },
                ),
              ),
        ),
      ],
    );
  }

  // Build View More button as a list item
  Widget _buildViewMoreButton() {
    return InkWell(
      onTap: () {
        // Navigate to history page
        if (_selectedFilter == 'Rent') {
          Get.toNamed('/rental-history');
        } else if (_selectedFilter == 'Return') {
          Get.toNamed('/return-history');
        } else {
          Get.toNamed('/history');
        }
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16),
        margin: EdgeInsets.only(top: 8, bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Color(0xFFdb8970).withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'View More',
              style: TextStyle(
                color: Color(0xFFdb8970),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward, color: Color(0xFFdb8970), size: 18),
          ],
        ),
      ),
    );
  }

  // Build empty state widget
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey.shade400),
            SizedBox(height: 10),
            Text(
              'No ${_selectedFilter == "All" ? "" : _selectedFilter.toLowerCase()} history found',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // Build grouped history item widget
  Widget _buildGroupedHistoryItem(Map<String, dynamic> group) {
    final items = group['items'] as List<ProductHistory>;
    final isReturn = group['type'] == HistoryType.return_product;
    final actionColor = isReturn ? Colors.red : Colors.green;
    final actionType = isReturn ? 'Return' : 'Rent';
    final actionIcon = isReturn ? Icons.assignment_return : Icons.shopping_cart;

    // Skip return items when showing rent filter and vice versa
    if (_selectedFilter == 'Rent' && isReturn) return SizedBox.shrink();
    if (_selectedFilter == 'Return' && !isReturn) return SizedBox.shrink();

    // Format date and time from createdAt for consistency
    final DateTime createdAt = group['createdAt'] as DateTime;
    final formattedDate = DateFormat('MMM dd, yyyy').format(createdAt);
    final formattedTime = DateFormat('HH:mm').format(createdAt);
    final durationText = group['rentalDays'] != null
        ? '${group['rentalDays']} ${group['rentalDays'] == 1 ? 'day' : 'days'}'
        : '';

    // Determine if we should show agency or person name
    final String agency = group['agency'] as String? ?? '';
    final String personName = group['givenTo'] as String? ?? '';
    final String displayName = agency.isNotEmpty ? agency : personName;
    final bool hasAgency = agency.isNotEmpty;

    // Get product photo for the first item (as a representative image)
    final String? photoPath = items.isNotEmpty ? _getProductPhotoById(items.first.productId) : null;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ExpansionTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Color(0xFFdb8970).withOpacity(0.2),
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
                    return Center(child: Icon(actionIcon, color: Color(0xFFdb8970)));
                  },
                ),
              )
            : Icon(actionIcon, color: Color(0xFFdb8970)),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                displayName,
                style: TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: actionColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                actionType,
                style: TextStyle(color: actionColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
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
            SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.inventory_2, size: 12, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  '${items.length} ${items.length == 1 ? 'product' : 'products'}',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
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
              ...items.map((item) => _buildProductDetails(item)).toList(),
            ],
          ),
        ],
      ),
    );
  }

  // Build individual history item widget (for backward compatibility)
  Widget _buildHistoryItem(ProductHistory history) {
    final isReturn = history.type == HistoryType.return_product;
    final actionColor = isReturn ? Colors.red : Colors.green;
    final actionType = isReturn ? 'Return' : 'Rent';
    final actionIcon = isReturn ? Icons.assignment_return : Icons.shopping_cart;

    // Skip return items when showing rent filter and vice versa
    if (_selectedFilter == 'Rent' && isReturn) return SizedBox.shrink();
    if (_selectedFilter == 'Return' && !isReturn) return SizedBox.shrink();

    // Format date and time from rentedDate for consistency
    final formattedDate = DateFormat('MMM dd, yyyy').format(history.rentedDate);
    final formattedTime = DateFormat('HH:mm').format(history.rentedDate);
    final durationText = history.rentalDays != null
        ? '${history.rentalDays} ${history.rentalDays == 1 ? 'day' : 'days'}'
        : '';

    // Determine if we should show agency or person name
    final String agency = history.agency ?? '';
    final String personName = history.givenTo ?? '';
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
          child: Icon(actionIcon, color: Color(0xFFdb8970)),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                displayName,
                style: TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: actionColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                actionType,
                style: TextStyle(color: actionColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
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
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Divider(height: 1, thickness: 1),
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Product Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              _buildProductDetails(history),
            ],
          ),
        ],
      ),
    );
  }

  // Build product details widget for expanded view
  Widget _buildProductDetails(ProductHistory item) {
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
                if (item.rentalDays != null) ...[
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.timer, size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        'Duration: ${item.rentalDays} ${item.rentalDays == 1 ? 'day' : 'days'}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
