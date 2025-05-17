import 'dart:convert';
import 'package:sqflite/sqflite.dart';
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
      await db.transaction((txn) async {
        // Insert product
        final productId = await txn.insert(
            'products',
            product.toMap(includeId: false),
            conflictAlgorithm: ConflictAlgorithm.replace
        );

        // Create product with new ID
        addedProduct = product.copyWith(id: productId);

        // Insert history with the new product ID
        final updatedHistory = history.copyWith(productId: productId);
        await txn.insert(
            'product_history',
            updatedHistory.toMap(includeId: false),
            conflictAlgorithm: ConflictAlgorithm.replace
        );

        // Add to sync queue
        await txn.insert(
            'sync_queue',
            SyncItem.fromProduct(addedProduct!, SyncOperation.add).toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace
        );
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
}
