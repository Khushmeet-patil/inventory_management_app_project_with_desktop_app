import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/sync_model.dart';
import '../models/product_model.dart';
import 'database_services.dart';

class NetworkService {
  static final NetworkService instance = NetworkService._init();

  // Server properties
  HttpServer? _server;
  final int serverPort = 8080;
  bool isServerRunning = false;

  // Device properties
  final String deviceId = const Uuid().v4();
  String deviceName = Platform.localHostname;
  String? ipAddress;
  String? manualIpAddress; // For manual IP configuration
  DeviceRole deviceRole = DeviceRole.client;

  // Known devices
  final RxList<DeviceInfo> knownDevices = <DeviceInfo>[].obs;

  // Callbacks
  Function(SyncBatch)? onSyncBatchReceived;

  NetworkService._init();

  Future<void> initialize({
    required DeviceRole role,
    String? customDeviceName,
    String? customIpAddress,
    Function(SyncBatch)? syncBatchCallback,
  }) async {
    deviceRole = role;
    if (customDeviceName != null) {
      deviceName = customDeviceName;
    }
    onSyncBatchReceived = syncBatchCallback;

    // Set manual IP if provided
    if (customIpAddress != null && customIpAddress.isNotEmpty) {
      manualIpAddress = customIpAddress;
      ipAddress = customIpAddress;
      print('Using manual IP address: $ipAddress');
    } else {
      // Try to get IP address automatically
      try {
        final info = NetworkInfo();
        ipAddress = await info.getWifiIP();
        print('Detected IP address: $ipAddress');

        // Fallback to alternative methods if needed
        if (ipAddress == null || ipAddress!.isEmpty || ipAddress == '0.0.0.0') {
          ipAddress = await _getAlternativeIpAddress();
          print('Using alternative IP detection: $ipAddress');
        }
      } catch (e) {
        print('Error detecting IP address: $e');
        ipAddress = await _getAlternativeIpAddress();
      }
    }

    // Validate IP address
    if (ipAddress == null || ipAddress!.isEmpty || ipAddress == '0.0.0.0') {
      print('Warning: Could not detect a valid IP address');
      ipAddress = '127.0.0.1'; // Fallback to localhost
    }

    if (deviceRole == DeviceRole.server) {
      await startServer();
    }
  }

  Future<String?> _getAlternativeIpAddress() async {
    try {
      // Try to get network interfaces
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      // Look for a suitable interface (non-loopback, IPv4)
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.isLoopback &&
              addr.address != '0.0.0.0') {
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('Error in alternative IP detection: $e');
    }
    return null;
  }

  Future<void> startServer() async {
    if (isServerRunning) return;

    try {
      final app = Router();

      // Define API routes
      app.post('/sync', _handleSyncRequest);
      app.get('/ping', _handlePingRequest);
      app.get('/devices', _handleGetDevicesRequest);

      final handler = const shelf.Pipeline()
          .addMiddleware(shelf.logRequests())
          .addHandler(app);

      // Try to bind to specific IP first
      try {
        if (ipAddress != null && ipAddress != '127.0.0.1' && ipAddress != '0.0.0.0') {
          _server = await shelf_io.serve(
            handler,
            InternetAddress(ipAddress!),
            serverPort,
          );
          print('Server started on specific IP: $ipAddress:$serverPort');
        } else {
          throw Exception('IP address not suitable for binding');
        }
      } catch (specificIpError) {
        print('Could not bind to specific IP: $specificIpError');
        print('Trying to bind to all interfaces...');

        // Fallback to any IPv4 address
        _server = await shelf_io.serve(
          handler,
          InternetAddress.anyIPv4,
          serverPort,
        );
        print('Server started on all interfaces, port $serverPort');
      }

      isServerRunning = true;

      // Print all server addresses for debugging
      try {
        final interfaces = await NetworkInterface.list(
          includeLoopback: false,
          type: InternetAddressType.IPv4,
        );

        print('Server is accessible at:');
        for (var interface in interfaces) {
          for (var addr in interface.addresses) {
            print('  http://${addr.address}:$serverPort');
          }
        }
      } catch (e) {
        print('Could not list network interfaces: $e');
      }
    } catch (e) {
      print('Failed to start server: $e');
      isServerRunning = false;
    }
  }

  Future<void> stopServer() async {
    if (!isServerRunning || _server == null) return;

    await _server!.close(force: true);
    _server = null;
    isServerRunning = false;
    print('Server stopped');
  }

  // Server API handlers

