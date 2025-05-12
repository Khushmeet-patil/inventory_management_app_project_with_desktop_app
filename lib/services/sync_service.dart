import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../models/sync_model.dart';
import '../models/product_model.dart';
import '../models/history_model.dart';
import '../controllers/product_controller.dart';
import 'database_services.dart';
import 'network_service.dart';

class SyncService {
  static final SyncService instance = SyncService._init();

  final DatabaseService _dbService = DatabaseService.instance;
  final NetworkService _networkService = NetworkService.instance;

  // Sync status
  final RxBool isSyncing = false.obs;
  final RxString syncStatus = 'Not synced'.obs;
  final RxInt pendingSyncItems = 0.obs;

  // Sync timer
  Timer? _syncTimer;
  final int syncIntervalSeconds = 5; // Reduced to 5 seconds for more frequent syncing

  SyncService._init();

  Future<void> initialize({
    required DeviceRole role,
    String? customDeviceName,
    String? customIpAddress,
  }) async {
    // Initialize network service
    await _networkService.initialize(
      role: role,
      customDeviceName: customDeviceName,
      customIpAddress: customIpAddress,
      syncBatchCallback: _handleIncomingSyncBatch,
    );

    // Start sync timer if client
    if (role == DeviceRole.client) {
      _startSyncTimer();
    }

    // Update pending sync items count
    _updatePendingSyncCount();
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      Duration(seconds: syncIntervalSeconds),
      (_) => syncWithServer(),
    );
  }

  Future<void> _updatePendingSyncCount() async {
    final items = await _dbService.getPendingSyncItems();
    pendingSyncItems.value = items.length;
  }

  Future<void> syncWithServer() async {
    // If already syncing, wait a bit and return
    if (isSyncing.value) {
      print('Sync already in progress, waiting...');
      await Future.delayed(Duration(milliseconds: 500));
      if (isSyncing.value) {
        print('Sync still in progress after waiting, skipping this request');
        return;
      }
    }

    isSyncing.value = true;
    syncStatus.value = 'Syncing...';
    print('Starting sync process');

    try {
      // First try to discover devices to ensure we have the latest server info
      try {
        print('Discovering devices before sync...');
        await _networkService.discoverDevices();
      } catch (e) {
        print('Error discovering devices: $e');
        // Continue anyway
      }

      // Find server devices
      final servers = await _networkService.getServerDevices();
      print('Found ${servers.length} servers for sync');

      if (servers.isEmpty) {
        // Try to get servers from database as fallback
        final dbDevices = await _dbService.getAllDevices();
        final dbServers = dbDevices.where((d) =>
          d.role == DeviceRole.server && d.id != _networkService.deviceId
        ).toList();

        print('Found ${dbServers.length} servers from database');

        if (dbServers.isNotEmpty) {
          servers.addAll(dbServers);
        } else {
          syncStatus.value = 'No server found';
          isSyncing.value = false;
          return;
        }
      }

      // Get pending sync items
      final pendingItems = await _dbService.getPendingSyncItems();
      print('Found ${pendingItems.length} pending items to sync');

      // Even if no pending items, we'll still try to connect to verify server is reachable
      final testBatch = SyncBatch(
        id: const Uuid().v4(),
        deviceId: _networkService.deviceId,
        items: pendingItems.isEmpty ? [] : pendingItems,
        timestamp: DateTime.now(),
      );

      // Try each server until one works
      bool syncSuccess = false;
      String errorMessage = '';

      for (final server in servers) {
        print('Trying to sync with server: ${server.name} (${server.ipAddress})');
        try {
          // First try to ping the server
          final pingSuccess = await _networkService.pingDevice(server.ipAddress, server.port);
          if (!pingSuccess) {
            print('Warning: Could not ping server ${server.ipAddress}. Will try to sync anyway.');
          }

          // Send to server
          final success = await _networkService.sendSyncBatch(server, testBatch);

          if (success) {
            print('Successfully connected to server ${server.ipAddress}');
            syncSuccess = true;

            // If we have pending items, update their status
            if (pendingItems.isNotEmpty) {
              for (final item in pendingItems) {
                await _dbService.updateSyncItemStatus(item.id, SyncStatus.completed);
              }
              syncStatus.value = 'Synced successfully';
            } else {
              syncStatus.value = 'Connected to server';
            }

            // Request all products from server to ensure we have the latest data
            await _requestLatestDataFromServer(server);

            break; // Exit the loop if successful
          } else {
            print('Failed to sync with server ${server.ipAddress}');
            errorMessage = 'Failed to connect to server';
          }
        } catch (e) {
          print('Error syncing with server ${server.ipAddress}: $e');
          errorMessage = 'Error: $e';
        }
      }

      if (!syncSuccess) {
        syncStatus.value = 'Sync failed: $errorMessage';
      } else {
        // If we're a server, also propagate to all clients
        if (_networkService.deviceRole == DeviceRole.server) {
          print('We are a server, propagating changes to all clients');
          // Create an empty batch to trigger sending all data to clients
          final emptyBatch = SyncBatch(
            id: const Uuid().v4(),
            deviceId: _networkService.deviceId,
            items: [],
            timestamp: DateTime.now(),
          );
          await _propagateChangesToClients(emptyBatch);
        }
      }
    } catch (e) {
      print('Sync error: $e');
      syncStatus.value = 'Sync error: $e';
    } finally {
      isSyncing.value = false;
      _updatePendingSyncCount();
    }
  }

  Future<void> _handleIncomingSyncBatch(SyncBatch batch) async {
    try {
      print('Received sync batch from device ${batch.deviceId} with ${batch.items.length} items');

      // If we're a server and received an empty batch, it's a request for all products
      if (batch.items.isEmpty && _networkService.deviceRole == DeviceRole.server) {
        print('Received empty batch from client, treating as request for all products');
        await _sendProductsToClient(batch.deviceId);
        return;
      }

      // If this is a batch from server, it might be a full product list
      if (_networkService.deviceRole == DeviceRole.client) {
        print('Processing ${batch.items.length} items from server');
        int processedCount = 0;

        // Process all items in the batch
        for (final item in batch.items) {
          await _processSyncItem(item);
          processedCount++;
          if (processedCount % 10 == 0) {
            print('Processed $processedCount/${batch.items.length} items');
          }
        }

        print('Completed processing all ${batch.items.length} items');

        // Reload product data in UI
        await _reloadProductData();

        // Show a notification if there are items in the batch
        if (batch.items.isNotEmpty) {
          try {
            Get.snackbar(
              'Data Updated',
              'Received ${batch.items.length} updates from server',
              duration: Duration(seconds: 2),
              snackPosition: SnackPosition.BOTTOM,
            );
          } catch (e) {
            print('Error showing notification: $e');
          }
        }
      } else {
        // We're a server processing items from a client
        print('Server processing ${batch.items.length} items from client');

        // Process normal sync items
        for (final item in batch.items) {
          await _processSyncItem(item);
        }

        // Reload our own data first
        await _reloadProductData();

        // Propagate changes to other clients
        print('Propagating changes to other clients');
        await _propagateChangesToClients(batch);

        // Send all products back to the client that just sent us data
        // This ensures the client has the complete dataset
        print('Sending all products back to client ${batch.deviceId}');
        await _sendProductsToClient(batch.deviceId);
      }
    } catch (e) {
      print('Error processing sync batch: $e');
    }
  }

  Future<void> _processSyncItem(SyncItem item) async {
    try {
      if (item.entityType == 'product') {
        await _processProductSync(item);
      } else if (item.entityType == 'history') {
        await _processHistorySync(item);
      }
    } catch (e) {
      print('Error processing sync item ${item.id}: $e');
    }
  }

  Future<void> _processProductSync(SyncItem item) async {
    try {
      final productData = item.data;
      print('Processing product sync: ${item.operation}, data: $productData');

      // Validate the data
      if (productData == null || productData.isEmpty) {
        print('Warning: Empty product data in sync item');
        return;
      }

      if (!productData.containsKey('barcode') || productData['barcode'] == null || productData['barcode'].toString().isEmpty) {
        print('Warning: Missing or empty barcode in product data');
        return;
      }

      switch (item.operation) {
        case SyncOperation.add:
        case SyncOperation.update:
          try {
            final product = Product.fromMap(productData);
            print('Parsed product: ${product.name}, quantity: ${product.quantity}, barcode: ${product.barcode}');

            // Check if product exists by barcode
            final existingProduct = await _dbService.getProductByBarcode(product.barcode);
            print('Existing product: ${existingProduct?.name}, quantity: ${existingProduct?.quantity}');

            if (existingProduct == null) {
              // Add new product
              print('Adding new product: ${product.name}');
              await _dbService.addProduct(product);
            } else {
              // Update existing product with ALL relevant fields
              final updatedProduct = existingProduct.copyWith(
                name: product.name,
                quantity: product.quantity,
                pricePerQuantity: product.pricePerQuantity,
                updatedAt: product.updatedAt,
                syncId: product.syncId,
                lastSynced: DateTime.now(),
              );
              print('Updating product: ${updatedProduct.name}, new quantity: ${updatedProduct.quantity}');
              await _dbService.updateProduct(updatedProduct);
            }
          } catch (e) {
            print('Error processing product data: $e');
            print('Problematic data: $productData');
          }
          break;

        case SyncOperation.delete:
          // Not implemented yet
          print('Delete operation not implemented yet');
          break;
      }
    } catch (e) {
      print('Error in _processProductSync: $e');
    }
  }

  Future<void> _processHistorySync(SyncItem item) async {
    try {
      if (item.data == null || item.data.isEmpty) {
        print('Warning: Empty history data in sync item');
        return;
      }

      final historyData = Map<String, dynamic>.from(item.data);
      print('Processing history sync: ${item.operation}, type: ${historyData['type']}');

      switch (item.operation) {
        case SyncOperation.add:
          try {
            // Check if this history entry already exists by syncId
            String? syncId = historyData['sync_id'];
            bool alreadyExists = false;

            if (syncId != null) {
              // This is a simplified check - in a real app, you'd query the database
              // Here we're just checking if the history type and product match
              final historyType = HistoryType.values[historyData['type'] as int];
              final existingHistory = await _dbService.getHistoryByType(historyType);

              alreadyExists = existingHistory.any((h) => h.syncId == syncId);
            }

            if (!alreadyExists) {
              final history = ProductHistory.fromMap(historyData);
              print('Adding history entry for product: ${history.productName}, quantity: ${history.quantity}, type: ${history.type}');
              await _dbService.addHistory(history);
              print('History entry added successfully');
            } else {
              print('History entry with syncId $syncId already exists, skipping');
            }
          } catch (e) {
            print('Error processing history data: $e');
            print('Problematic data: $historyData');
          }
          break;

        case SyncOperation.update:
        case SyncOperation.delete:
          // Not implemented yet
          print('History update/delete not implemented yet');
          break;
      }
    } catch (e) {
      print('Error in _processHistorySync: $e');
    }
  }

  Future<void> _propagateChangesToClients(SyncBatch originalBatch) async {
    // Get all client devices from both known devices and database
    final knownClients = _networkService.knownDevices
        .where((device) =>
            device.role == DeviceRole.client &&
            device.id != originalBatch.deviceId)
        .toList();

    print('Found ${knownClients.length} known clients to propagate changes to');

    // Also try to get clients from database as fallback
    final dbDevices = await _dbService.getAllDevices();
    final dbClients = dbDevices.where((d) =>
      d.role == DeviceRole.client &&
      d.id != _networkService.deviceId &&
      d.id != originalBatch.deviceId &&
      !knownClients.any((kc) => kc.id == d.id) // Avoid duplicates
    ).toList();

    print('Found ${dbClients.length} additional clients from database');

    // Combine both lists
    final allClients = [...knownClients, ...dbClients];

    if (allClients.isEmpty) {
      print('No clients found to propagate changes to');
      return;
    }

    print('Propagating changes to ${allClients.length} total clients');

    // Send to each client
    for (final client in allClients) {
      try {
        print('Propagating changes to client: ${client.name} (${client.ipAddress})');
        final success = await _networkService.sendSyncBatch(client, originalBatch);
        print('Propagation to ${client.name} ${success ? 'successful' : 'failed'}');

        // If successful, also send a complete data set to ensure client has everything
        if (success) {
          print('Sending complete data set to client ${client.id}');
          await _sendProductsToClient(client.id);
        }
      } catch (e) {
        print('Error propagating changes to client ${client.name}: $e');
        // Continue with next client
      }
    }
  }

  Future<void> _requestLatestDataFromServer(DeviceInfo server) async {
    try {
      print('Requesting latest data from server: ${server.name} (${server.ipAddress})');

      // First, send all our local products to the server
      await _sendAllLocalProductsToServer(server);

      // Then, create a special sync batch that requests all products
      final requestBatch = SyncBatch(
        id: const Uuid().v4(),
        deviceId: _networkService.deviceId,
        items: [], // Empty items list indicates we're just requesting data
        timestamp: DateTime.now(),
      );

      // Send request to server
      final success = await _networkService.sendSyncBatch(server, requestBatch);

      if (success) {
        print('Successfully requested data from server');
      } else {
        print('Failed to request data from server');
      }
    } catch (e) {
      print('Error requesting data from server: $e');
    }
  }

  Future<void> _sendAllLocalProductsToServer(DeviceInfo server) async {
    try {
      print('Sending all local data to server: ${server.name} (${server.ipAddress})');

      // Get all products from database
      final products = await _dbService.getAllProducts();
      print('Found ${products.length} local products to send to server');

      // Get all history entries
      final addedHistory = await _dbService.getHistoryByType(HistoryType.added_stock);
      final rentalHistory = await _dbService.getHistoryByType(HistoryType.rental);
      final returnHistory = await _dbService.getHistoryByType(HistoryType.return_product);
      final allHistory = [...addedHistory, ...rentalHistory, ...returnHistory];
      print('Found ${allHistory.length} history entries to send to server');

      // Create sync items list
      final List<SyncItem> syncItems = [];

      // Add products to sync items
      for (final product in products) {
        syncItems.add(SyncItem.fromProduct(product, SyncOperation.update));
      }

      // Add history entries to sync items
      for (final history in allHistory) {
        syncItems.add(SyncItem.fromHistory(history, SyncOperation.add));
      }

      if (syncItems.isEmpty) {
        print('No data to send');
        return;
      }

      print('Sending ${syncItems.length} items to server (${products.length} products, ${allHistory.length} history entries)');

      // Create a sync batch with all data
      final syncBatch = SyncBatch(
        id: const Uuid().v4(),
        deviceId: _networkService.deviceId,
        items: syncItems,
        timestamp: DateTime.now(),
      );

      // Send to server
      final success = await _networkService.sendSyncBatch(server, syncBatch);

      if (success) {
        print('Successfully sent all local data to server');
      } else {
        print('Failed to send local data to server');
      }
    } catch (e) {
      print('Error sending local data to server: $e');
    }
  }

  Future<void> _reloadProductData() async {
    try {
      // Try to find the ProductController instance
      if (Get.isRegistered<ProductController>()) {
        final controller = Get.find<ProductController>();
        print('Reloading product and history data in ProductController');
        await controller.loadData();
        print('Data reload complete');
      } else {
        print('No ProductController instance found to reload data');
      }
    } catch (e) {
      print('Error reloading data: $e');
    }
  }

  // Method for immediate sync - called by ProductController
  Future<void> syncImmediately() async {
    print('Immediate sync requested');
    await forceSync();
  }

  Future<void> forceSync() async {
    print('Force sync requested');

    // First, try to discover devices to ensure we have the latest server info
    try {
      print('Discovering devices before force sync...');
      await _networkService.discoverDevices();
    } catch (e) {
      print('Error discovering devices: $e');
      // Continue anyway
    }

    // Then perform the sync
    await syncWithServer();

    // Reload product data in UI regardless of sync result
    try {
      await _reloadProductData();
    } catch (e) {
      print('Error reloading product data: $e');
    }
  }

  Future<void> _sendProductsToClient(String clientDeviceId) async {
    try {
      print('Preparing to send all data to client: $clientDeviceId');

      // Get all products from database
      final products = await _dbService.getAllProducts();
      print('Found ${products.length} products to send to client');

      // Get all history entries
      final addedHistory = await _dbService.getHistoryByType(HistoryType.added_stock);
      final rentalHistory = await _dbService.getHistoryByType(HistoryType.rental);
      final returnHistory = await _dbService.getHistoryByType(HistoryType.return_product);
      final allHistory = [...addedHistory, ...rentalHistory, ...returnHistory];
      print('Found ${allHistory.length} history entries to send to client');

      if (products.isEmpty && allHistory.isEmpty) {
        print('No data to send to client');
        return;
      }

      // Find the client device in known devices
      DeviceInfo? clientDevice;
      try {
        final knownDevices = _networkService.knownDevices;
        clientDevice = knownDevices.firstWhere(
          (device) => device.id == clientDeviceId,
        );
      } catch (e) {
        print('Client device not found in known devices, searching in database...');

        // Try to find the device in the database
        final dbDevices = await _dbService.getAllDevices();
        try {
          clientDevice = dbDevices.firstWhere(
            (device) => device.id == clientDeviceId,
          );
          print('Found client device in database: ${clientDevice.name} (${clientDevice.ipAddress})');
        } catch (dbError) {
          print('Client device not found in database either: $dbError');
          return;
        }
      }

      if (clientDevice == null) {
        print('Could not find client device with ID: $clientDeviceId');
        return;
      }

      // Create sync items list
      final List<SyncItem> syncItems = [];

      // Add products to sync items
      for (final product in products) {
        syncItems.add(SyncItem(
          id: const Uuid().v4(),
          entityId: product.syncId ?? product.id.toString(),
          entityType: 'product',
          operation: SyncOperation.update,
          data: product.toMap(),
          timestamp: DateTime.now(),
        ));
      }

      // Add history entries to sync items
      for (final history in allHistory) {
        syncItems.add(SyncItem(
          id: const Uuid().v4(),
          entityId: history.syncId ?? history.id.toString(),
          entityType: 'history',
          operation: SyncOperation.add,
          data: history.toMap(includeId: true),
          timestamp: DateTime.now(),
        ));
      }

      // Create a sync batch with all data
      final syncBatch = SyncBatch(
        id: const Uuid().v4(),
        deviceId: _networkService.deviceId,
        items: syncItems,
        timestamp: DateTime.now(),
      );

      // Send the batch to the client
      print('Sending ${syncItems.length} items to client ${clientDevice.name} (${products.length} products, ${allHistory.length} history entries)');
      final success = await _networkService.sendSyncBatch(clientDevice, syncBatch);
      print('Sent all data to client $clientDeviceId: ${success ? 'success' : 'failed'}');
    } catch (e) {
      print('Error sending data to client: $e');
    }
  }

  void dispose() {
    _syncTimer?.cancel();
  }
}
