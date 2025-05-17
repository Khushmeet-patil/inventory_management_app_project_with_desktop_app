import 'dart:async';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../models/product_model.dart';
import '../models/history_model.dart';
import '../services/database_services.dart';
import '../services/sync_service.dart';
import '../utils/toast_util.dart';

class ProductController extends GetxController {
  final DatabaseService _dbService = DatabaseService.instance;
  final SyncService _syncService = SyncService.instance;

  final RxList<Product> products = <Product>[].obs;
  final RxList<ProductHistory> rentalHistory = <ProductHistory>[].obs;
  final RxList<ProductHistory> returnHistory = <ProductHistory>[].obs;
  final RxList<ProductHistory> addedProductHistory = <ProductHistory>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  Future<void> loadData() async {
    try {
      print('Loading product data...');
      products.value = await _dbService.getAllProducts();
      print('Loaded ${products.length} products');

      print('Loading history data...');
      rentalHistory.value = await _dbService.getHistoryByType(HistoryType.rental);
      print('Loaded ${rentalHistory.length} rental history entries');

      returnHistory.value = await _dbService.getHistoryByType(HistoryType.return_product);
      print('Loaded ${returnHistory.length} return history entries');

      addedProductHistory.value = await _dbService.getHistoryByType(HistoryType.added_stock);
      print('Loaded ${addedProductHistory.length} added product history entries');

      print('Data loading complete');
    } catch (e) {
      print('Error loading data: $e');
      try {
        ToastUtil.showError('Failed to load data: $e');
      } catch (toastError) {
        print('Error showing toast: $toastError');
      }
    }
  }

  // Sync data with server and reload
  Future<void> syncAndReload() async {
    try {
      print('Syncing data with server...');
      await _syncService.syncImmediately();
      print('Sync complete, reloading data...');
      await loadData();
    } catch (e) {
      print('Error during sync and reload: $e');
      // Still try to reload data even if sync fails
      await loadData();
    }
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    return await _dbService.getProductByBarcode(barcode);
  }

