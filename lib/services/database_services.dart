import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/product_model.dart';
import '../models/history_model.dart';
import '../models/sync_model.dart';
import '../utils/database_batch_util.dart';

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
      try {
        // Initialize FFI
        sqfliteFfiInit();
        // Change the default factory for desktop
        databaseFactory = databaseFactoryFfi;
        print('Successfully initialized FFI for desktop platform');
      } catch (e) {
        print('Error initializing FFI for desktop platform: $e');
        print('Stack trace: ${StackTrace.current}');
        // Try again with a different approach
        try {
          print('Trying alternative initialization for desktop platform');
          // Force re-initialization
          sqfliteFfiInit();
          databaseFactory = databaseFactoryFfi;
          print('Alternative initialization successful');
        } catch (e2) {
          print('Alternative initialization also failed: $e2');
        }
      }
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
      if (Platform.isWindows) {
        // For Windows, use a specific approach to ensure proper path handling
        try {
          // Try to get the database path
          dbPath = await getDatabasesPath();
          print('Windows database path (initial): $dbPath');

          // Ensure the directory exists
          final dbDir = Directory(dbPath);
          if (!await dbDir.exists()) {
            print('Creating database directory: $dbPath');
            await dbDir.create(recursive: true);
          }

          // Normalize path for Windows
          dbPath = dbPath.replaceAll('\\', '/');
          print('Windows database path (normalized): $dbPath');
        } catch (e) {
          // Fallback to application documents directory
          print('Error getting database path for Windows: $e');
          print('Using fallback path');
          final appDocDir = await getApplicationDocumentsDirectory();
          dbPath = join(appDocDir.path, 'databases');
          print('Windows fallback database path: $dbPath');

          // Ensure the directory exists
          final dbDir = Directory(dbPath);
          if (!await dbDir.exists()) {
            print('Creating fallback database directory: $dbPath');
            await dbDir.create(recursive: true);
          }
        }
      } else if (Platform.isLinux || Platform.isMacOS) {
        // For other desktop platforms
        dbPath = await getDatabasesPath();
        print('Desktop database path: $dbPath');
      } else {
        // For mobile, use the default path
        dbPath = await getDatabasesPath();
        print('Mobile database path: $dbPath');
      }

      final path = join(dbPath, filePath);
      print('Full database path: $path');

      // Ensure the database file is accessible
      try {
        final dbFile = File(path);
        if (!await dbFile.exists()) {
          print('Database file does not exist yet, will be created');
        } else {
          print('Database file exists and is accessible');
        }
      } catch (e) {
        print('Error checking database file: $e');
      }

      return await openDatabase(
        path,
        version: 4, // Increased version for new schema
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
    } catch (e) {
      print('Error in _initDB: $e');
      print('Stack trace: ${StackTrace.current}');
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
      photo TEXT,
      unit_type TEXT,
      number_of_units INTEGER,
      size TEXT,
      color TEXT,
      material TEXT,
      weight TEXT,
      rent_price REAL,
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

        // IMPORTANT: Always add quantities when adding a product that already exists
        // This ensures we don't lose data during sync
        final int newQuantity = (existing.quantity ?? 0) + (product.quantity ?? 0);
        print('Merging quantities: ${existing.quantity ?? 0} + ${product.quantity ?? 0} = $newQuantity');

        // Update the existing product instead of adding a new one
        final updatedProduct = existing.copyWith(
          name: product.name,
          quantity: newQuantity, // Always add quantities when adding products
          pricePerQuantity: product.pricePerQuantity,
          photo: product.photo ?? existing.photo,
          unitType: product.unitType ?? existing.unitType,
          size: product.size ?? existing.size,
          color: product.color ?? existing.color,
          material: product.material ?? existing.material,
          weight: product.weight ?? existing.weight,
          rentPrice: product.rentPrice ?? existing.rentPrice,
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

    if (oldVersion < 4) {
      // Add new product fields
      print('Upgrading database to version 4: Adding new product fields');
      await db.execute('ALTER TABLE products ADD COLUMN photo TEXT');
      await db.execute('ALTER TABLE products ADD COLUMN unit_type TEXT');
      await db.execute('ALTER TABLE products ADD COLUMN number_of_units INTEGER');
      await db.execute('ALTER TABLE products ADD COLUMN size TEXT');
      await db.execute('ALTER TABLE products ADD COLUMN color TEXT');
      await db.execute('ALTER TABLE products ADD COLUMN material TEXT');
      await db.execute('ALTER TABLE products ADD COLUMN weight TEXT');
      await db.execute('ALTER TABLE products ADD COLUMN rent_price REAL');
    }
  }

  // Sync-related methods

  Future<void> addToSyncQueue(SyncItem item) async {
    final db = await database;
    // Use the toMap method which now properly handles JSON serialization
    await db.insert('sync_queue', item.toMap());
  }

  Future<List<SyncItem>> getPendingSyncItems() async {
    final db = await database;

    // Optimize sync queue before retrieving items
    await DatabaseBatchUtil.optimizeSyncQueue(db);

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
      print('Starting addProductWithSync for product: ${product.name}');

      // Validate product data before proceeding
      if (product.barcode.isEmpty) {
        throw Exception('Product barcode cannot be empty');
      }
      if (product.name.isEmpty) {
        throw Exception('Product name cannot be empty');
      }

      // Normalize photo path for Windows if needed
      String? normalizedPhotoPath = product.photo;
      if (normalizedPhotoPath != null && Platform.isWindows) {
        normalizedPhotoPath = normalizedPhotoPath.replaceAll('\\', '/');
        print('Normalized photo path: $normalizedPhotoPath');
      }

      // Generate sync ID and timestamp
      final syncId = const Uuid().v4();
      final now = DateTime.now();
      print('Generated syncId: $syncId');

      // Create product with sync info
      final productWithSync = product.copyWith(
        syncId: syncId,
        lastSynced: now,
        photo: normalizedPhotoPath, // Use normalized path
      );
      print('Created product with sync info');

      // Use optimized batch operation instead of separate calls
      print('Getting database instance');
      final db = await database;

      // First check if a product with this barcode already exists
      print('Checking if product with barcode ${product.barcode} already exists');
      final existing = await getProductByBarcode(product.barcode);

      if (existing != null) {
        print('Product with barcode ${product.barcode} already exists, updating instead');

        // Update the existing product
        final int newQuantity = (existing.quantity ?? 0) + (product.quantity ?? 0);
        print('Merging quantities: ${existing.quantity ?? 0} + ${product.quantity ?? 0} = $newQuantity');

        final updatedProduct = existing.copyWith(
          name: product.name,
          quantity: newQuantity,
          pricePerQuantity: product.pricePerQuantity,
          photo: normalizedPhotoPath ?? existing.photo,
          unitType: product.unitType ?? existing.unitType,
          size: product.size ?? existing.size,
          color: product.color ?? existing.color,
          material: product.material ?? existing.material,
          weight: product.weight ?? existing.weight,
          rentPrice: product.rentPrice ?? existing.rentPrice,
          updatedAt: DateTime.now(),
          syncId: syncId,
          lastSynced: now,
        );

        // Update the product directly
        print('Updating existing product');
        await updateProduct(updatedProduct);

        // Add history entry
        print('Adding history entry for updated product');
        final history = ProductHistory(
          id: 0,
          productId: updatedProduct.id,
          productName: updatedProduct.name,
          barcode: updatedProduct.barcode,
          quantity: product.quantity ?? 0,
          type: HistoryType.added_stock,
          rentedDate: DateTime.now(),
          createdAt: DateTime.now(),
          syncId: const Uuid().v4(),
          lastSynced: now,
        );

        await addHistory(history);

        // Add to sync queue
        await addToSyncQueue(SyncItem.fromProduct(updatedProduct, SyncOperation.update));

        print('Product updated successfully with ID: ${updatedProduct.id}');
        return updatedProduct;
      }

      // For new products, use the batch operation
      print('Creating history object for new product');
      final history = ProductHistory(
        id: 0,
        productId: 0, // Will be updated in the batch operation
        productName: product.name,
        barcode: product.barcode,
        quantity: product.quantity ?? 0,
        type: HistoryType.added_stock,
        rentedDate: DateTime.now(),
        createdAt: DateTime.now(),
        syncId: const Uuid().v4(),
        lastSynced: now,
      );

      // Try the batch operation first
      try {
        print('Calling DatabaseBatchUtil.addProductWithHistory');
        final addedProduct = await DatabaseBatchUtil.addProductWithHistory(
          db,
          productWithSync,
          history,
        );
        print('Product added successfully with ID: ${addedProduct.id}');
        return addedProduct;
      } catch (batchError) {
        // If batch operation fails, try direct insertion
        print('Batch operation failed: $batchError');
        print('Trying direct insertion as fallback');

        // Insert product directly
        final id = await db.insert('products', productWithSync.toMap(includeId: false));
        final newProduct = productWithSync.copyWith(id: id);

        // Update history with product ID
        final updatedHistory = history.copyWith(productId: id);
        await db.insert('product_history', updatedHistory.toMap(includeId: false));

        // Add to sync queue
        await addToSyncQueue(SyncItem.fromProduct(newProduct, SyncOperation.add));

        print('Direct insertion successful, product ID: $id');
        return newProduct;
      }
    } catch (e) {
      print('Error in addProductWithSync: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  Future<void> updateProductWithSync(Product product) async {
    try {
      print('Starting updateProductWithSync for product: ID=${product.id}, Name=${product.name}');

      // Normalize photo path for Windows if needed
      String? normalizedPhotoPath = product.photo;
      if (normalizedPhotoPath != null && Platform.isWindows) {
        normalizedPhotoPath = normalizedPhotoPath.replaceAll('\\', '/');
        print('Normalized photo path: $normalizedPhotoPath');

        // Create a copy of the product with the normalized photo path
        product = product.copyWith(photo: normalizedPhotoPath);
      }

      final now = DateTime.now();
      final updatedProduct = product.copyWith(
        lastSynced: now,
        // Ensure syncId exists
        syncId: product.syncId ?? const Uuid().v4(),
      );

      print('Product prepared for update: ID=${updatedProduct.id}, Name=${updatedProduct.name}');

      // Use optimized batch operation for better performance
      print('Optimizing product update with batch operation');
      final db = await database;

      // For desktop platforms, use a more reliable approach with individual operations
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        print('Using desktop-specific update approach');

        // First update the product
        print('Updating product in database');
        final result = await db.update(
          'products',
          updatedProduct.toMap(),
          where: 'id = ?',
          whereArgs: [updatedProduct.id],
        );

        if (result == 0) {
          // No rows were updated, try updating by barcode instead
          print('No product updated by ID, trying by barcode');
          final barcodeResult = await db.update(
            'products',
            updatedProduct.toMap(includeId: false),
            where: 'barcode = ?',
            whereArgs: [updatedProduct.barcode],
          );

          if (barcodeResult == 0) {
            print('Warning: Could not update product, no matching ID or barcode');
            throw Exception('Product not found with ID ${updatedProduct.id} or barcode ${updatedProduct.barcode}');
          } else {
            print('Updated product by barcode: ${updatedProduct.barcode}');
          }
        } else {
          print('Updated product by ID: ${updatedProduct.id}');
        }

        // Then add to sync queue
        print('Adding to sync queue');
        await db.insert(
          'sync_queue',
          SyncItem.fromProduct(updatedProduct, SyncOperation.update).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        print('Desktop update completed successfully');
      } else {
        // For mobile platforms, use the batch operation
        print('Using batch operation for mobile platform');
        await db.transaction((txn) async {
          final batch = txn.batch();

          // Update product
          batch.update(
            'products',
            updatedProduct.toMap(),
            where: 'id = ?',
            whereArgs: [updatedProduct.id],
          );

          // Add to sync queue
          batch.insert(
            'sync_queue',
            SyncItem.fromProduct(updatedProduct, SyncOperation.update).toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          // Commit batch operation (faster than individual operations)
          print('Committing batch update operation');
          await batch.commit(noResult: true);
          print('Batch update completed successfully');
        });
      }
    } catch (e) {
      print('Error in updateProductWithSync: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  // Enhanced history methods for sync

  Future<void> addHistoryWithSync(ProductHistory history) async {
    try {
      final syncId = const Uuid().v4();
      final now = DateTime.now();

      final historyWithSync = history.copyWith(
        syncId: syncId,
        lastSynced: now,
      );

      // Use transaction for better performance
      final db = await database;
      await db.transaction((txn) async {
        final batch = txn.batch();

        // Add history
        batch.insert(
          'product_history',
          historyWithSync.toMap(includeId: false),
          conflictAlgorithm: ConflictAlgorithm.replace
        );

        // Add to sync queue
        batch.insert(
          'sync_queue',
          SyncItem.fromHistory(historyWithSync, SyncOperation.add).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Commit batch operation (faster than individual operations)
        await batch.commit(noResult: true);
      });
    } catch (e) {
      print('Error in addHistoryWithSync: $e');
      rethrow;
    }
  }

  /// Process multiple product rentals in a single transaction
  Future<void> batchRentProducts(
    List<Map<String, dynamic>> rentItems,
    String givenTo,
    String? agency,
    String transactionId,
  ) async {
    try {
      final db = await database;
      await DatabaseBatchUtil.batchRentProducts(
        db,
        rentItems,
        givenTo,
        agency,
        transactionId,
      );
    } catch (e) {
      print('Error batch renting products: $e');
      rethrow;
    }
  }

  /// Process multiple product returns in a single transaction
  Future<void> batchReturnProducts(
    List<Map<String, dynamic>> returnItems,
    String returnedBy,
    String? agency,
    String transactionId,
  ) async {
    try {
      final db = await database;
      await DatabaseBatchUtil.batchReturnProducts(
        db,
        returnItems,
        returnedBy,
        agency,
        transactionId,
      );
    } catch (e) {
      print('Error batch returning products: $e');
      rethrow;
    }
  }
}