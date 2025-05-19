import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../models/sync_model.dart';
import '../models/product_model.dart';
import '../models/history_model.dart';
import '../controllers/product_controller.dart';
import 'database_services.dart';
import 'network_service.dart';
import '../utils/windows_notification_util.dart';

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
  final int syncIntervalSeconds = 3; // Reduced to 3 seconds for more frequent syncing

  // Connection optimization
  bool _isFirstSync = true;
  DateTime? _lastSuccessfulSync;

  // Auto-sync settings
  final RxBool autoSyncEnabled = true.obs; // Enable auto-sync by default

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
      (_) => {
        if (autoSyncEnabled.value && _networkService.isConnectedToServer.value) {
          syncWithServer()
        }
      },
    );
    print('Sync timer started, will run every $syncIntervalSeconds seconds if auto-sync is enabled');
  }

  Future<void> _updatePendingSyncCount() async {
    final items = await _dbService.getPendingSyncItems();
    pendingSyncItems.value = items.length;
  }

  Future<void> syncWithServer() async {
    // If already syncing, return immediately instead of waiting
    if (isSyncing.value) {
      print('Sync already in progress, skipping this request');
      return;
    }

    isSyncing.value = true;
    syncStatus.value = 'Syncing...';
    print('Starting sync process');

    try {
      // Use a more aggressive caching strategy for faster reconnection
      final bool needsFullDiscovery = _isFirstSync ||
          (_lastSuccessfulSync == null ||
           DateTime.now().difference(_lastSuccessfulSync!).inMinutes > 10); // Increased from 5 to 10 minutes

      // Try to use cached server information first for faster connection
      if (!needsFullDiscovery && _networkService.isConnectedToServer.value) {
        final serverIp = _networkService.connectedServerIp.value;
        if (serverIp.isNotEmpty) {
          print('Using cached server connection: $serverIp');

          // Try to sync with the cached server first
          final cachedServerSync = await _syncWithCachedServer();
          if (cachedServerSync) {
            // Successfully synced with cached server, we're done
            print('Successfully synced with cached server');
            syncStatus.value = 'Synced successfully';
            isSyncing.value = false;
            _updatePendingSyncCount();
            return;
          }

          // If cached server sync failed, fall back to full discovery
          print('Cached server sync failed, falling back to discovery');
        }
      }

      // Perform device discovery if needed
      if (needsFullDiscovery) {
        try {
          print('Performing full device discovery...');
          await _networkService.discoverDevices();
          _isFirstSync = false;
        } catch (e) {
          print('Error discovering devices: $e');
          // Continue anyway
        }
      } else {
        // Do a quick discovery without scanning the entire network
        try {
          print('Performing quick device discovery...');
          // This will check recent connections and common IPs only
          await _networkService.discoverDevices();
        } catch (e) {
          print('Error in quick discovery: $e');
          // Continue anyway
        }
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

      // Try all servers in parallel for faster connection
      bool syncSuccess = false;
      String errorMessage = '';
      DeviceInfo? successfulServer;

      if (servers.isNotEmpty) {
        print('Trying to sync with ${servers.length} servers in parallel');

        // Create a completer to handle the first successful connection
        final completer = Completer<Map<String, dynamic>>();

        // Set up a timeout for all sync attempts
        final timeout = Timer(Duration(seconds: 5), () {
          if (!completer.isCompleted) {
            completer.complete({
              'success': false,
              'error': 'Timeout waiting for server response'
            });
          }
        });

        // Try all servers in parallel
        for (final server in servers) {
          _trySyncWithServer(server, testBatch).then((result) {
            // If this is the first successful connection, complete the completer
            if (result['success'] == true && !completer.isCompleted) {
              timeout.cancel();
              completer.complete(result);
            }
          }).catchError((e) {
            // Ignore individual errors, we'll handle the overall result
          });
        }

        // Wait for the first successful connection or timeout
        final result = await completer.future;

        if (result['success'] == true) {
          syncSuccess = true;
          successfulServer = result['server'] as DeviceInfo;

          // If we have pending items, update their status
          if (pendingItems.isNotEmpty) {
            for (final item in pendingItems) {
              await _dbService.updateSyncItemStatus(item.id, SyncStatus.completed);
            }
            syncStatus.value = 'Synced successfully';
          } else {
            syncStatus.value = 'Connected to server';
          }

          // Update last successful sync time
          _lastSuccessfulSync = DateTime.now();

          // Request all products from server to ensure we have the latest data
          await _requestLatestDataFromServer(successfulServer);
        } else {
          errorMessage = result['error'] as String? ?? 'Unknown error';
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

  // Try to sync with a cached server connection
  Future<bool> _syncWithCachedServer() async {
    try {
      final serverIp = _networkService.connectedServerIp.value;
      if (serverIp.isEmpty) return false;

      print('Attempting to sync with cached server at $serverIp');

      // Get pending sync items
      final pendingItems = await _dbService.getPendingSyncItems();

      // Create a test batch
      final testBatch = SyncBatch(
        id: const Uuid().v4(),
        deviceId: _networkService.deviceId,
        items: pendingItems.isEmpty ? [] : pendingItems,
        timestamp: DateTime.now(),
      );

      // Find the server in known devices
      final servers = await _networkService.getServerDevices();
      final cachedServer = servers.firstWhere(
        (server) => server.ipAddress == serverIp,
        orElse: () => DeviceInfo(
          id: 'cached-server',
          name: _networkService.connectedServerName.value,
          ipAddress: serverIp,
          port: _networkService.serverPort,
          role: DeviceRole.server,
          lastSeen: DateTime.now(),
        ),
      );

      // Try to send the batch
      final success = await _networkService.sendSyncBatch(cachedServer, testBatch);

      if (success) {
        // If we have pending items, update their status
        if (pendingItems.isNotEmpty) {
          for (final item in pendingItems) {
            await _dbService.updateSyncItemStatus(item.id, SyncStatus.completed);
          }
        }

        // Update last successful sync time
        _lastSuccessfulSync = DateTime.now();

        // Request all products from server
        await _requestLatestDataFromServer(cachedServer);

        return true;
      }

      return false;
    } catch (e) {
      print('Error syncing with cached server: $e');
      return false;
    }
  }

  // Try to sync with a specific server
  Future<Map<String, dynamic>> _trySyncWithServer(DeviceInfo server, SyncBatch batch) async {
    try {
      print('Attempting to sync with server: ${server.name} (${server.ipAddress})');
      final success = await _networkService.sendSyncBatch(server, batch);

      return {
        'server': server,
        'success': success,
        'error': success ? null : 'Failed to connect'
      };
    } catch (e) {
      print('Error syncing with server ${server.ipAddress}: $e');
      return {
        'server': server,
        'success': false,
        'error': 'Error: $e'
      };
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
            if (Platform.isWindows) {
              // Use Windows blue snackbar
              WindowsNotificationUtil.showSyncCompleted(batch.items.length);
            } else {
              // Use regular snackbar for other platforms
              Get.snackbar(
                'Data Updated',
                'Received ${batch.items.length} updates from server',
                duration: Duration(seconds: 2),
                snackPosition: SnackPosition.BOTTOM,
              );
            }
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
            print('Parsed product: ${product.name}, quantity: ${product.quantity ?? 0}, barcode: ${product.barcode}');

            // Check if product exists by barcode
            final existingProduct = await _dbService.getProductByBarcode(product.barcode);
            print('Existing product: ${existingProduct?.name}, quantity: ${existingProduct?.quantity ?? 0}');

            if (existingProduct == null) {
              // Add new product
              print('Adding new product: ${product.name}');
              await _dbService.addProduct(product);
            } else {
              // IMPORTANT: Preserve and merge quantities instead of overwriting
              // This ensures we don't lose data when syncing from clients to server
              final int existingQuantity = existingProduct.quantity ?? 0;
              final int incomingQuantity = product.quantity ?? 0;

              // If we're a server, we need to be careful about quantity updates
              int finalQuantity;
              if (_networkService.deviceRole == DeviceRole.server) {
                // On server: If incoming quantity is different, add the difference
                // This assumes the client is reporting a quantity change (like adding stock)
                if (incomingQuantity != existingQuantity) {
                  // Calculate the difference between incoming and what the client likely had before
                  // This is a heuristic approach - we assume the client is reporting a delta
                  final int quantityDifference = incomingQuantity - existingQuantity;
                  if (quantityDifference > 0) {
                    // If positive, it's likely new stock being added
                    finalQuantity = existingQuantity + quantityDifference;
                    print('Server detected quantity increase: +$quantityDifference units');
                  } else {
                    // If negative, it could be a rental or return - we keep our quantity
                    // as server data is considered authoritative
                    finalQuantity = existingQuantity;
                    print('Server ignoring quantity decrease to preserve data');
                  }
                } else {
                  // No quantity change, keep existing
                  finalQuantity = existingQuantity;
                }
              } else {
                // On client: Always take the server's quantity as authoritative
                finalQuantity = incomingQuantity;
              }

              // Update existing product with merged data
              final updatedProduct = existingProduct.copyWith(
                name: product.name,
                quantity: finalQuantity, // Use our calculated quantity
                pricePerQuantity: product.pricePerQuantity,
                photo: product.photo,
                unitType: product.unitType,
                size: product.size,
                color: product.color,
                material: product.material,
                weight: product.weight,
                rentPrice: product.rentPrice,
                updatedAt: product.updatedAt,
                syncId: product.syncId,
                lastSynced: DateTime.now(),
              );
              print('Updating product: ${updatedProduct.name}, new quantity: ${updatedProduct.quantity ?? 0}');
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

      // Create a special sync batch that requests all products
      final requestBatch = SyncBatch(
        id: const Uuid().v4(),
        deviceId: _networkService.deviceId,
        items: [], // Empty items list indicates we're just requesting data
        timestamp: DateTime.now(),
      );

      // Send request to server first to get latest data
      final success = await _networkService.sendSyncBatch(server, requestBatch);

      if (success) {
        print('Successfully requested data from server');

        // Then, send all our local products to the server in the background
        // This way we don't block the UI waiting for the upload to complete
        _sendAllLocalProductsToServer(server).then((_) {
          print('Finished sending local products to server in background');
        }).catchError((e) {
          print('Error sending local products in background: $e');
        });
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
