import 'package:get/get.dart';
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
      print('Adding new product: ${product.name}, barcode: ${product.barcode}');

      // Validate product data
      if (product.barcode.isEmpty) {
        ToastUtil.showError('Barcode cannot be empty');
        return;
      }

      if (product.name.isEmpty) {
        ToastUtil.showError('Product name cannot be empty');
        return;
      }

      if (product.quantity <= 0) {
        ToastUtil.showError('Quantity must be greater than zero');
        return;
      }

      // Add the product
      final addedProduct = await _dbService.addProductWithSync(product);
      print('Product added successfully: ID=${addedProduct.id}');

      // Add history entry
      await _dbService.addHistoryWithSync(ProductHistory(
        id: 0,
        productId: addedProduct.id,
        productName: product.name,
        barcode: product.barcode,
        quantity: product.quantity,
        type: HistoryType.added_stock,
        rentedDate: DateTime.now(),
        createdAt: DateTime.now(),
      ));
      print('History entry added');

      // Sync with server and reload data
      await syncAndReload();

      // Show success message
      try {
        ToastUtil.showSuccess('Product added successfully');
      } catch (toastError) {
        print('Error showing toast: $toastError');
      }
    } catch (e) {
      print('Error adding new product: $e');
      try {
        ToastUtil.showError('Failed to add product: $e');
      } catch (toastError) {
        print('Error showing toast: $toastError');
      }
    }
  }

  Future<void> addExistingStock(String barcode, int quantity) async {
    try {
      print('Adding stock to existing product with barcode: $barcode, quantity: $quantity');

      // Validate input
      if (barcode.isEmpty) {
        ToastUtil.showError('Barcode cannot be empty');
        return;
      }

      if (quantity <= 0) {
        ToastUtil.showError('Quantity must be greater than zero');
        return;
      }

      // Find the product
      final product = await getProductByBarcode(barcode);
      if (product != null) {
        print('Found existing product: ${product.name}, current quantity: ${product.quantity}');

        // Update the product
        final updatedProduct = product.copyWith(
          quantity: product.quantity + quantity,
          updatedAt: DateTime.now(),
        );
        await _dbService.updateProductWithSync(updatedProduct);
        print('Product updated, new quantity: ${updatedProduct.quantity}');

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

  Future<void> rentProduct(String barcode, int quantity, String givenTo, int rentalDays, {String? agency}) async {
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
        print('Found product: ${product.name}, current quantity: ${product.quantity}');

        // Check if we have enough stock
        if (product.quantity >= quantity) {
          // Update the product
          final updatedProduct = product.copyWith(
            quantity: product.quantity - quantity,
            updatedAt: DateTime.now(),
          );
          await _dbService.updateProductWithSync(updatedProduct);
          print('Product updated, new quantity: ${updatedProduct.quantity}');

          // Add history entry
          await _dbService.addHistoryWithSync(ProductHistory(
            id: 0,
            productId: product.id,
            productName: product.name,
            barcode: product.barcode,
            quantity: quantity,
            type: HistoryType.rental,
            givenTo: givenTo,
            agency: agency,
            rentedDate: DateTime.now(),
            rentalDays: rentalDays,
            createdAt: DateTime.now(),
          ));
          print('Rental history entry added');

          // Sync with server and reload data
          await syncAndReload();

          // Show success message
          try {
            ToastUtil.showSuccess('Product rented successfully');
          } catch (toastError) {
            print('Error showing toast: $toastError');
          }
        } else {
          print('Insufficient stock: requested $quantity, available ${product.quantity}');
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

  Future<void> returnProduct(String barcode, int quantity, String returnedBy, {String? agency, String? notes}) async {
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
        print('Found product: ${product.name}, current quantity: ${product.quantity}');

        // Update the product
        final updatedProduct = product.copyWith(
          quantity: product.quantity + quantity,
          updatedAt: DateTime.now(),
        );
        await _dbService.updateProductWithSync(updatedProduct);
        print('Product updated, new quantity: ${updatedProduct.quantity}');

        // Add history entry
        await _dbService.addHistoryWithSync(ProductHistory(
          id: 0,
          productId: product.id,
          productName: product.name,
          barcode: product.barcode,
          quantity: quantity,
          type: HistoryType.return_product,
          givenTo: returnedBy,
          agency: agency,
          returnDate: DateTime.now(),
          notes: notes,
          createdAt: DateTime.now(),
          rentedDate: DateTime.now(), // This is required but not really used for returns
        ));
        print('Return history entry added');

        // Sync with server and reload data
        await syncAndReload();

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
}