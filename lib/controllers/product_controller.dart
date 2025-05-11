import 'package:get/get.dart';
import '../models/product_model.dart';
import '../models/history_model.dart';
import '../services/database_services.dart';
import '../services/sync_service.dart';

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

      rentalHistory.value = await _dbService.getHistoryByType(HistoryType.rental);
      returnHistory.value = await _dbService.getHistoryByType(HistoryType.return_product);
      addedProductHistory.value = await _dbService.getHistoryByType(HistoryType.added_stock);

      print('Data loading complete');
    } catch (e) {
      print('Error loading data: $e');
      Get.snackbar('Error', 'Failed to load data: $e');
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
        Get.snackbar('Error', 'Barcode cannot be empty');
        return;
      }

      if (product.name.isEmpty) {
        Get.snackbar('Error', 'Product name cannot be empty');
        return;
      }

      if (product.quantity <= 0) {
        Get.snackbar('Error', 'Quantity must be greater than zero');
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

      // Reload data
      await loadData();

      // Show success message
      Get.snackbar('Success', 'Product added successfully');
    } catch (e) {
      print('Error adding new product: $e');
      Get.snackbar('Error', 'Failed to add product: $e');
    }
  }

  Future<void> addExistingStock(String barcode, int quantity) async {
    try {
      print('Adding stock to existing product with barcode: $barcode, quantity: $quantity');

      // Validate input
      if (barcode.isEmpty) {
        Get.snackbar('Error', 'Barcode cannot be empty');
        return;
      }

      if (quantity <= 0) {
        Get.snackbar('Error', 'Quantity must be greater than zero');
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

        // Reload data
        await loadData();

        // Show success message
        Get.snackbar('Success', 'Stock added successfully');
      } else {
        print('Product not found with barcode: $barcode');
        Get.snackbar('Error', 'Product not found');
      }
    } catch (e) {
      print('Error adding existing stock: $e');
      Get.snackbar('Error', 'Failed to add stock: $e');
    }
  }

  Future<void> rentProduct(String barcode, int quantity, String givenTo, int rentalDays, {String? agency}) async {
    try {
      print('Renting product with barcode: $barcode, quantity: $quantity, to: $givenTo');

      // Validate input
      if (barcode.isEmpty) {
        Get.snackbar('Error', 'Barcode cannot be empty');
        return;
      }

      if (quantity <= 0) {
        Get.snackbar('Error', 'Quantity must be greater than zero');
        return;
      }

      if (givenTo.isEmpty) {
        Get.snackbar('Error', 'Recipient name cannot be empty');
        return;
      }

      if (rentalDays <= 0) {
        Get.snackbar('Error', 'Rental days must be greater than zero');
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

          // Reload data
          await loadData();

          // Show success message
          Get.snackbar('Success', 'Product rented successfully');
        } else {
          print('Insufficient stock: requested $quantity, available ${product.quantity}');
          Get.snackbar('Error', 'Insufficient stock');
        }
      } else {
        print('Product not found with barcode: $barcode');
        Get.snackbar('Error', 'Product not found');
      }
    } catch (e) {
      print('Error renting product: $e');
      Get.snackbar('Error', 'Failed to rent product: $e');
    }
  }

  Future<void> returnProduct(String barcode, int quantity, String returnedBy, {String? agency, String? notes}) async {
    try {
      print('Returning product with barcode: $barcode, quantity: $quantity, by: $returnedBy');

      // Validate input
      if (barcode.isEmpty) {
        Get.snackbar('Error', 'Barcode cannot be empty');
        return;
      }

      if (quantity <= 0) {
        Get.snackbar('Error', 'Quantity must be greater than zero');
        return;
      }

      if (returnedBy.isEmpty) {
        Get.snackbar('Error', 'Returned by name cannot be empty');
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

        // Reload data
        await loadData();

        // Show success message
        Get.snackbar('Success', 'Product returned successfully');
      } else {
        print('Product not found with barcode: $barcode');
        Get.snackbar('Error', 'Product not found');
      }
    } catch (e) {
      print('Error returning product: $e');
      Get.snackbar('Error', 'Failed to return product: $e');
    }
  }
}