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
import '../utils/desktop_scroll_behavior.dart';
import '../utils/memory_management_util.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final ProductController controller = Get.find<ProductController>();
  final SyncService syncService = SyncService.instance;

  // Selected filter for transactions
  String selectedFilter = 'All';

  // Loading state
  final RxBool isLoading = true.obs;

  // Reactive statistics
  final RxInt availableProductsCount = 0.obs;
  final RxInt totalAvailableQuantity = 0.obs; // Total quantity of all available products
  final RxInt rentedTotalQuantity = 0.obs;
  final RxInt rentedUniqueProducts = 0.obs;
  final RxInt rentedUniquePersons = 0.obs;
  final RxInt returnedTotalQuantity = 0.obs;
  final RxInt returnedUniqueProducts = 0.obs;
  final RxInt returnedUniquePersons = 0.obs;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _setupListeners();

    // Start memory monitoring
    MemoryManagementUtil.startMemoryMonitoring();
  }

  @override
  void dispose() {
    // Stop memory monitoring when the page is disposed
    MemoryManagementUtil.stopMemoryMonitoring();
    super.dispose();
  }

  void _initializeData() async {
    isLoading.value = true;
    try {
      await controller.loadData();
      _calculateStatistics();
    } catch (e) {
      print('Error initializing data: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _setupListeners() {
    ever(controller.products, (_) => _calculateStatistics());
    ever(controller.rentalHistory, (_) => _calculateStatistics());
    ever(controller.returnHistory, (_) => _calculateStatistics());
  }

  void _calculateStatistics() {
    // Available products
    availableProductsCount.value = controller.products
        .where((product) => (product.quantity ?? 0) > 0)
        .length;

    // Rental statistics
    final rentalStats = _calculateTransactionStats(controller.rentalHistory);
    rentedTotalQuantity.value = rentalStats['totalQuantity']!;
    rentedUniqueProducts.value = rentalStats['uniqueProducts']!;
    rentedUniquePersons.value = rentalStats['uniquePersons']!;

    // Return statistics
    final returnStats = _calculateTransactionStats(controller.returnHistory);
    returnedTotalQuantity.value = returnStats['totalQuantity']!;
    returnedUniqueProducts.value = returnStats['uniqueProducts']!;
    returnedUniquePersons.value = returnStats['uniquePersons']!;
  }

  Map<String, int> _calculateTransactionStats(List<ProductHistory> history) {
    int totalQuantity = 0;
    final uniqueProducts = <int>{};
    final uniquePersons = <String>{};

    for (var item in history) {
      totalQuantity += item.quantity;
      uniqueProducts.add(item.productId);
      final person = item.agency?.isNotEmpty == true ? item.agency! : item.givenTo ?? '';
      if (person.isNotEmpty) uniquePersons.add(person);
    }

    return {
      'totalQuantity': totalQuantity,
      'uniqueProducts': uniqueProducts.length,
      'uniquePersons': uniquePersons.length,
    };
  }

  String? _getProductPhoto(int productId) {
    try {
      return controller.products
          .firstWhere((p) => p.id == productId)
          .photo;
    } catch (e) {
      return null;
    }
  }

  Future<void> _refreshData() async {
    try {
      isLoading.value = true;
      Get.snackbar('syncing'.tr, 'syncing_message'.tr, duration: const Duration(seconds: 1));
      await controller.syncAndReload();
      _calculateStatistics();
      Get.snackbar('sync_complete'.tr, 'data_updated'.tr, duration: const Duration(seconds: 1));
    } catch (e) {
      Get.snackbar('sync_error'.tr, 'sync_failed'.tr + ': $e');
    } finally {
      isLoading.value = false;
    }
  }

  List<ProductHistory> get filteredHistory {
    final history = selectedFilter == 'Rent'
        ? controller.rentalHistory
        : selectedFilter == 'Return'
        ? controller.returnHistory
        : [...controller.rentalHistory, ...controller.returnHistory];

    history.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return history.take(7).toList();
  }

  List<Map<String, dynamic>> _groupHistory(List<ProductHistory> history) {
    final Map<String, List<ProductHistory>> grouped = {};

    for (var item in history) {
      final key = item.transactionId ?? 'single_${item.id}';
      grouped.putIfAbsent(key, () => []).add(item);
    }

    var result = grouped.entries.map((entry) {
      final items = entry.value..sort((a, b) => a.productName.compareTo(b.productName));
      final firstItem = items.first;

      return {
        'transactionId': entry.key,
        'items': items,
        'givenTo': firstItem.givenTo,
        'agency': firstItem.agency,
        'rentalDays': firstItem.rentalDays,
        'createdAt': firstItem.createdAt,
        'type': firstItem.type,
      };
    }).toList();

    result = result.where((item) => item['createdAt'] != null).toList();
    // Sort by date descending (newest first)
    result.sort((a, b) => (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));
    return result;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) return 'TODAY';
    if (dateToCheck == yesterday) return 'YESTERDAY';
    return DateFormat('MMM dd').format(date).toUpperCase();
  }

  // Memoized widgets for better performance
  final Widget _loadingIndicator = const Center(
    child: CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFdb8970)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // Optimize memory before building the UI
    MemoryManagementUtil.optimizeBeforeHeavyOperation();

    return Scaffold(
      drawer: CustomDrawer(),
      body: Column(
        children: [
          // Fixed part: App bar and available stocks
          _buildFixedHeader(),

          // Scrollable part: Transaction statistics and history
          Expanded(
            child: Obx(() {
              if (isLoading.value) {
                return _loadingIndicator;
              }

              return ScrollConfiguration(
                behavior: DesktopScrollBehavior(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _buildTransactionStats(),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: _buildRecentTransactionsHeader(),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: _buildFilterTabs(),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: _buildTransactionsList(),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedHeader() {
    return Container(
      color: const Color(0xFFdb8970),
      child: SafeArea(
        child: Column(
          children: [
            // App Bar
            _buildAppBar(),

            // Available Stocks
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _buildStockCard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: Color(0xFFdb8970),
      ),
      child: Row(
        children: [
          // Menu button
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: 'Menu',
            ),
          ),

          // Empty space
          const Expanded(child: SizedBox()),

          // Action buttons
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
            tooltip: 'Notifications',
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => Get.toNamed('/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }



  Widget _buildStockCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2, color: Colors.white, size: 28),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AVAILABLE STOCK',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Obx(() => Text(
                '$availableProductsCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TRANSACTION STATISTICS',
          style: TextStyle(
            color: Color(0xFF333333),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildRentalStats()),
            const SizedBox(width: 8),
            Expanded(child: _buildReturnStats()),
          ],
        ),
      ],
    );
  }

  Widget _buildRentalStats() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_cart, color: Colors.green.shade700, size: 16),
              const SizedBox(width: 6),
              Text(
                'RENTAL',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildStatItem('Agencies/Persons', rentedUniquePersons, textColor: Colors.black87),
          _buildStatItem('Products', rentedUniqueProducts, textColor: Colors.black87),
          _buildStatItem('Total Quantity', rentedTotalQuantity, highlight: true, textColor: Colors.black87, highlightColor: Colors.green.withOpacity(0.2)),
        ],
      ),
    );
  }

  Widget _buildReturnStats() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_return, color: Colors.red.shade700, size: 16),
              const SizedBox(width: 6),
              Text(
                'RETURN',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildStatItem('Agencies/Persons', returnedUniquePersons, textColor: Colors.black87),
          _buildStatItem('Products', returnedUniqueProducts, textColor: Colors.black87),
          _buildStatItem('Total Quantity', returnedTotalQuantity, highlight: true, textColor: Colors.black87, highlightColor: Colors.red.withOpacity(0.2)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, RxInt count, {bool highlight = false, Color? textColor, Color? highlightColor}) {
    final textCol = textColor ?? Colors.white.withOpacity(0.9);
    final highlightCol = highlightColor ?? Colors.white.withOpacity(0.3);

    return Obx(() => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: textCol,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: highlight ? highlightCol : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: textCol,
                fontSize: highlight ? 16 : 14,
                fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildRecentTransactionsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Recent Transactions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        GestureDetector(
          onTap: () => Get.toNamed(
            selectedFilter == 'Rent'
                ? '/rental-history'
                : selectedFilter == 'Return'
                ? '/return-history'
                : '/history',
          ),
          child: const Text(
            'See all',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFFdb8970),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All'),
            const SizedBox(width: 8),
            _buildFilterChip('Rent', color: Colors.green.withOpacity(0.2), textColor: Colors.green),
            const SizedBox(width: 8),
            _buildFilterChip('Return', color: Colors.red.withOpacity(0.2), textColor: Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, {Color? color, Color? textColor}) {
    final isSelected = selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? const Color(0xFFdb8970).withOpacity(0.1))
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: (textColor ?? const Color(0xFFdb8970)).withOpacity(0.5))
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? (textColor ?? const Color(0xFFdb8970)) : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // Cached transaction lists for better performance
  final Map<String, List<Map<String, dynamic>>> _cachedTransactions = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheDuration = Duration(seconds: 30);

  // Memoized widgets
  final Widget _recentActivityHeader = const Padding(
    padding: EdgeInsets.symmetric(vertical: 10),
    child: Text(
      'RECENT ACTIVITY',
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  Widget _buildTransactionsList() {
    // Check if we have a valid cached result for this filter
    final now = DateTime.now();
    if (_cachedTransactions.containsKey(selectedFilter) &&
        _cacheTimestamps.containsKey(selectedFilter) &&
        now.difference(_cacheTimestamps[selectedFilter]!) < _cacheDuration) {
      final groupedHistory = _cachedTransactions[selectedFilter]!;
      return _buildTransactionsListContent(groupedHistory);
    }

    // Get and process history
    final groupedHistory = _groupHistory(filteredHistory);

    // Cache the result
    _cachedTransactions[selectedFilter] = groupedHistory;
    _cacheTimestamps[selectedFilter] = now;

    return _buildTransactionsListContent(groupedHistory);
  }

  Widget _buildTransactionsListContent(List<Map<String, dynamic>> groupedHistory) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _recentActivityHeader,
        if (groupedHistory.isEmpty)
          _buildEmptyState()
        else
          Column(
            children: [
              ...groupedHistory.map((group) => _buildGroupedHistoryItem(group)),
              const SizedBox(height: 8),
              _buildViewMoreButton(),
            ],
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 150,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(
            'No ${selectedFilter == "All" ? "" : selectedFilter.toLowerCase()} history found',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildViewMoreButton() {
    return Builder(
      builder: (context) => InkWell(
        onTap: () {
          // Open the drawer instead of navigating to a different page
          Scaffold.of(context).openDrawer();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          margin: const EdgeInsets.only(top: 8, bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFdb8970).withOpacity(0.3)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
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
      ),
    );
  }

  Widget _buildGroupedHistoryItem(Map<String, dynamic> group) {
    final items = group['items'] as List<ProductHistory>;
    final isReturn = group['type'] == HistoryType.return_product;
    if (selectedFilter == 'Rent' && isReturn || selectedFilter == 'Return' && !isReturn) {
      return const SizedBox.shrink();
    }

    final actionColor = isReturn ? Colors.red : Colors.green;
    final actionType = isReturn ? 'Return' : 'Rent';
    final actionIcon = isReturn ? Icons.assignment_return : Icons.shopping_cart;

    final createdAt = group['createdAt'] as DateTime;
    final formattedDate = DateFormat('MMM dd, yyyy').format(createdAt);
    final formattedTime = DateFormat('HH:mm').format(createdAt);
    final durationText = group['rentalDays'] != null
        ? '${group['rentalDays']} ${group['rentalDays'] == 1 ? 'day' : 'days'}'
        : '';

    final agency = group['agency'] as String? ?? '';
    final personName = group['givenTo'] as String? ?? '';
    final displayName = agency.isNotEmpty ? agency : personName;
    final hasAgency = agency.isNotEmpty;

    final photoPath = items.isNotEmpty ? _getProductPhoto(items.first.productId) : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ExpansionTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFdb8970).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: photoPath != null && photoPath.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ImagePickerUtil.getImageWidget(
                    photoPath,
                    width: 48,
                    height: 48,
                  ),
                )
              : Center(child: Icon(actionIcon, color: const Color(0xFFdb8970))),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                displayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: actionColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                actionType,
                style: TextStyle(
                  color: actionColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (hasAgency)
              Text(
                'Person: $personName',
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '$formattedDate at $formattedTime',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.inventory_2, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${items.length} ${items.length == 1 ? 'product' : 'products'}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 1),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Products',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              ...items.map(_buildProductDetails),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductDetails(ProductHistory item) {
    final photoPath = _getProductPhoto(item.productId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFdb8970).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: photoPath != null && photoPath.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ImagePickerUtil.getImageWidget(
                      photoPath,
                      width: 60,
                      height: 60,
                    ),
                  )
                : const Center(child: Icon(Icons.inventory, color: Color(0xFFdb8970))),
          ),
          const SizedBox(width: 12),
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
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFdb8970),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Qty: ${item.quantity}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.qr_code, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Barcode: ${item.barcode}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ],
                ),
                if (item.rentalDays != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.timer, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
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