import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/product_model.dart';
import '../models/history_model.dart';
import '../models/sync_model.dart';

/// Utility class for batch database operations to improve performance
class DatabaseBatchUtil {
  /// Execute multiple database operations in a single transaction
  /// This is much faster than executing them individually
  static Future<void> executeBatch(Database db, List<Map<String, dynamic>> operations) async {
    await db.transaction((txn) async {
      final batch = txn.batch();

      for (final operation in operations) {
        final String type = operation['type'];
        final String table = operation['table'];
        final dynamic data = operation['data'];
        final String? where = operation['where'];
        final List<dynamic>? whereArgs = operation['whereArgs'];

        switch (type) {
          case 'insert':
            batch.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
            break;
          case 'update':
            batch.update(table, data, where: where, whereArgs: whereArgs);
            break;
          case 'delete':
            batch.delete(table, where: where, whereArgs: whereArgs);
            break;
          default:
            throw Exception('Unknown operation type: $type');
        }
      }

      await batch.commit(noResult: true);
    });
  }

  /// Add a product and its history entry in a single transaction
  static Future<Product> addProductWithHistory(
      Database db,
      Product product,
      ProductHistory history
      ) async {
    Product? addedProduct;

    try {
      print('Starting database transaction for adding product');
      await db.transaction((txn) async {
        print('Checking if product with barcode ${product.barcode} already exists');
        // Check if a product with this barcode already exists
        final List<Map<String, dynamic>> existingProducts = await txn.query(
          'products',
          where: 'barcode = ?',
          whereArgs: [product.barcode],
        );
        print('Query result: ${existingProducts.length} existing products found');

        int productId;

        if (existingProducts.isNotEmpty) {
          // Product exists, update it instead of inserting
          final existingProduct = Product.fromMap(existingProducts.first);
          print('Product with barcode ${product.barcode} already exists in batch, updating instead');

          // IMPORTANT: Always add quantities when adding a product that already exists
          // This ensures we don't lose data during sync
          final int newQuantity = (existingProduct.quantity ?? 0) + (product.quantity ?? 0);
          print('Batch merging quantities: ${existingProduct.quantity ?? 0} + ${product.quantity ?? 0} = $newQuantity');

          // Update the existing product
          final updatedProduct = existingProduct.copyWith(
            name: product.name,
            quantity: newQuantity, // Always add quantities when adding products
            pricePerQuantity: product.pricePerQuantity,
            photo: product.photo ?? existingProduct.photo,
            unitType: product.unitType ?? existingProduct.unitType,
            size: product.size ?? existingProduct.size,
            color: product.color ?? existingProduct.color,
            material: product.material ?? existingProduct.material,
            weight: product.weight ?? existingProduct.weight,
            rentPrice: product.rentPrice ?? existingProduct.rentPrice,
            updatedAt: DateTime.now(),
            syncId: product.syncId ?? existingProduct.syncId,
            lastSynced: DateTime.now(),
          );

          // Update the product
          await txn.update(
            'products',
            updatedProduct.toMap(),
            where: 'id = ?',
            whereArgs: [updatedProduct.id],
          );

          productId = updatedProduct.id;
          addedProduct = updatedProduct;
        } else {
          // Insert new product
          print('Inserting new product: ${product.name}');
          try {
            final productMap = product.toMap(includeId: false);
            print('Product map for insertion: $productMap');
            productId = await txn.insert(
                'products',
                productMap,
                conflictAlgorithm: ConflictAlgorithm.replace
            );
            print('Product inserted with ID: $productId');

            // Create product with new ID
            addedProduct = product.copyWith(id: productId);
            print('Created product object with new ID');
          } catch (e) {
            print('Error inserting product: $e');
            print('Stack trace: ${StackTrace.current}');
            rethrow;
          }
        }

        // Insert history with the product ID
        print('Creating history entry for product ID: $productId');
        final updatedHistory = history.copyWith(productId: productId);
        try {
          final historyMap = updatedHistory.toMap(includeId: false);
          print('History map for insertion: $historyMap');
          await txn.insert(
              'product_history',
              historyMap,
              conflictAlgorithm: ConflictAlgorithm.replace
          );
          print('History entry inserted successfully');

          // Add to sync queue
          print('Adding product to sync queue');
          final syncItem = SyncItem.fromProduct(addedProduct!, SyncOperation.add);
          final syncMap = syncItem.toMap();
          print('Sync item map for insertion: $syncMap');
          await txn.insert(
              'sync_queue',
              syncMap,
              conflictAlgorithm: ConflictAlgorithm.replace
          );
          print('Product added to sync queue successfully');
        } catch (e) {
          print('Error inserting history or sync item: $e');
          print('Stack trace: ${StackTrace.current}');
          rethrow;
        }
      });
    } catch (e) {
      // Handle the error
      print('Error adding product with history: $e');
      rethrow;
    }

    return addedProduct!;
  }