  Future<void> addNewProduct(Product product) async {
    try {
      print('Adding new product: ${product.name} with barcode ${product.barcode}');

      // Validate product data
      if (product.barcode.isEmpty) {
        print('Error: Barcode is empty');
        ToastUtil.showError('Barcode cannot be empty');
        return;
      }

      if (product.name.isEmpty) {
        print('Error: Product name is empty');
        ToastUtil.showError('Product name cannot be empty');
        return;
      }

      // Add the product - this now handles history entry in a single transaction
      print('Calling database service to add product');

      // Use a timeout to prevent hanging
      final addedProduct = await _dbService.addProductWithSync(product).timeout(
        Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Adding product timed out after 30 seconds');
        },
      );

      print('Product added successfully with ID: ${addedProduct.id}');

      // Reload data without immediate sync for better performance
      print('Reloading data');
      await loadData();

      // Schedule a sync in the background
      print('Scheduling background sync');
      _syncService.syncImmediately().catchError((e) {
        print('Background sync error: $e');
        // Ignore sync errors to keep UI responsive
      });

      // Show success message
      print('Showing success message');
      try {
        ToastUtil.showSuccess('Product added successfully');
      } catch (toastError) {
        print('Error showing success toast: $toastError');
        // Continue execution even if toast fails
      }

      print('Product addition completed successfully');
    } catch (e) {
      print('Error adding new product: $e');
      print('Stack trace: ${StackTrace.current}');

      // Try to show error message
      try {
        ToastUtil.showError('Failed to add product: ${e.toString()}');
      } catch (toastError) {
        print('Error showing error toast: $toastError');
      }

      // Rethrow the exception to be handled by the UI
      rethrow;
    }
  }

  Future<void> addExistingStock(String barcode, int quantity) async {
    try {
      print('Adding stock to existing product with barcode: $barcode, quantity: $quantity');

      // Validate input
      if (barcode.isEmpty) {
        print('Error: Barcode is empty');
        ToastUtil.showError('Barcode cannot be empty');
        return;
      }

      if (quantity <= 0) {
        print('Error: Quantity must be greater than zero');
        ToastUtil.showError('Quantity must be greater than zero');
        return;
      }

      // Find the product
      final product = await getProductByBarcode(barcode);
      if (product != null) {
        print('Found existing product: ${product.name}, current quantity: ${product.quantity ?? 0}');

        // Update the product
        final updatedProduct = product.copyWith(
          quantity: (product.quantity ?? 0) + quantity,
          updatedAt: DateTime.now(),
        );
        await _dbService.updateProductWithSync(updatedProduct);
        print('Product updated, new quantity: ${updatedProduct.quantity ?? 0}');

        // Add history entry
        await _dbService.addHistoryWithSync(ProductHistory(
          id: 0,
          productId: product.id,
          productName: product.name,
          barcode: product.barcode,
          quantity: quantity,
          type: HistoryType.added_stock,
          rentedDate: DateTime.now(),
          createdAt: DateTime.now(),
        ));
        print('History entry added');

        // Sync with server and reload data
        await syncAndReload();

        // Show success message
        try {
          ToastUtil.showSuccess('Stock added successfully');
        } catch (toastError) {
          print('Error showing toast: $toastError');
        }
      } else {
        print('Product not found with barcode: $barcode');
        try {
          ToastUtil.showError('Product not found');
        } catch (toastError) {
          print('Error showing toast: $toastError');
        }
      }
    } catch (e) {
      print('Error adding existing stock: $e');
      try {
        ToastUtil.showError('Failed to add stock: $e');
      } catch (toastError) {
        print('Error showing toast: $toastError');
      }
    }
  }

  Future<void> rentProduct(String barcode, int quantity, String givenTo, int rentalDays, {String? agency, String? transactionId}) async {
    try {
      print('Renting product with barcode: $barcode, quantity: $quantity, to: $givenTo');

      // Validate input
      if (barcode.isEmpty) {
        ToastUtil.showError('Barcode cannot be empty');
        return;
      }

      if (quantity <= 0) {
        ToastUtil.showError('Quantity must be greater than zero');
        return;
      }

      if (givenTo.isEmpty) {
        ToastUtil.showError('Recipient name cannot be empty');
        return;
      }

      if (rentalDays <= 0) {
        ToastUtil.showError('Rental days must be greater than zero');
        return;
      }

      // Find the product
      final product = await getProductByBarcode(barcode);
      if (product != null) {
        print('Found product: ${product.name}, current quantity: ${product.quantity ?? 0}');

        // Check if we have enough stock
        if ((product.quantity ?? 0) >= quantity) {
          // Create a single item list for the batch operation
          final rentItems = [
            {
              'barcode': barcode,
              'quantity': quantity,
              'rentalDays': rentalDays,
            }
          ];

          // Use the batch operation for better performance
          await _dbService.batchRentProducts(
            rentItems,
            givenTo,
            agency,
            transactionId ?? const Uuid().v4(),
          );

          // Reload data without waiting for sync to complete
          loadData();

          // Trigger sync in the background
          _syncService.syncImmediately().catchError((e) {
            print('Background sync error: $e');
            // Ignore sync errors to keep UI responsive
          });

          // Show success message
          try {
            ToastUtil.showSuccess('Product rented successfully');
          } catch (toastError) {
            print('Error showing toast: $toastError');
          }
        } else {
          print('Insufficient stock: requested $quantity, available ${product.quantity ?? 0}');
          try {
            ToastUtil.showError('Insufficient stock');
          } catch (toastError) {
            print('Error showing toast: $toastError');
          }
        }
      } else {
        print('Product not found with barcode: $barcode');
        try {
          ToastUtil.showError('Product not found');
        } catch (toastError) {
          print('Error showing toast: $toastError');
        }
      }
    } catch (e) {
      print('Error renting product: $e');
      try {
        ToastUtil.showError('Failed to rent product: $e');
      } catch (toastError) {
        print('Error showing toast: $toastError');
      }
    }
  }

  /// Rent multiple products in a single batch operation for better performance
  Future<void> batchRentProducts(List<Map<String, dynamic>> rentItems, String givenTo, {String? agency}) async {
    try {
      print('Batch renting ${rentItems.length} products to $givenTo');

      if (rentItems.isEmpty) {
        print('Error: No products to rent');
        ToastUtil.showError('No products to rent');
        return;
      }

      if (givenTo.isEmpty) {
        print('Error: Recipient name is empty');
        ToastUtil.showError('Recipient name cannot be empty');
        return;
      }

      // Generate a single transaction ID for all products in this batch
      final String transactionId = const Uuid().v4();
      print('Generated transaction ID for batch rental: $transactionId');

      // Use the batch operation for better performance
      print('Calling database service to batch rent products');
      await _dbService.batchRentProducts(
        rentItems,
        givenTo,
        agency,
        transactionId,
      );
      print('Products rented successfully');

      // Reload data without waiting for sync to complete
      print('Reloading data');
      await loadData();

      // Trigger sync in the background
      print('Scheduling background sync');
      _syncService.syncImmediately().catchError((e) {
        print('Background sync error: $e');
        // Ignore sync errors to keep UI responsive
      });

      // Show success message
      print('Showing success message');
      ToastUtil.showSuccess('products_rented_successfully'.tr);
    } catch (e) {
      print('Error batch renting products: $e');
      ToastUtil.showError('Failed to rent products: ${e.toString()}');
    }
  }

  Future<void> returnProduct(String barcode, int quantity, String returnedBy, {String? agency, String? notes, String? transactionId}) async {
    try {
      print('Returning product with barcode: $barcode, quantity: $quantity, by: $returnedBy');

      // Validate input
      if (barcode.isEmpty) {
        ToastUtil.showError('Barcode cannot be empty');
        return;
      }

      if (quantity <= 0) {
        ToastUtil.showError('Quantity must be greater than zero');
        return;
      }

      if (returnedBy.isEmpty) {
        ToastUtil.showError('Returned by name cannot be empty');
        return;
      }

      // Find the product
      final product = await getProductByBarcode(barcode);
      if (product != null) {
        print('Found product: ${product.name}, current quantity: ${product.quantity ?? 0}');

        // Create a single item list for the batch operation
        final returnItems = [
          {
            'barcode': barcode,
            'quantity': quantity,
            'notes': notes ?? '',
          }
        ];

        // Use the batch operation for better performance
        await _dbService.batchReturnProducts(
          returnItems,
          returnedBy,
          agency,
          transactionId ?? const Uuid().v4(),
        );

        // Reload data without waiting for sync to complete
        loadData();

        // Trigger sync in the background
        _syncService.syncImmediately().catchError((e) {
          print('Background sync error: $e');
          // Ignore sync errors to keep UI responsive
        });

        // Show success message
        try {
          ToastUtil.showSuccess('Product returned successfully');
        } catch (toastError) {
          print('Error showing toast: $toastError');
        }
      } else {
        print('Product not found with barcode: $barcode');
        try {
          ToastUtil.showError('Product not found');
        } catch (toastError) {
          print('Error showing toast: $toastError');
        }
      }
    } catch (e) {
      print('Error returning product: $e');
      try {
        ToastUtil.showError('Failed to return product: $e');
      } catch (toastError) {
        print('Error showing toast: $toastError');
      }
    }
  }

  /// Return multiple products in a single batch operation for better performance
  Future<void> batchReturnProducts(List<Map<String, dynamic>> returnItems, String returnedBy, {String? agency}) async {
    try {
      print('Batch returning ${returnItems.length} products by $returnedBy');

      if (returnItems.isEmpty) {
        print('Error: No products to return');
        ToastUtil.showError('No products to return');
        return;
      }

      if (returnedBy.isEmpty) {
        print('Error: Returned by name is empty');
        ToastUtil.showError('Returned by name cannot be empty');
        return;
      }

      // Generate a single transaction ID for all products in this batch
      final String transactionId = const Uuid().v4();
      print('Generated transaction ID for batch return: $transactionId');

      // Use the batch operation for better performance
      print('Calling database service to batch return products');
      await _dbService.batchReturnProducts(
        returnItems,
        returnedBy,
        agency,
        transactionId,
      );
      print('Products returned successfully');

      // Reload data without waiting for sync to complete
      print('Reloading data');
      await loadData();

      // Trigger sync in the background
      print('Scheduling background sync');
      _syncService.syncImmediately().catchError((e) {
        print('Background sync error: $e');
        // Ignore sync errors to keep UI responsive
      });

      // Show success message
      print('Showing success message');
      ToastUtil.showSuccess('products_returned_successfully'.tr);
    } catch (e) {
      print('Error batch returning products: $e');
      ToastUtil.showError('Failed to return products: ${e.toString()}');
    }
  }

  Future<void> updateProduct(Product product) async {
    try {
      print('Updating product: ID=${product.id}, Name=${product.name}');

      // Validate product data
      if (product.name.isEmpty) {
        ToastUtil.showError('Product name cannot be empty');
        return;
      }

      // Update the product
      await _dbService.updateProductWithSync(product);
      print('Product updated successfully');

      // Show success message
      try {
        ToastUtil.showSuccess('Product updated successfully');
      } catch (toastError) {
        print('Error showing toast: $toastError');
      }

      // Schedule a background sync instead of waiting for it
      _syncService.syncImmediately().catchError((e) {
        print('Background sync error: $e');
        // Ignore sync errors to keep UI responsive
      });

      // Reload data locally without waiting for sync
      loadData();
    } catch (e) {
      print('Error updating product: $e');
      try {
        ToastUtil.showError('Failed to update product: $e');
      } catch (toastError) {
        print('Error showing toast: $toastError');
      }
    }
  }
}