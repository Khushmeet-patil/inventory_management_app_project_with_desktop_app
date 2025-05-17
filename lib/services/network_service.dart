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

  // Connection status
  final RxBool isConnectedToServer = false.obs;
  final RxString connectedServerName = ''.obs;
  final RxString connectedServerIp = ''.obs;

  // Auto-discovery settings
  final int autoDiscoveryIntervalSeconds = 10; // Reduced from 30 to 10 seconds for faster reconnection
  Timer? _autoDiscoveryTimer;

  // Connection caching
  final Map<String, DateTime> _lastSuccessfulConnections = {};
  final Duration _connectionCacheValidity = Duration(minutes: 5);

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

    // Cancel any existing auto-discovery timer
    _autoDiscoveryTimer?.cancel();

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
    } else {
      // For clients, start auto-discovery timer
      _startAutoDiscovery();
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

      // Define API routes with security checks
      app.post('/sync', _secureHandler(_handleSyncRequest));
      app.get('/ping', _secureHandler(_handlePingRequest));
      app.get('/devices', _secureHandler(_handleGetDevicesRequest));

      // Add security middleware
      final handler = const shelf.Pipeline()
          .addMiddleware(shelf.logRequests())
          .addMiddleware(_securityMiddleware)
          .addHandler(app);

      // Try to bind to specific IP first
      try {
        if (ipAddress != null && ipAddress != '127.0.0.1' && ipAddress != '0.0.0.0') {
          _server = await shelf_io.serve(
            handler,
            InternetAddress(ipAddress!),
            serverPort,
            // Add security options
            securityContext: _createSecurityContext(),
          );
          print('Server started on specific IP: $ipAddress:$serverPort');

          // Firewall notification is now handled by WindowsSecurityUtil
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
          // Add security options
          securityContext: _createSecurityContext(),
        );
        print('Server started on all interfaces, port $serverPort');

        // Firewall notification is now handled by WindowsSecurityUtil
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

    // Also stop auto-discovery timer if it's running
    _autoDiscoveryTimer?.cancel();
  }

  // Start auto-discovery timer for clients
  void _startAutoDiscovery() {
    // Cancel any existing timer
    _autoDiscoveryTimer?.cancel();

    // Run discovery immediately
    _runAutoDiscovery();

    // Then set up periodic discovery
    _autoDiscoveryTimer = Timer.periodic(
      Duration(seconds: autoDiscoveryIntervalSeconds),
      (_) => _runAutoDiscovery(),
    );

    print('Auto-discovery timer started, will run every $autoDiscoveryIntervalSeconds seconds');
  }

  // Run the auto-discovery process
  Future<void> _runAutoDiscovery() async {
    if (deviceRole != DeviceRole.client) return;

    print('Running auto-discovery...');
    try {
      // First check if we're already connected to a server
      if (isConnectedToServer.value) {
        // Try to ping the server we're connected to
        final serverIp = connectedServerIp.value;
        if (serverIp.isNotEmpty) {
          final success = await pingDevice(serverIp, serverPort);
          if (success) {
            print('Still connected to server at $serverIp');
            return; // We're still connected, no need to discover
          } else {
            print('Lost connection to server at $serverIp, will try to discover new servers');
            isConnectedToServer.value = false;
            connectedServerName.value = '';
            connectedServerIp.value = '';
          }
        }
      }

      // Discover devices
      await discoverDevices();

      // Check if we found any servers
      final servers = knownDevices.where((d) => d.role == DeviceRole.server).toList();
      if (servers.isNotEmpty) {
        // Update connection status
        final server = servers.first;
        isConnectedToServer.value = true;
        connectedServerName.value = server.name;
        connectedServerIp.value = server.ipAddress;
        print('Connected to server: ${server.name} (${server.ipAddress})');
      } else {
        print('No servers found during auto-discovery');
      }
    } catch (e) {
      print('Error during auto-discovery: $e');
    }
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

    // Validate IP address format and security
    if (!_isValidIpAddress(ip) || !_isLocalNetworkAddress(ip)) {
      developer.log('Skipping non-local or invalid IP: $ip');
      return false;
    }

    // Check if we've successfully connected to this IP recently
    final cacheKey = '$ip:$port';
    final lastSuccess = _lastSuccessfulConnections[cacheKey];
    if (lastSuccess != null) {
      final timeSinceLastSuccess = DateTime.now().difference(lastSuccess);
      if (timeSinceLastSuccess < _connectionCacheValidity) {
        // We've connected to this IP recently, try it with higher priority
        developer.log('Recently connected to $ip:$port (${timeSinceLastSuccess.inSeconds}s ago)');
      }
    }

    try {
      developer.log('Pinging device at $ip:$port');

      // Try multiple times with shorter timeouts
      for (int attempt = 1; attempt <= 2; attempt++) {
        try {
          // Add security headers
          final headers = {
            'X-Client-ID': deviceId,
            'X-Client-Name': deviceName,
            'X-Client-Type': Platform.operatingSystem,
          };

          // Reduced timeout from seconds to milliseconds
          final response = await http.get(
            Uri.parse('http://$ip:$port/ping'),
            headers: headers,
          ).timeout(Duration(milliseconds: attempt == 1 ? 500 : 1000));

          if (response.statusCode == 200) {
            try {
              final data = jsonDecode(response.body);
              final device = DeviceInfo.fromMap(data);

              developer.log('Found device: ${device.name} (${device.ipAddress}) - Role: ${device.role == DeviceRole.server ? "Server" : "Client"}');

              // Don't add ourselves to the list
              if (device.id == deviceId) {
                return true;
              }

              // Update connection cache for faster reconnection
              final cacheKey = '$ip:$port';
              _lastSuccessfulConnections[cacheKey] = DateTime.now();

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

                // Update connection status immediately for faster UI feedback
                isConnectedToServer.value = true;
                connectedServerName.value = device.name;
                connectedServerIp.value = device.ipAddress;
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

    // Don't clear previous devices immediately to avoid UI flicker
    // We'll update them as we go
    final previousDevices = List<DeviceInfo>.from(knownDevices);
    final newDevices = <DeviceInfo>[];

    // Store self device info but don't add to the list shown to users
    final selfDevice = getLocalDeviceInfo();
    developer.log('Self device info: ${selfDevice.name} (${selfDevice.ipAddress})');

    // Only add self to known devices if we're a server
    // Clients don't need to see themselves in the list
    if (deviceRole == DeviceRole.server) {
      newDevices.add(selfDevice);
      developer.log('Added self (server) to known devices list');
    }

    final segments = ipAddress!.split('.');
    if (segments.length != 4) {
      developer.log('Invalid IP address format: $ipAddress');
      return knownDevices;
    }

    final baseIp = '${segments[0]}.${segments[1]}.${segments[2]}';
    developer.log('Scanning network with base IP: $baseIp');

    // First check recently successful connections
    final recentConnections = <String>[];
    _lastSuccessfulConnections.forEach((key, timestamp) {
      if (DateTime.now().difference(timestamp) < _connectionCacheValidity) {
        final parts = key.split(':');
        if (parts.length == 2) {
          final ip = parts[0];
          if (ip != ipAddress) {
            recentConnections.add(ip);
          }
        }
      }
    });

    // Try recent connections first with a short timeout
    if (recentConnections.isNotEmpty) {
      developer.log('Trying ${recentConnections.length} recent connections first');
      final recentFutures = <Future<bool>>[];

      for (final ip in recentConnections) {
        recentFutures.add(pingDevice(ip, serverPort));
      }

      // Wait for recent connections with a short timeout
      await Future.wait(recentFutures);

      // If we found a server, we can stop here
      if (knownDevices.any((device) => device.role == DeviceRole.server && device.id != deviceId)) {
        developer.log('Found server in recent connections, stopping discovery');
        return knownDevices;
      }
    }

    // Try common IPs (1, 100-105, 254) for faster discovery
    final commonIps = [1, 100, 101, 102, 103, 104, 105, 254];
    final commonFutures = <Future<bool>>[];

    for (int i in commonIps) {
      final ip = '$baseIp.$i';
      if (ip != ipAddress && !recentConnections.contains(ip)) {
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

    // If we still don't have a server, scan more IPs but in parallel batches
    if (!knownDevices.any((device) => device.role == DeviceRole.server && device.id != deviceId)) {
      developer.log('No server found yet, scanning more IPs in parallel');

      // Scan in parallel with multiple smaller batches
      final allFutures = <Future<bool>>[];
      final batchSize = 25; // Smaller batch size for more parallelism
      final totalBatches = 10; // Scan more IPs in parallel

      for (int batch = 0; batch < totalBatches; batch++) {
        final startRange = batch * batchSize + 1;
        final endRange = startRange + batchSize - 1;

        if (startRange > 254) break; // Don't exceed valid IP range

        developer.log('Preparing IP batch $startRange-$endRange');

        for (int i = startRange; i <= endRange && i <= 254; i++) {
          final ip = '$baseIp.$i';
          if (ip != ipAddress && !commonIps.contains(i) && !recentConnections.contains(ip)) {
            allFutures.add(pingDevice(ip, serverPort));
          }
        }
      }

      // Process all batches in parallel with a timeout
      if (allFutures.isNotEmpty) {
        developer.log('Scanning ${allFutures.length} IPs in parallel');
        await Future.wait(allFutures).timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            developer.log('IP scan timeout reached, continuing with discovered devices');
            return [];
          },
        );
      }
    }

    // Update the knownDevices list with new discoveries
    knownDevices.clear();
    knownDevices.addAll(newDevices);

    // Add any devices we found during scanning
    for (final device in previousDevices) {
      if (!knownDevices.any((d) => d.id == device.id)) {
        knownDevices.add(device);
      }
    }

    developer.log('Discovery complete. Found ${knownDevices.length} devices');
    return knownDevices;
  }

  Future<bool> sendSyncBatch(DeviceInfo targetDevice, SyncBatch batch) async {
    try {
      // Validate target device IP for security
      if (!_isValidIpAddress(targetDevice.ipAddress) || !_isLocalNetworkAddress(targetDevice.ipAddress)) {
        developer.log('Refusing to send data to non-local or invalid IP: ${targetDevice.ipAddress}');
        return false;
      }

      developer.log('Sending sync batch to ${targetDevice.name} at ${targetDevice.ipAddress}:${targetDevice.port}');

      // Update connection cache for this device
      final cacheKey = '${targetDevice.ipAddress}:${targetDevice.port}';
      _lastSuccessfulConnections[cacheKey] = DateTime.now();

      // Skip ping and try to send data directly for faster operation
      // This is more efficient since we'll know if it fails anyway

      // Try to send the sync batch
      final url = 'http://${targetDevice.ipAddress}:${targetDevice.port}/sync';
      developer.log('Sending request to: $url');

      try {
        // Add security headers
        final headers = {
          'Content-Type': 'application/json',
          'X-Client-ID': deviceId,
          'X-Client-Name': deviceName,
          'X-Client-Type': Platform.operatingSystem,
        };

        // Reduced timeout from 15 to 5 seconds for faster failure detection
        final response = await http.post(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(batch.toMap()),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          developer.log('Successfully sent sync batch to ${targetDevice.ipAddress}');
          return true;
        } else {
          developer.log('Failed to send sync batch. Status code: ${response.statusCode}');
          return false;
        }
      } catch (httpError) {
        developer.log('HTTP error sending sync batch: $httpError');

        // Try one more time with a different approach and shorter timeout
        try {
          developer.log('Trying alternative HTTP client for sync...');
          final client = http.Client();
          final request = http.Request('POST', Uri.parse(url));

          // Add security headers
          request.headers['Content-Type'] = 'application/json';
          request.headers['X-Client-ID'] = deviceId;
          request.headers['X-Client-Name'] = deviceName;
          request.headers['X-Client-Type'] = Platform.operatingSystem;
          request.body = jsonEncode(batch.toMap());

          // Reduced timeout from 20 to 8 seconds
          final streamedResponse = await client.send(request).timeout(const Duration(seconds: 8));
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

  // Security helper methods

  // Create a security context for HTTPS (if needed in the future)
  SecurityContext? _createSecurityContext() {
    // For now, return null as we're using HTTP
    // In a production app, you would set up SSL/TLS certificates here
    return null;
  }

  // Security middleware to validate requests
  shelf.Handler _securityMiddleware(shelf.Handler innerHandler) {
    return (shelf.Request request) async {
      // Check if request is from local network
      final remoteAddress = request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
      if (remoteAddress == null) {
        return shelf.Response.forbidden('Access denied: Cannot verify client');
      }

      final clientIp = remoteAddress.remoteAddress.address;

      // Only allow local network connections
      if (!_isLocalNetworkAddress(clientIp)) {
        print('Rejected connection from non-local IP: $clientIp');
        return shelf.Response.forbidden('Access denied: Only local network connections allowed');
      }

      // Rate limiting (simple implementation)
      // In a real app, you would use a more sophisticated rate limiter
      if (!_checkRateLimit(clientIp)) {
        return shelf.Response(
          429, // HTTP 429 Too Many Requests
          body: 'Too many requests',
          headers: {'Content-Type': 'text/plain'},
        );
      }

      // Continue to the actual handler
      return innerHandler(request);
    };
  }

  // Wrap handlers with security checks
  shelf.Handler _secureHandler(shelf.Handler handler) {
    return (shelf.Request request) async {
      try {
        // Add request validation here if needed
        return await handler(request);
      } catch (e) {
        print('Error in secure handler: $e');
        return shelf.Response.internalServerError(
          body: jsonEncode({'status': 'error', 'message': 'Internal server error'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    };
  }

  // Check if an IP address is on the local network
  bool _isLocalNetworkAddress(String ip) {
    // Allow localhost
    if (ip == '127.0.0.1' || ip == 'localhost' || ip == '::1') {
      return true;
    }

    try {
      final addr = InternetAddress(ip);

      // Check if it's a private network address
      // 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16
      if (addr.type == InternetAddressType.IPv4) {
        final parts = ip.split('.');
        if (parts.length == 4) {
          final first = int.parse(parts[0]);
          final second = int.parse(parts[1]);

          if (first == 10) return true; // 10.x.x.x
          if (first == 172 && second >= 16 && second <= 31) return true; // 172.16.x.x - 172.31.x.x
          if (first == 192 && second == 168) return true; // 192.168.x.x
        }
      }

      return false;
    } catch (e) {
      print('Error checking IP address: $e');
      return false;
    }
  }

  // Validate IP address format
  bool _isValidIpAddress(String ip) {
    if (ip.isEmpty) return false;

    try {
      // Check format using regex
      final ipRegex = RegExp(
        r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
      );

      if (!ipRegex.hasMatch(ip)) {
        return false;
      }

      // Additional validation by trying to parse it
      InternetAddress(ip);
      return true;
    } catch (e) {
      print('Invalid IP address format: $ip');
      return false;
    }
  }

  // Simple rate limiting
  final Map<String, int> _requestCounts = {};
  final Map<String, DateTime> _lastResetTime = {};

  bool _checkRateLimit(String clientIp) {
    final now = DateTime.now();

    // Reset counter if it's been more than a minute
    if (_lastResetTime.containsKey(clientIp)) {
      final lastReset = _lastResetTime[clientIp]!;
      if (now.difference(lastReset).inSeconds > 60) {
        _requestCounts[clientIp] = 0;
        _lastResetTime[clientIp] = now;
      }
    } else {
      _lastResetTime[clientIp] = now;
      _requestCounts[clientIp] = 0;
    }

    // Increment request count
    _requestCounts[clientIp] = (_requestCounts[clientIp] ?? 0) + 1;

    // Allow up to 100 requests per minute per IP
    return (_requestCounts[clientIp] ?? 0) <= 100;
  }

  // Firewall notification is now handled by WindowsSecurityUtil

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
