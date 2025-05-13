import 'dart:convert';
import 'dart:io' show Platform;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../models/product_model.dart';
import '../models/history_model.dart';
import '../models/sync_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init() {
    // Initialize FFI for desktop platforms
    _initializePlatformSpecific();
  }

  void _initializePlatformSpecific() {
    // Initialize FFI for desktop platforms
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      print('Initializing database for desktop platform');
      // Initialize FFI
      sqfliteFfiInit();
      // Change the default factory for desktop
      databaseFactory = databaseFactoryFfi;
    } else {
      print('Using default database factory for mobile platform');
    }
  }

  Future<Database> get database async {
    try {
      if (_database != null) return _database!;
      print('Initializing database...');
      _database = await _initDB('inventory.db');
      print('Database initialized successfully');
      return _database!;
    } catch (e) {
      print('Error initializing database: $e');
      // Re-initialize platform specific settings and try again
      _initializePlatformSpecific();
      try {
        print('Retrying database initialization...');
        _database = await _initDB('inventory.db');
        print('Database initialized successfully on retry');
        return _database!;
      } catch (retryError) {
        print('Failed to initialize database on retry: $retryError');
        rethrow;
      }
    }
  }

  Future<Database> _initDB(String filePath) async {
    try {
      String dbPath;
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // For desktop, use a path in the app documents directory
        dbPath = await getDatabasesPath();
        print('Desktop database path: $dbPath');
      } else {
        // For mobile, use the default path
        dbPath = await getDatabasesPath();
        print('Mobile database path: $dbPath');
      }

      final path = join(dbPath, filePath);
      print('Full database path: $path');

      return await openDatabase(
        path,
        version: 3,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
    } catch (e) {
      print('Error in _initDB: $e');
      rethrow;
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      barcode TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      price_per_quantity REAL NOT NULL,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL,
      syncId TEXT,
      lastSynced TEXT
    )
    ''');
    await db.execute('''
    CREATE TABLE product_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL,
      product_name TEXT NOT NULL,
      barcode TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      type INTEGER NOT NULL,
      given_to TEXT,
      agency TEXT,
      rental_days INTEGER,
      rented_date TEXT NOT NULL,
      return_date TEXT,
      notes TEXT,
      created_at TEXT NOT NULL,
      sync_id TEXT,
      last_synced TEXT,
      transaction_id TEXT,
      FOREIGN KEY (product_id) REFERENCES products (id)
    )
    ''');

    await db.execute('''
    CREATE TABLE sync_queue (
      id TEXT PRIMARY KEY,
      entity_id TEXT NOT NULL,
      entity_type TEXT NOT NULL,
      operation INTEGER NOT NULL,
      data TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      status INTEGER NOT NULL,
      error_message TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE devices (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      ip_address TEXT NOT NULL,
      port INTEGER NOT NULL,
      role INTEGER NOT NULL,
      last_seen TEXT NOT NULL
    )
    ''');
  }

  Future<List<Product>> getAllProducts() async {
    try {
      print('Getting all products from database');
      final db = await database;
      final maps = await db.query('products');
      final products = maps.map((map) => Product.fromMap(map)).toList();
      print('Retrieved ${products.length} products from database');
      return products;
    } catch (e) {
      print('Error getting all products: $e');
      // Return empty list instead of throwing to prevent UI crashes
      return [];
    }
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    try {
      print('Getting product with barcode: $barcode');
      final db = await database;
      final maps = await db.query('products', where: 'barcode = ?', whereArgs: [barcode]);

      if (maps.isNotEmpty) {
        final product = Product.fromMap(maps.first);
        print('Found product: ${product.name}, ID: ${product.id}');
        return product;
      } else {
        print('No product found with barcode: $barcode');
        return null;
      }
    } catch (e) {
      print('Error getting product by barcode: $e');
      return null;
    }
  }

  Future<Product> addProduct(Product product) async {
    try {
      final db = await database;

      // Check if a product with this barcode already exists
      final existing = await getProductByBarcode(product.barcode);
      if (existing != null) {
        print('Product with barcode ${product.barcode} already exists, updating instead');
        // Update the existing product instead of adding a new one
        final updatedProduct = existing.copyWith(
          name: product.name,
          quantity: existing.quantity + product.quantity,
          pricePerQuantity: product.pricePerQuantity,
          updatedAt: DateTime.now(),
          syncId: product.syncId ?? existing.syncId,
          lastSynced: DateTime.now(),
        );
        await updateProduct(updatedProduct);
        return updatedProduct;
      }

      // Insert new product
      print('Inserting new product: ${product.name} with barcode ${product.barcode}');
      final id = await db.insert('products', product.toMap(includeId: false));
      print('Inserted product with ID: $id');
      return product.copyWith(id: id);
    } catch (e) {
      print('Error adding product: $e');
      // If there's an error, try to get the product by barcode to see if it was actually added
      final existing = await getProductByBarcode(product.barcode);
      if (existing != null) {
        print('Product exists despite error, returning existing product');
        return existing;
      }
      rethrow;
    }
  }

  Future<void> updateProduct(Product product) async {
    try {
      final db = await database;
      print('Updating product: ID=${product.id}, Name=${product.name}, Quantity=${product.quantity}');

      final result = await db.update(
        'products',
        product.toMap(), // includeId: true by default
        where: 'id = ?',
        whereArgs: [product.id],
      );

      if (result == 0) {
        // No rows were updated, try updating by barcode instead
        print('No product updated by ID, trying by barcode');
        final barcodeResult = await db.update(
          'products',
          product.toMap(includeId: false), // Don't include ID when updating by barcode
          where: 'barcode = ?',
          whereArgs: [product.barcode],
        );

        if (barcodeResult == 0) {
          print('Warning: Could not update product, no matching ID or barcode');
        } else {
          print('Updated product by barcode: ${product.barcode}');
        }
      } else {
        print('Updated product by ID: ${product.id}');
      }
    } catch (e) {
      print('Error updating product: $e');
      rethrow;
    }
  }

  Future<void> addHistory(ProductHistory history) async {
    final db = await database;
    await db.insert('product_history', history.toMap());
  }

  Future<List<ProductHistory>> getHistoryByType(HistoryType type) async {
    final db = await database;
    final maps = await db.query('product_history', where: 'type = ?', whereArgs: [type.index], orderBy: 'created_at DESC');
    return maps.map((map) => ProductHistory.fromMap(map)).toList();
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add sync columns to products table
      await db.execute('ALTER TABLE products ADD COLUMN syncId TEXT');
      await db.execute('ALTER TABLE products ADD COLUMN lastSynced TEXT');

      // Add sync columns to product_history table
      await db.execute('ALTER TABLE product_history ADD COLUMN sync_id TEXT');
      await db.execute('ALTER TABLE product_history ADD COLUMN last_synced TEXT');

      // Create sync_queue table
      await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        entity_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        operation INTEGER NOT NULL,
        data TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        status INTEGER NOT NULL,
        error_message TEXT
      )
      ''');

      // Create devices table
      await db.execute('''
      CREATE TABLE devices (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        ip_address TEXT NOT NULL,
        port INTEGER NOT NULL,
        role INTEGER NOT NULL,
        last_seen TEXT NOT NULL
      )
      ''');
    }

    if (oldVersion < 3) {
      // Add transaction_id column to product_history table
      print('Upgrading database to version 3: Adding transaction_id column');
      await db.execute('ALTER TABLE product_history ADD COLUMN transaction_id TEXT');
    }
  }

  // Sync-related methods

  Future<void> addToSyncQueue(SyncItem item) async {
    final db = await database;
    await db.insert('sync_queue', {
      'id': item.id,
      'entity_id': item.entityId,
      'entity_type': item.entityType,
      'operation': item.operation.index,
      'data': jsonEncode(item.data),
      'timestamp': item.timestamp.toIso8601String(),
      'status': item.status.index,
      'error_message': item.errorMessage,
    });
  }

  Future<List<SyncItem>> getPendingSyncItems() async {
    final db = await database;
    final maps = await db.query(
      'sync_queue',
      where: 'status = ?',
      whereArgs: [SyncStatus.pending.index],
      orderBy: 'timestamp ASC',
    );

    return maps.map((map) {
      Map<String, dynamic> dataMap;
      try {
        // Try to parse the JSON data
        dataMap = jsonDecode(map['data'] as String);
      } catch (e) {
        // If parsing fails, use an empty map
        print('Error parsing sync data: $e');
        dataMap = {};
      }

      return SyncItem.fromMap({
        'id': map['id'] as String,
        'entity_id': map['entity_id'] as String,
        'entity_type': map['entity_type'] as String,
        'operation': map['operation'] as int,
        'data': dataMap,
        'timestamp': map['timestamp'] as String,
        'status': map['status'] as int,
        'error_message': map['error_message'] as String?,
      });
    }).toList();
  }

  Future<void> updateSyncItemStatus(String id, SyncStatus status, {String? errorMessage}) async {
    final db = await database;
    await db.update(
      'sync_queue',
      {
        'status': status.index,
        'error_message': errorMessage,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> saveDevice(DeviceInfo device) async {
    final db = await database;
    await db.insert(
      'devices',
      device.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DeviceInfo>> getAllDevices() async {
    final db = await database;
    final maps = await db.query('devices');
    return maps.map((map) => DeviceInfo.fromMap({
      'id': map['id'] as String,
      'name': map['name'] as String,
      'ip_address': map['ip_address'] as String,
      'port': map['port'] as int,
      'role': map['role'] as int,
      'last_seen': map['last_seen'] as String,
    })).toList();
  }

  Future<void> removeDevice(String deviceId) async {
    final db = await database;
    await db.delete(
      'devices',
      where: 'id = ?',
      whereArgs: [deviceId],
    );
  }

  // Enhanced product methods for sync

  Future<Product> addProductWithSync(Product product) async {
    try {
      print('Adding product with sync: ${product.name}, barcode: ${product.barcode}');
      final syncId = const Uuid().v4();
      final now = DateTime.now();

      final productWithSync = product.copyWith(
        syncId: syncId,
        lastSynced: now,
      );

      final addedProduct = await addProduct(productWithSync);
      print('Product added successfully: ID=${addedProduct.id}, syncId=${addedProduct.syncId}');

      // Add to sync queue
      await addToSyncQueue(SyncItem.fromProduct(addedProduct, SyncOperation.add));
      print('Product added to sync queue');

      return addedProduct;
    } catch (e) {
      print('Error in addProductWithSync: $e');
      rethrow;
    }
  }

  Future<void> updateProductWithSync(Product product) async {
    try {
      print('Updating product with sync: ID=${product.id}, Name=${product.name}, Quantity=${product.quantity}');
      final now = DateTime.now();
      final updatedProduct = product.copyWith(
        lastSynced: now,
        // Ensure syncId exists
        syncId: product.syncId ?? const Uuid().v4(),
      );

      await updateProduct(updatedProduct);
      print('Product updated successfully');

      // Add to sync queue
      await addToSyncQueue(SyncItem.fromProduct(updatedProduct, SyncOperation.update));
      print('Product update added to sync queue');
    } catch (e) {
      print('Error in updateProductWithSync: $e');
      rethrow;
    }
  }

  // Enhanced history methods for sync

  Future<void> addHistoryWithSync(ProductHistory history) async {
    final syncId = const Uuid().v4();
    final now = DateTime.now();

    final historyWithSync = history.copyWith(
      syncId: syncId,
      lastSynced: now,
    );

    await addHistory(historyWithSync);

    // Add to sync queue
    await addToSyncQueue(SyncItem.fromHistory(historyWithSync, SyncOperation.add));
  }
}