  Future<shelf.Response> _handleSyncRequest(shelf.Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final syncBatch = SyncBatch.fromMap(data);

      developer.log('Received sync request from device ${syncBatch.deviceId} with ${syncBatch.items.length} items');

      // If this is a server and the batch has no items, it's a request for all products
      if (deviceRole == DeviceRole.server && syncBatch.items.isEmpty) {
        developer.log('Received request for all products from client ${syncBatch.deviceId}');
        await _sendAllProductsToClient(syncBatch.deviceId);
      }

      if (onSyncBatchReceived != null) {
        onSyncBatchReceived!(syncBatch);
      }

      return shelf.Response.ok(
        jsonEncode({'status': 'success', 'message': 'Sync batch received'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      developer.log('Error handling sync request: $e');
      return shelf.Response.internalServerError(
        body: jsonEncode({'status': 'error', 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  shelf.Response _handlePingRequest(shelf.Request request) {
    final deviceInfo = {
      'id': deviceId,
      'name': deviceName,
      'ip_address': ipAddress,
      'port': serverPort,
      'role': deviceRole.index,
      'last_seen': DateTime.now().toIso8601String(),
    };

    return shelf.Response.ok(
      jsonEncode(deviceInfo),
      headers: {'Content-Type': 'application/json'},
    );
  }

  shelf.Response _handleGetDevicesRequest(shelf.Request request) {
    final devices = knownDevices.map((device) => device.toMap()).toList();

    return shelf.Response.ok(
      jsonEncode(devices),
      headers: {'Content-Type': 'application/json'},
    );
  }

  // Client methods

  Future<bool> pingDevice(String ip, int port) async {
    // Skip invalid IPs
    if (ip == '0.0.0.0' || ip == '127.0.0.1' || ip.isEmpty) {
      return false;
    }

    try {
      developer.log('Pinging device at $ip:$port');

      // Try multiple times with increasing timeouts
      for (int attempt = 1; attempt <= 2; attempt++) {
        try {
          final response = await http.get(
            Uri.parse('http://$ip:$port/ping'),
          ).timeout(Duration(seconds: attempt));

          if (response.statusCode == 200) {
            try {
              final data = jsonDecode(response.body);
              final device = DeviceInfo.fromMap(data);

              developer.log('Found device: ${device.name} (${device.ipAddress}) - Role: ${device.role == DeviceRole.server ? "Server" : "Client"}');

              // Don't add ourselves to the list
              if (device.id == deviceId) {
                return true;
              }

              // Update known devices
              final existingIndex = knownDevices.indexWhere((d) => d.id == device.id);
              if (existingIndex >= 0) {
                knownDevices[existingIndex] = device;
              } else {
                knownDevices.add(device);
              }

              // If this is a server, make sure to save it to the database
              if (device.role == DeviceRole.server) {
                developer.log('Found a server! ${device.name} (${device.ipAddress})');
              }

              return true;
            } catch (e) {
              developer.log('Error parsing device data from $ip: $e');
              // Continue to next attempt
            }
          }
        } catch (e) {
          // This is expected for most IPs, so we'll only log in debug mode
          if (kDebugMode && attempt == 2) {
            developer.log('Failed ping attempt $attempt to $ip:$port');
          }
          // Continue to next attempt
        }
      }

      return false;
    } catch (e) {
      developer.log('Unexpected error pinging device at $ip:$port: $e');
      return false;
    }
  }

  Future<List<DeviceInfo>> discoverDevices() async {
    if (ipAddress == null) return [];

    // Clear previous devices
    knownDevices.clear();

    // Store self device info but don't add to the list shown to users
    final selfDevice = getLocalDeviceInfo();
    developer.log('Self device info: ${selfDevice.name} (${selfDevice.ipAddress})');

    // Only add self to known devices if we're a server
    // Clients don't need to see themselves in the list
    if (deviceRole == DeviceRole.server) {
      knownDevices.add(selfDevice);
      developer.log('Added self (server) to known devices list');
    }

    final segments = ipAddress!.split('.');
    if (segments.length != 4) {
      developer.log('Invalid IP address format: $ipAddress');
      return knownDevices;
    }

    final baseIp = '${segments[0]}.${segments[1]}.${segments[2]}';
    developer.log('Scanning network with base IP: $baseIp');

    // First try common IPs (1, 100-105, 254) for faster discovery
    final commonIps = [1, 100, 101, 102, 103, 104, 105, 254];
    final commonFutures = <Future<bool>>[];

    for (int i in commonIps) {
      final ip = '$baseIp.$i';
      if (ip != ipAddress) {
        commonFutures.add(pingDevice(ip, serverPort));
      }
    }

    // Wait for common IPs to respond
    await Future.wait(commonFutures);

    // If we found a server, we can stop here
    if (knownDevices.any((device) => device.role == DeviceRole.server && device.id != deviceId)) {
      developer.log('Found server in common IPs, stopping discovery');
      return knownDevices;
    }

    // If manual IP is provided, try that specifically
    if (manualIpAddress != null && manualIpAddress != ipAddress) {
      developer.log('Trying manual IP: $manualIpAddress');
      await pingDevice(manualIpAddress!, serverPort);
    }

    // If we still don't have a server, scan more IPs
    if (!knownDevices.any((device) => device.role == DeviceRole.server && device.id != deviceId)) {
      developer.log('No server found yet, scanning more IPs');

      // Try to scan the entire subnet in batches to avoid overwhelming the network
      for (int batch = 0; batch < 5; batch++) {
        final futures = <Future<bool>>[];
        final startRange = batch * 50 + 1;
        final endRange = startRange + 49;

        developer.log('Scanning IP range $startRange-$endRange');

        for (int i = startRange; i <= endRange; i++) {
          if (i > 254) break; // Valid IP range is 1-254

          final ip = '$baseIp.$i';
          if (ip != ipAddress && !commonIps.contains(i)) {
            futures.add(pingDevice(ip, serverPort));
          }
        }

        // Wait for this batch to complete
        await Future.wait(futures);

        // If we found a server, we can stop scanning
        if (knownDevices.any((device) => device.role == DeviceRole.server && device.id != deviceId)) {
          developer.log('Found server, stopping IP scan');
          break;
        }
      }
    }

    developer.log('Discovery complete. Found ${knownDevices.length} devices');
    return knownDevices;
  }

  Future<bool> sendSyncBatch(DeviceInfo targetDevice, SyncBatch batch) async {
    try {
      developer.log('Sending sync batch to ${targetDevice.name} at ${targetDevice.ipAddress}:${targetDevice.port}');

      // First try to ping the device to make sure it's reachable
      final pingSuccess = await pingDevice(targetDevice.ipAddress, targetDevice.port);
      if (!pingSuccess) {
        developer.log('Warning: Could not ping device before sending sync batch. Will try anyway.');
        // Continue anyway - sometimes ping fails but HTTP works
      }

      // Try to send the sync batch
      final url = 'http://${targetDevice.ipAddress}:${targetDevice.port}/sync';
      developer.log('Sending request to: $url');

      try {
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(batch.toMap()),
        ).timeout(const Duration(seconds: 15)); // Increased timeout

        if (response.statusCode == 200) {
          developer.log('Successfully sent sync batch to ${targetDevice.ipAddress}');
          return true;
        } else {
          developer.log('Failed to send sync batch. Status code: ${response.statusCode}');
          return false;
        }
      } catch (httpError) {
        developer.log('HTTP error sending sync batch: $httpError');

        // Try one more time with a different approach
        try {
          developer.log('Trying alternative HTTP client for sync...');
          final client = http.Client();
          final request = http.Request('POST', Uri.parse(url));
          request.headers['Content-Type'] = 'application/json';
          request.body = jsonEncode(batch.toMap());

          final streamedResponse = await client.send(request).timeout(const Duration(seconds: 20));
          final response = await http.Response.fromStream(streamedResponse);
          client.close();

          if (response.statusCode == 200) {
            developer.log('Alternative HTTP method succeeded!');
            return true;
          } else {
            developer.log('Alternative HTTP method failed. Status: ${response.statusCode}');
            return false;
          }
        } catch (retryError) {
          developer.log('Retry also failed: $retryError');
          return false;
        }
      }
    } catch (e) {
      developer.log('Error sending sync batch: $e');
      return false;
    }
  }

  Future<List<DeviceInfo>> getServerDevices() async {
    // Filter out devices with the same ID as this device
    final servers = knownDevices.where((device) =>
      device.role == DeviceRole.server && device.id != deviceId
    ).toList();

    developer.log('Found ${servers.length} server devices: ${servers.map((s) => "${s.name} (${s.ipAddress})").join(", ")}');
    return servers;
  }

  DeviceInfo getLocalDeviceInfo() {
    return DeviceInfo(
      id: deviceId,
      name: deviceName,
      ipAddress: ipAddress ?? '127.0.0.1',
      port: serverPort,
      role: deviceRole,
      lastSeen: DateTime.now(),
    );
  }

  Future<void> _sendAllProductsToClient(String clientDeviceId) async {
    try {
      // Use DatabaseService directly
      final dbService = DatabaseService.instance;

      // Get all products from database
      final products = await dbService.getAllProducts();
      developer.log('Sending ${products.length} products to client $clientDeviceId');

      if (products.isEmpty) {
        developer.log('No products to send to client');
        return;
      }

      // Find the client device
      DeviceInfo? clientDevice;
      try {
        clientDevice = knownDevices.firstWhere(
          (device) => device.id == clientDeviceId,
        );
      } catch (e) {
        developer.log('Client device not found in known devices, searching in database...');

        // Try to find the device in the database
        final dbDevices = await dbService.getAllDevices();
        try {
          clientDevice = dbDevices.firstWhere(
            (device) => device.id == clientDeviceId,
          );
          developer.log('Found client device in database: ${clientDevice.name} (${clientDevice.ipAddress})');

          // Add to known devices for future use
          if (!knownDevices.any((d) => d.id == clientDevice!.id)) {
            knownDevices.add(clientDevice!);
          }
        } catch (dbError) {
          developer.log('Client device not found in database either: $dbError');
          return;
        }
      }

      if (clientDevice == null) {
        developer.log('Could not find client device with ID: $clientDeviceId');
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
        deviceId: deviceId,
        items: syncItems,
        timestamp: DateTime.now(),
      );

      // Send the batch to the client
      developer.log('Attempting to send ${syncItems.length} products to client ${clientDevice.name} at ${clientDevice.ipAddress}');
      final success = await sendSyncBatch(clientDevice, syncBatch);
      developer.log('Sent all products to client $clientDeviceId: ${success ? 'success' : 'failed'}');
    } catch (e) {
      developer.log('Error sending all products to client: $e');
    }
  }
}