  /// Optimize sync queue by combining similar operations
  static Future<void> optimizeSyncQueue(Database db) async {
    // Get all pending sync items
    final List<Map<String, dynamic>> pendingItems = await db.query(
      'sync_queue',
      where: 'status = ?',
      whereArgs: [SyncStatus.pending.index],
      orderBy: 'timestamp ASC',
    );

    // Group by entity_id and entity_type
    final Map<String, List<Map<String, dynamic>>> groupedItems = {};
    for (final item in pendingItems) {
      final key = '${item['entity_type']}_${item['entity_id']}';
      if (!groupedItems.containsKey(key)) {
        groupedItems[key] = [];
      }
      groupedItems[key]!.add(item);
    }

    // For each group, keep only the latest operation
    final List<String> itemsToDelete = [];
    for (final key in groupedItems.keys) {
      final items = groupedItems[key]!;
      if (items.length > 1) {
        // Sort by timestamp (descending)
        items.sort((a, b) => DateTime.parse(b['timestamp'] as String)
            .compareTo(DateTime.parse(a['timestamp'] as String)));

        // Keep the latest item, delete the rest
        for (int i = 1; i < items.length; i++) {
          itemsToDelete.add(items[i]['id'] as String);
        }
      }
    }

    // Delete redundant items
    if (itemsToDelete.isNotEmpty) {
      await db.transaction((txn) async {
        for (final id in itemsToDelete) {
          await txn.delete(
            'sync_queue',
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      });
    }
  }

  /// Process multiple product rentals in a single transaction for better performance
  static Future<void> batchRentProducts(
    Database db,
    List<Map<String, dynamic>> rentItems,
    String givenTo,
    String? agency,
    String transactionId,
  ) async {
    if (rentItems.isEmpty) return;

    await db.transaction((txn) async {
      final batch = txn.batch();
      final now = DateTime.now();

      for (final item in rentItems) {
        final String barcode = item['barcode'];
        final int quantity = item['quantity'];
        final int rentalDays = item['rentalDays'];

        // Get product by barcode
        final List<Map<String, dynamic>> products = await txn.query(
          'products',
          where: 'barcode = ?',
          whereArgs: [barcode],
        );

        if (products.isEmpty) continue;

        final product = Product.fromMap(products.first);

        // Check if we have enough stock
        if ((product.quantity ?? 0) < quantity) continue;

        // Update product quantity
        final updatedProduct = product.copyWith(
          quantity: (product.quantity ?? 0) - quantity,
          updatedAt: now,
          lastSynced: now,
        );

        // Update product
        batch.update(
          'products',
          updatedProduct.toMap(),
          where: 'id = ?',
          whereArgs: [product.id],
        );

        // Create history entry
        final history = ProductHistory(
          id: 0,
          productId: product.id,
          productName: product.name,
          barcode: product.barcode,
          quantity: quantity,
          type: HistoryType.rental,
          givenTo: givenTo,
          agency: agency,
          rentedDate: now,
          rentalDays: rentalDays,
          createdAt: now,
          syncId: const Uuid().v4(),
          lastSynced: now,
          transactionId: transactionId,
        );

        // Insert history
        batch.insert(
          'product_history',
          history.toMap(includeId: false),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Add to sync queue
        batch.insert(
          'sync_queue',
          SyncItem.fromProduct(updatedProduct, SyncOperation.update).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        batch.insert(
          'sync_queue',
          SyncItem.fromHistory(history, SyncOperation.add).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Execute all operations at once
      await batch.commit(noResult: true);
    });
  }

  /// Process multiple product returns in a single transaction for better performance
  static Future<void> batchReturnProducts(
    Database db,
    List<Map<String, dynamic>> returnItems,
    String returnedBy,
    String? agency,
    String transactionId,
  ) async {
    if (returnItems.isEmpty) return;

    await db.transaction((txn) async {
      final batch = txn.batch();
      final now = DateTime.now();

      for (final item in returnItems) {
        final String barcode = item['barcode'];
        final int quantity = item['quantity'];
        final String? notes = item['notes'];

        // Get product by barcode
        final List<Map<String, dynamic>> products = await txn.query(
          'products',
          where: 'barcode = ?',
          whereArgs: [barcode],
        );

        if (products.isEmpty) continue;

        final product = Product.fromMap(products.first);

        // Update product quantity
        final updatedProduct = product.copyWith(
          quantity: (product.quantity ?? 0) + quantity,
          updatedAt: now,
          lastSynced: now,
        );

        // Update product
        batch.update(
          'products',
          updatedProduct.toMap(),
          where: 'id = ?',
          whereArgs: [product.id],
        );

        // Create history entry
        final history = ProductHistory(
          id: 0,
          productId: product.id,
          productName: product.name,
          barcode: product.barcode,
          quantity: quantity,
          type: HistoryType.return_product,
          givenTo: returnedBy,
          agency: agency,
          rentedDate: now, // Required but not used for returns
          returnDate: now,
          notes: notes,
          createdAt: now,
          syncId: const Uuid().v4(),
          lastSynced: now,
          transactionId: transactionId,
        );

        // Insert history
        batch.insert(
          'product_history',
          history.toMap(includeId: false),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Add to sync queue
        batch.insert(
          'sync_queue',
          SyncItem.fromProduct(updatedProduct, SyncOperation.update).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        batch.insert(
          'sync_queue',
          SyncItem.fromHistory(history, SyncOperation.add).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Execute all operations at once
      await batch.commit(noResult: true);
    });
  }
}
