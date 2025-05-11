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
  final int syncIntervalSeconds = 30;

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
    if (isSyncing.value) return;

    isSyncing.value = true;
    syncStatus.value = 'Syncing...';
    print('Starting sync process');

    try {
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
      } else {
        // We're a server processing items from a client
        print('Server processing ${batch.items.length} items from client');

        // Process normal sync items
        for (final item in batch.items) {
          await _processSyncItem(item);
        }

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
            final history = ProductHistory.fromMap(historyData);
            print('Adding history entry for product: ${history.productName}, quantity: ${history.quantity}');
            await _dbService.addHistory(history);
            print('History entry added successfully');
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
    // Get all client devices
    final clients = _networkService.knownDevices
        .where((device) =>
            device.role == DeviceRole.client &&
            device.id != originalBatch.deviceId)
        .toList();

    print('Found ${clients.length} clients to propagate changes to');
    if (clients.isEmpty) return;

    // Send to each client
    for (final client in clients) {
      print('Propagating changes to client: ${client.name} (${client.ipAddress})');
      final success = await _networkService.sendSyncBatch(client, originalBatch);
      print('Propagation to ${client.name} ${success ? 'successful' : 'failed'}');
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
      print('Sending all local products to server: ${server.name} (${server.ipAddress})');

      // Get all products from database
      final products = await _dbService.getAllProducts();
      print('Found ${products.length} local products to send to server');

      if (products.isEmpty) {
        print('No local products to send');
        return;
      }

      // Create sync items for each product
      final syncItems = products.map((product) {
        return SyncItem.fromProduct(product, SyncOperation.update);
      }).toList();

      // Create a sync batch with all products
      final syncBatch = SyncBatch(
        id: const Uuid().v4(),
        deviceId: _networkService.deviceId,
        items: syncItems,
        timestamp: DateTime.now(),
      );

      // Send to server
      final success = await _networkService.sendSyncBatch(server, syncBatch);

      if (success) {
        print('Successfully sent all local products to server');
      } else {
        print('Failed to send local products to server');
      }
    } catch (e) {
      print('Error sending local products to server: $e');
    }
  }

  Future<void> _reloadProductData() async {
    try {
      // Try to find the ProductController instance
      if (Get.isRegistered<ProductController>()) {
        final controller = Get.find<ProductController>();
        print('Reloading product data in ProductController');
        await controller.loadData();
      } else {
        print('No ProductController instance found to reload data');
      }
    } catch (e) {
      print('Error reloading product data: $e');
    }
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
      print('Preparing to send all products to client: $clientDeviceId');

      // Get all products from database
      final products = await _dbService.getAllProducts();
      print('Found ${products.length} products to send to client');

      if (products.isEmpty) {
        print('No products to send to client');
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

      // Create sync items for each product
      final syncItems = products.map((product) {
        return SyncItem(
          id: const Uuid().v4(),
          entityId: product.syncId ?? product.id.toString(),
          entityType: 'product',
          operation: SyncOperation.update,
          data: product.toMap(),
          timestamp: DateTime.now(),
        );
      }).toList();

      // Create a sync batch with all products
      final syncBatch = SyncBatch(
        id: const Uuid().v4(),
        deviceId: _networkService.deviceId,
        items: syncItems,
        timestamp: DateTime.now(),
      );

      // Send the batch to the client
      print('Sending ${syncItems.length} products to client ${clientDevice.name} at ${clientDevice.ipAddress}');
      final success = await _networkService.sendSyncBatch(clientDevice, syncBatch);
      print('Sent all products to client $clientDeviceId: ${success ? 'success' : 'failed'}');
    } catch (e) {
      print('Error sending products to client: $e');
    }
  }

  void dispose() {
    _syncTimer?.cancel();
  }
}
