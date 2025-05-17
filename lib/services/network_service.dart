import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
import 'dart:typed_data';
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
  final int autoDiscoveryIntervalSeconds = 3; // Reduced from 5 to 3 seconds for faster reconnection
  Timer? _autoDiscoveryTimer;

  // Adaptive discovery interval
  int _currentDiscoveryInterval = 3; // Start with 3 seconds
  int _consecutiveFailedDiscoveries = 0;
  int _consecutiveSuccessfulDiscoveries = 0;

  // Connection caching
  final Map<String, DateTime> _lastSuccessfulConnections = {};
  final Duration _connectionCacheValidity = Duration(minutes: 10); // Extended from 5 to 10 minutes

  // UDP broadcast socket for discovery
  RawDatagramSocket? _udpDiscoverySocket;
  Timer? _udpBroadcastTimer;

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
      // Even for server, start a discovery timer to find clients
      _startAutoDiscovery();
    } else {
      // For clients, start auto-discovery timer with more aggressive settings
      _startAutoDiscovery(isClient: true);

      // Immediately try to discover servers
      _runAutoDiscovery(isClient: true, isInitialDiscovery: true);
    }
  }

  Future<String?> _getAlternativeIpAddress() async {
    try {
      // Try to get network interfaces
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      // Prioritize interfaces in this order: Wi-Fi, Ethernet, others
      // Common Wi-Fi interface names
      final wifiNames = ['wlan', 'wifi', 'wlp', 'wireless', 'en0'];
      // Common Ethernet interface names
      final ethernetNames = ['eth', 'ethernet', 'en1', 'eno', 'enp'];

      String? wifiAddress;
      String? ethernetAddress;
      String? otherAddress;

      // First pass: categorize interfaces
      for (var interface in interfaces) {
        final name = interface.name.toLowerCase();

        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.isLoopback &&
              addr.address != '0.0.0.0') {

            // Check if this is a private network address (more likely to be useful)
            final isPrivate = _isLocalNetworkAddress(addr.address);
            if (!isPrivate) continue;

            // Categorize by interface type
            if (wifiNames.any((wifiName) => name.contains(wifiName))) {
              wifiAddress ??= addr.address;
              print('Found Wi-Fi address: ${addr.address} on ${interface.name}');
            } else if (ethernetNames.any((ethName) => name.contains(ethName))) {
              ethernetAddress ??= addr.address;
              print('Found Ethernet address: ${addr.address} on ${interface.name}');
            } else {
              otherAddress ??= addr.address;
              print('Found other address: ${addr.address} on ${interface.name}');
            }
          }
        }
      }

      // Return the best address found, prioritizing Wi-Fi > Ethernet > Others
      return wifiAddress ?? ethernetAddress ?? otherAddress;
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

      // Start UDP discovery listener for faster client discovery
      _startUdpDiscoveryListener();

      // Broadcast server presence immediately to help clients find it faster
      _broadcastServerPresence();

    } catch (e) {
      print('Failed to start server: $e');
      isServerRunning = false;
    }
  }

  // Listen for UDP discovery broadcasts from clients
  Future<void> _startUdpDiscoveryListener() async {
    try {
      // Only servers should listen for discovery broadcasts
      if (deviceRole != DeviceRole.server) return;

      print('Starting UDP discovery listener on port $serverPort');
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, serverPort);

      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            try {
              final message = String.fromCharCodes(datagram.data);
              print('Received UDP message from ${datagram.address.address}: $message');

              try {
                final data = jsonDecode(message);

                // Handle discovery requests
                if (data['action'] == 'discovery') {
                  // This is a discovery request, send a response
                  final response = jsonEncode({
                    'id': deviceId,
                    'name': deviceName,
                    'role': deviceRole.index,
                    'port': serverPort,
                    'last_seen': DateTime.now().toIso8601String(),
                  });

                  // Send response directly back to the client
                  socket.send(
                    utf8.encode(response),
                    datagram.address,
                    datagram.port
                  );
                  print('Sent UDP response to ${datagram.address.address}:${datagram.port}');

                  // Also add the client to known devices if it's not already there
                  if (data['id'] != null && data['id'] != deviceId) {
                    final clientDevice = DeviceInfo(
                      id: data['id'],
                      name: data['name'] ?? 'Unknown Client',
                      ipAddress: datagram.address.address,
                      port: data['port'] ?? serverPort,
                      role: DeviceRole.client, // Assume it's a client since it's discovering
                      lastSeen: DateTime.now(),
                    );

                    // Add to known devices if not already there
                    if (!knownDevices.any((d) => d.id == clientDevice.id)) {
                      knownDevices.add(clientDevice);
                      print('Added client from UDP discovery: ${clientDevice.name} (${clientDevice.ipAddress})');
                    }
                  }
                }
                // Handle server announcements
                else if (data['action'] == 'server_announcement') {
                  // This is a server announcing its presence
                  if (data['id'] != null && data['id'] != deviceId) {
                    final serverDevice = DeviceInfo(
                      id: data['id'],
                      name: data['name'] ?? 'Unknown Server',
                      ipAddress: datagram.address.address,
                      port: data['port'] ?? serverPort,
                      role: DeviceRole.server,
                      lastSeen: DateTime.now(),
                    );

                    // Process the server device
                    _processDiscoveredDevice(serverDevice);
                    print('Received server announcement from: ${serverDevice.name} (${serverDevice.ipAddress})');

                    // If we're a client, update connection status immediately
                    if (deviceRole == DeviceRole.client) {
                      isConnectedToServer.value = true;
                      connectedServerName.value = serverDevice.name;
                      connectedServerIp.value = serverDevice.ipAddress;
                    }
                  }
                }
              } catch (e) {
                print('Error parsing UDP message: $e');
              }
            } catch (e) {
              print('Error processing UDP datagram: $e');
            }
          }
        }
      });

      print('UDP discovery listener started successfully');
    } catch (e) {
      print('Error starting UDP discovery listener: $e');
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
  void _startAutoDiscovery({bool isClient = false}) {
    // Cancel any existing timer
    _autoDiscoveryTimer?.cancel();

    // Run discovery immediately
    _runAutoDiscovery(isClient: isClient);

    // Then set up periodic discovery with adaptive interval
    _scheduleNextDiscovery(isClient: isClient);

    print('Auto-discovery timer started with adaptive interval');

    // For servers, also start a UDP broadcast timer to announce presence
    if (deviceRole == DeviceRole.server) {
      _startServerBroadcastTimer();
    }
  }

  // Start a timer to periodically broadcast server presence
  void _startServerBroadcastTimer() {
    // Cancel any existing timer
    _udpBroadcastTimer?.cancel();

    // Broadcast every 3 seconds
    _udpBroadcastTimer = Timer.periodic(
      Duration(seconds: 3),
      (_) => _broadcastServerPresence(),
    );

    print('Server broadcast timer started');
  }

  // Schedule the next discovery with adaptive interval
  void _scheduleNextDiscovery({bool isClient = false}) {
    // Cancel any existing timer
    _autoDiscoveryTimer?.cancel();

    // Calculate the next interval based on success/failure pattern
    int nextInterval = _currentDiscoveryInterval;

    // For clients, use more aggressive settings
    if (isClient) {
      // If we're connected to a server, use a longer interval
      if (isConnectedToServer.value) {
        // Gradually increase the interval up to 20 seconds if we have consistent success
        if (_consecutiveSuccessfulDiscoveries > 3) {
          nextInterval = _currentDiscoveryInterval + 3;
          if (nextInterval > 20) nextInterval = 20; // Cap at 20 seconds for clients
          _currentDiscoveryInterval = nextInterval;
        }
      } else {
        // If we're not connected, use a shorter interval
        if (_consecutiveFailedDiscoveries > 1) {
          // After multiple failures, reduce the interval to find a server faster
          nextInterval = _currentDiscoveryInterval - 1;
          if (nextInterval < 2) nextInterval = 2; // Minimum 2 seconds for clients
          _currentDiscoveryInterval = nextInterval;
        }
      }
    } else {
      // For servers, use standard settings
      if (_consecutiveSuccessfulDiscoveries > 3) {
        nextInterval = _currentDiscoveryInterval + 5;
        if (nextInterval > 30) nextInterval = 30; // Cap at 30 seconds
        _currentDiscoveryInterval = nextInterval;
      } else if (_consecutiveFailedDiscoveries > 2) {
        nextInterval = _currentDiscoveryInterval - 1;
        if (nextInterval < 3) nextInterval = 3; // Minimum 3 seconds
        _currentDiscoveryInterval = nextInterval;
      }
    }

    print('Scheduling next discovery in $nextInterval seconds');

    // Schedule the next discovery
    _autoDiscoveryTimer = Timer(Duration(seconds: nextInterval), () {
      _runAutoDiscovery(isClient: isClient);
      // Schedule the next one after this completes
      _scheduleNextDiscovery(isClient: isClient);
    });
  }

  // Run the auto-discovery process
  Future<void> _runAutoDiscovery({bool isClient = false, bool isInitialDiscovery = false}) async {
    // For servers, only run discovery if explicitly requested
    if (deviceRole == DeviceRole.server && !isClient) {
      // For servers, just broadcast presence
      _broadcastServerPresence();
      return;
    }

    print('Running auto-discovery...');
    bool discoverySuccess = false;

    try {
      // First check if we're already connected to a server
      if (isConnectedToServer.value) {
        // Try to ping the server we're connected to
        final serverIp = connectedServerIp.value;
        if (serverIp.isNotEmpty) {
          final success = await pingDevice(serverIp, serverPort);
          if (success) {
            print('Still connected to server at $serverIp');
            _consecutiveSuccessfulDiscoveries++;
            _consecutiveFailedDiscoveries = 0;
            discoverySuccess = true;
            return; // We're still connected, no need to discover
          } else {
            print('Lost connection to server at $serverIp, will try to discover new servers');
            isConnectedToServer.value = false;
            connectedServerName.value = '';
            connectedServerIp.value = '';
            _consecutiveFailedDiscoveries++;
            _consecutiveSuccessfulDiscoveries = 0;
          }
        }
      }

      // Try UDP broadcast discovery first (fastest method)
      try {
        // Use a more aggressive approach for clients or initial discovery
        if (isClient || isInitialDiscovery) {
          // Try multiple UDP broadcasts with short delays between them
          for (int i = 0; i < 3; i++) {
            await _discoverViaUdpBroadcast();

            // Check if we found any servers through UDP broadcast
            final serversFromUdp = knownDevices.where((d) => d.role == DeviceRole.server && d.id != deviceId).toList();
            if (serversFromUdp.isNotEmpty) {
              // Update connection status
              final server = serversFromUdp.first;
              isConnectedToServer.value = true;
              connectedServerName.value = server.name;
              connectedServerIp.value = server.ipAddress;
              print('Connected to server via UDP broadcast: ${server.name} (${server.ipAddress})');
              _consecutiveSuccessfulDiscoveries++;
              _consecutiveFailedDiscoveries = 0;
              discoverySuccess = true;
              return; // Found server via UDP, no need for further discovery
            }

            // Short delay before trying again
            if (i < 2) await Future.delayed(Duration(milliseconds: 200));
          }
        } else {
          // Standard approach
          await _discoverViaUdpBroadcast();

          // Check if we found any servers through UDP broadcast
          final serversFromUdp = knownDevices.where((d) => d.role == DeviceRole.server && d.id != deviceId).toList();
          if (serversFromUdp.isNotEmpty) {
            // Update connection status
            final server = serversFromUdp.first;
            isConnectedToServer.value = true;
            connectedServerName.value = server.name;
            connectedServerIp.value = server.ipAddress;
            print('Connected to server via UDP broadcast: ${server.name} (${server.ipAddress})');
            _consecutiveSuccessfulDiscoveries++;
            _consecutiveFailedDiscoveries = 0;
            discoverySuccess = true;
            return; // Found server via UDP, no need for further discovery
          }
        }
      } catch (e) {
        print('UDP broadcast discovery failed: $e');
        // Continue with regular discovery
      }

      // Regular device discovery as fallback
      await discoverDevices();

      // Check if we found any servers
      final servers = knownDevices.where((d) => d.role == DeviceRole.server && d.id != deviceId).toList();
      if (servers.isNotEmpty) {
        // Update connection status
        final server = servers.first;
        isConnectedToServer.value = true;
        connectedServerName.value = server.name;
        connectedServerIp.value = server.ipAddress;
        print('Connected to server: ${server.name} (${server.ipAddress})');
        _consecutiveSuccessfulDiscoveries++;
        _consecutiveFailedDiscoveries = 0;
        discoverySuccess = true;
      } else {
        print('No servers found during auto-discovery');
        _consecutiveFailedDiscoveries++;
        _consecutiveSuccessfulDiscoveries = 0;
      }
    } catch (e) {
      print('Error during auto-discovery: $e');
      _consecutiveFailedDiscoveries++;
      _consecutiveSuccessfulDiscoveries = 0;
    }

    // Update discovery success tracking
    if (!discoverySuccess) {
      _consecutiveFailedDiscoveries++;
      _consecutiveSuccessfulDiscoveries = 0;
    }
  }

  // Server API handlers

  Future<shelf.Response> _handleSyncRequest(shelf.Request request) async {
    try {
      // Check for compression header
      final contentEncoding = request.headers['x-content-encoding'];
      final isCompressed = contentEncoding == 'gzip';

      SyncBatch syncBatch;

      if (isCompressed) {
        // Handle compressed data
        developer.log('Received compressed sync data');
        final compressedBytes = await request.read().expand((chunk) => chunk).toList();
        final decompressedBytes = gzip.decode(compressedBytes);
        final decompressedJson = utf8.decode(decompressedBytes);
        final data = jsonDecode(decompressedJson);
        syncBatch = SyncBatch.fromMap(data);
      } else {
        // Handle regular JSON data
        final payload = await request.readAsString();
        final data = jsonDecode(payload);
        syncBatch = SyncBatch.fromMap(data);
      }

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

      // Create a completer to handle the first successful response
      final completer = Completer<bool>();

      // Try multiple approaches in parallel for faster discovery
      // 1. Fast HTTP ping with very short timeout
      // 2. UDP ping (faster but less reliable)
      // 3. Standard HTTP ping with longer timeout as fallback

      // 1. Fast HTTP ping
      _fastHttpPing(ip, port).then((success) {
        if (success && !completer.isCompleted) {
          completer.complete(true);
        }
      }).catchError((_) {});

      // 2. UDP ping (even faster)
      _udpPing(ip, port).then((success) {
        if (success && !completer.isCompleted) {
          completer.complete(true);
        }
      }).catchError((_) {});

      // 3. Standard HTTP ping as fallback
      _standardHttpPing(ip, port).then((success) {
        if (success && !completer.isCompleted) {
          completer.complete(true);
        } else if (!completer.isCompleted) {
          completer.complete(false);
        }
      }).catchError((e) {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });

      // Wait for the first successful response or all to fail
      return await completer.future.timeout(
        Duration(milliseconds: 1500),
        onTimeout: () {
          developer.log('Ping timeout for $ip:$port');
          return false;
        },
      );
    } catch (e) {
      developer.log('Unexpected error pinging device at $ip:$port: $e');
      return false;
    }
  }

  // Fast HTTP ping with minimal timeout
  Future<bool> _fastHttpPing(String ip, int port) async {
    try {
      // Add security headers
      final headers = {
        'X-Client-ID': deviceId,
        'X-Client-Name': deviceName,
        'X-Client-Type': Platform.operatingSystem,
      };

      // Very short timeout for quick response
      final response = await http.get(
        Uri.parse('http://$ip:$port/ping'),
        headers: headers,
      ).timeout(Duration(milliseconds: 300));

      if (response.statusCode == 200) {
        return await _processSuccessfulPingResponse(ip, port, response.body);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Standard HTTP ping with longer timeout
  Future<bool> _standardHttpPing(String ip, int port) async {
    try {
      // Add security headers
      final headers = {
        'X-Client-ID': deviceId,
        'X-Client-Name': deviceName,
        'X-Client-Type': Platform.operatingSystem,
      };

      // Longer timeout as fallback
      final response = await http.get(
        Uri.parse('http://$ip:$port/ping'),
        headers: headers,
      ).timeout(Duration(milliseconds: 1000));

      if (response.statusCode == 200) {
        return await _processSuccessfulPingResponse(ip, port, response.body);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // UDP ping (faster but less reliable)
  Future<bool> _udpPing(String ip, int port) async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final completer = Completer<bool>();

      // Set up a timeout
      final timeout = Timer(Duration(milliseconds: 300), () {
        if (!completer.isCompleted) {
          socket.close();
          completer.complete(false);
        }
      });

      // Listen for responses
      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null && datagram.address.address == ip) {
            try {
              final response = String.fromCharCodes(datagram.data);
              try {
                final data = jsonDecode(response);
                if (data['id'] != null && !completer.isCompleted) {
                  // Create a device info object from the response
                  final device = DeviceInfo(
                    id: data['id'],
                    name: data['name'] ?? 'Unknown Device',
                    ipAddress: ip,
                    port: data['port'] ?? port,
                    role: DeviceRole.values[data['role'] as int],
                    lastSeen: DateTime.now(),
                  );

                  // Process the device info
                  _processDiscoveredDevice(device);

                  // Complete the future
                  timeout.cancel();
                  socket.close();
                  completer.complete(true);
                }
              } catch (e) {
                // Ignore parsing errors
              }
            } catch (e) {
              // Ignore processing errors
            }
          }
        }
      });

      // Send ping message
      final pingMessage = jsonEncode({
        'id': deviceId,
        'name': deviceName,
        'role': deviceRole.index,
        'action': 'ping',
      });

      socket.send(
        utf8.encode(pingMessage),
        InternetAddress(ip),
        port
      );

      return await completer.future;
    } catch (e) {
      return false;
    }
  }

  // Process a successful ping response
  Future<bool> _processSuccessfulPingResponse(String ip, int port, String responseBody) async {
    try {
      final data = jsonDecode(responseBody);
      final device = DeviceInfo.fromMap(data);

      developer.log('Found device: ${device.name} (${device.ipAddress}) - Role: ${device.role == DeviceRole.server ? "Server" : "Client"}');

      // Don't add ourselves to the list
      if (device.id == deviceId) {
        return true;
      }

      // Process the device info
      _processDiscoveredDevice(device);
      return true;
    } catch (e) {
      developer.log('Error parsing device data from $ip: $e');
      return false;
    }
  }

  // Process a discovered device
  void _processDiscoveredDevice(DeviceInfo device) {
    // Update connection cache for faster reconnection
    final cacheKey = '${device.ipAddress}:${device.port}';
    _lastSuccessfulConnections[cacheKey] = DateTime.now();

    // Update known devices
    final existingIndex = knownDevices.indexWhere((d) => d.id == device.id);
    if (existingIndex >= 0) {
      knownDevices[existingIndex] = device;
    } else {
      knownDevices.add(device);
    }

    // If this is a server, update connection status immediately
    if (device.role == DeviceRole.server) {
      developer.log('Found a server! ${device.name} (${device.ipAddress})');

      // Update connection status immediately for faster UI feedback
      isConnectedToServer.value = true;
      connectedServerName.value = device.name;
      connectedServerIp.value = device.ipAddress;
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

    // Create a completer that will be completed when we find a server
    // This allows us to stop scanning as soon as we find a server
    final serverFoundCompleter = Completer<bool>();

    // First check recently successful connections with higher priority
    final recentConnections = <String, DateTime>{};
    _lastSuccessfulConnections.forEach((key, timestamp) {
      if (DateTime.now().difference(timestamp) < _connectionCacheValidity) {
        final parts = key.split(':');
        if (parts.length == 2) {
          final ip = parts[0];
          if (ip != ipAddress) {
            recentConnections[ip] = timestamp;
          }
        }
      }
    });

    // Sort recent connections by timestamp (most recent first)
    final sortedRecentIps = recentConnections.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final recentIps = sortedRecentIps.map((e) => e.key).toList();

    // Try recent connections first with a short timeout
    if (recentIps.isNotEmpty) {
      developer.log('Trying ${recentIps.length} recent connections first');
      final recentFutures = <Future<bool>>[];

      for (final ip in recentIps) {
        recentFutures.add(pingDevice(ip, serverPort).then((success) {
          if (success) {
            // Check if we found a server
            if (knownDevices.any((device) =>
                device.role == DeviceRole.server &&
                device.id != deviceId &&
                device.ipAddress == ip)) {
              if (!serverFoundCompleter.isCompleted) {
                developer.log('Found server in recent connections: $ip');
                serverFoundCompleter.complete(true);
              }
            }
          }
          return success;
        }));
      }

      // Wait for recent connections with a short timeout
      await Future.wait(recentFutures);

      // If we found a server, we can stop here
      if (serverFoundCompleter.isCompleted ||
          knownDevices.any((device) => device.role == DeviceRole.server && device.id != deviceId)) {
        developer.log('Found server in recent connections, stopping discovery');

        // Update the knownDevices list with new discoveries
        _updateKnownDevicesList(newDevices, previousDevices);
        return knownDevices;
      }
    }

    // If manual IP is provided, try that specifically with high priority
    if (manualIpAddress != null && manualIpAddress != ipAddress) {
      developer.log('Trying manual IP: $manualIpAddress');
      final success = await pingDevice(manualIpAddress!, serverPort);

      if (success && knownDevices.any((device) =>
          device.role == DeviceRole.server &&
          device.id != deviceId &&
          device.ipAddress == manualIpAddress)) {
        developer.log('Found server at manual IP: $manualIpAddress');

        // Update the knownDevices list with new discoveries
        _updateKnownDevicesList(newDevices, previousDevices);
        return knownDevices;
      }
    }

    // Try common IPs (1, 100-105, 254) for faster discovery
    // These are common IP addresses for routers and servers
    final commonIps = [1, 100, 101, 102, 103, 104, 105, 254];
    final commonFutures = <Future<bool>>[];

    for (int i in commonIps) {
      final ip = '$baseIp.$i';
      if (ip != ipAddress && !recentIps.contains(ip)) {
        commonFutures.add(pingDevice(ip, serverPort).then((success) {
          if (success) {
            // Check if we found a server
            if (knownDevices.any((device) =>
                device.role == DeviceRole.server &&
                device.id != deviceId &&
                device.ipAddress == ip)) {
              if (!serverFoundCompleter.isCompleted) {
                developer.log('Found server in common IPs: $ip');
                serverFoundCompleter.complete(true);
              }
            }
          }
          return success;
        }));
      }
    }

    // Wait for common IPs to respond or until we find a server
    await Future.wait(commonFutures);

    // If we found a server, we can stop here
    if (serverFoundCompleter.isCompleted ||
        knownDevices.any((device) => device.role == DeviceRole.server && device.id != deviceId)) {
      developer.log('Found server, stopping discovery');

      // Update the knownDevices list with new discoveries
      _updateKnownDevicesList(newDevices, previousDevices);
      return knownDevices;
    }

    // Try UDP broadcast discovery as a faster alternative to scanning all IPs
    try {
      await _discoverViaUdpBroadcast();

      // Check if we found a server through UDP broadcast
      if (knownDevices.any((device) => device.role == DeviceRole.server && device.id != deviceId)) {
        developer.log('Found server via UDP broadcast, stopping discovery');

        // Update the knownDevices list with new discoveries
        _updateKnownDevicesList(newDevices, previousDevices);
        return knownDevices;
      }
    } catch (e) {
      developer.log('UDP broadcast discovery failed: $e');
      // Continue with IP scanning if UDP broadcast fails
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
          if (ip != ipAddress && !commonIps.contains(i) && !recentIps.contains(ip)) {
            allFutures.add(pingDevice(ip, serverPort).then((success) {
              if (success) {
                // Check if we found a server
                if (knownDevices.any((device) =>
                    device.role == DeviceRole.server &&
                    device.id != deviceId &&
                    device.ipAddress == ip)) {
                  if (!serverFoundCompleter.isCompleted) {
                    developer.log('Found server in IP scan: $ip');
                    serverFoundCompleter.complete(true);
                  }
                }
              }
              return success;
            }));
          }
        }
      }

      // Process all batches in parallel with a timeout
      if (allFutures.isNotEmpty) {
        developer.log('Scanning ${allFutures.length} IPs in parallel');
        await Future.wait(allFutures).timeout(
          const Duration(seconds: 2), // Reduced timeout for faster discovery
          onTimeout: () {
            developer.log('IP scan timeout reached, continuing with discovered devices');
            return [];
          },
        );
      }
    }

    // Update the knownDevices list with new discoveries
    _updateKnownDevicesList(newDevices, previousDevices);

    developer.log('Discovery complete. Found ${knownDevices.length} devices');
    return knownDevices;
  }

  // Helper method to update the known devices list
  void _updateKnownDevicesList(List<DeviceInfo> newDevices, List<DeviceInfo> previousDevices) {
    knownDevices.clear();
    knownDevices.addAll(newDevices);

    // Add any devices we found during scanning
    for (final device in previousDevices) {
      if (!knownDevices.any((d) => d.id == device.id)) {
        knownDevices.add(device);
      }
    }
  }

  // Broadcast server presence to help clients find it faster
  Future<void> _broadcastServerPresence() async {
    if (deviceRole != DeviceRole.server || ipAddress == null) return;

    try {
      // Create a UDP socket for broadcasting
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      // Prepare server announcement message
      final announcement = jsonEncode({
        'id': deviceId,
        'name': deviceName,
        'role': deviceRole.index,
        'port': serverPort,
        'action': 'server_announcement',
        'last_seen': DateTime.now().toIso8601String(),
      });

      // Send to broadcast address
      final segments = ipAddress!.split('.');
      if (segments.length == 4) {
        final broadcastIp = '${segments[0]}.${segments[1]}.${segments[2]}.255';
        socket.send(
          utf8.encode(announcement),
          InternetAddress(broadcastIp),
          serverPort
        );
        developer.log('Broadcast server presence to $broadcastIp:$serverPort');
      }

      // Close the socket
      socket.close();
    } catch (e) {
      developer.log('Error broadcasting server presence: $e');
    }
  }

  // Discover devices using UDP broadcast
  Future<void> _discoverViaUdpBroadcast() async {
    try {
      developer.log('Starting UDP broadcast discovery');
      final RawDatagramSocket socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      // Set up a listener for responses
      final completer = Completer<void>();
      final responseTimeout = Timer(Duration(milliseconds: 800), () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            try {
              final response = String.fromCharCodes(datagram.data);
              developer.log('Received UDP response from ${datagram.address.address}: $response');

              // Try to parse the response as JSON
              try {
                final data = jsonDecode(response);
                if (data['id'] != null && data['role'] != null) {
                  // Create a device info object from the response
                  final device = DeviceInfo(
                    id: data['id'],
                    name: data['name'] ?? 'Unknown Device',
                    ipAddress: datagram.address.address,
                    port: data['port'] ?? serverPort,
                    role: DeviceRole.values[data['role'] as int],
                    lastSeen: DateTime.now(),
                  );

                  // Process the discovered device
                  _processDiscoveredDevice(device);
                  developer.log('Added device from UDP broadcast: ${device.name} (${device.ipAddress})');

                  // If this is a server and we're a client, update connection status immediately
                  if (device.role == DeviceRole.server && deviceRole == DeviceRole.client) {
                    isConnectedToServer.value = true;
                    connectedServerName.value = device.name;
                    connectedServerIp.value = device.ipAddress;
                    developer.log('Connected to server via UDP: ${device.name} (${device.ipAddress})');
                  }
                }
              } catch (e) {
                developer.log('Error parsing UDP response: $e');
              }
            } catch (e) {
              developer.log('Error processing UDP datagram: $e');
            }
          }
        }
      });

      // Send broadcast message
      final broadcastMessage = jsonEncode({
        'id': deviceId,
        'name': deviceName,
        'role': deviceRole.index,
        'action': 'discovery',
      });

      // Send to broadcast address
      final segments = ipAddress!.split('.');
      if (segments.length == 4) {
        final broadcastIp = '${segments[0]}.${segments[1]}.${segments[2]}.255';
        socket.send(
          utf8.encode(broadcastMessage),
          InternetAddress(broadcastIp),
          serverPort
        );
        developer.log('Sent UDP broadcast to $broadcastIp:$serverPort');
      }

      // Wait for responses
      await completer.future;
      responseTimeout.cancel();
      socket.close();
      developer.log('UDP broadcast discovery completed');
    } catch (e) {
      developer.log('Error in UDP broadcast discovery: $e');
    }
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

      // Compress the data for faster transfer
      final batchMap = batch.toMap();
      final jsonData = jsonEncode(batchMap);
      final compressedData = gzip.encode(utf8.encode(jsonData));

      // Calculate compression ratio for logging
      final originalSize = jsonData.length;
      final compressedSize = compressedData.length;
      final compressionRatio = (originalSize > 0) ? (100 - (compressedSize * 100 / originalSize)).toStringAsFixed(1) : '0';
      developer.log('Data compressed from $originalSize to $compressedSize bytes ($compressionRatio% reduction)');

      // Create a completer to handle the first successful response
      final completer = Completer<bool>();

      // Try multiple approaches in parallel for faster sync
      // 1. Standard HTTP POST with compressed data
      // 2. Chunked HTTP POST for larger datasets
      // 3. UDP-based sync for small datasets (fastest but less reliable)

      // Only use UDP for small datasets (less than 1000 bytes)
      if (compressedSize < 1000) {
        // Try UDP first for small datasets (fastest)
        _sendSyncViaUdp(targetDevice, batch).then((success) {
          if (success && !completer.isCompleted) {
            developer.log('UDP sync succeeded!');
            completer.complete(true);
          }
        }).catchError((_) {});
      }

      // Always try HTTP POST (most reliable)
      _sendSyncViaHttp(targetDevice, compressedData, true).then((success) {
        if (success && !completer.isCompleted) {
          developer.log('HTTP sync succeeded!');
          completer.complete(true);
        }
      }).catchError((_) {});

      // For larger datasets, also try chunked transfer
      if (compressedSize > 10000) {
        _sendSyncViaChunkedHttp(targetDevice, compressedData).then((success) {
          if (success && !completer.isCompleted) {
            developer.log('Chunked HTTP sync succeeded!');
            completer.complete(true);
          }
        }).catchError((_) {});
      }

      // Set a timeout and fallback to standard HTTP if all parallel attempts fail
      Timer(Duration(milliseconds: 2000), () {
        if (!completer.isCompleted) {
          developer.log('Parallel sync attempts timed out, trying standard HTTP as fallback');
          _sendSyncViaHttp(targetDevice, compressedData, false).then((success) {
            completer.complete(success);
          }).catchError((e) {
            developer.log('Fallback HTTP sync failed: $e');
            completer.complete(false);
          });
        }
      });

      // Wait for the first successful response or all to fail
      return await completer.future.timeout(
        Duration(seconds: 5),
        onTimeout: () {
          developer.log('All sync attempts timed out');
          return false;
        },
      );
    } catch (e) {
      developer.log('Error sending sync batch: $e');
      return false;
    }
  }

  // Send sync data via standard HTTP POST
  Future<bool> _sendSyncViaHttp(DeviceInfo targetDevice, List<int> compressedData, bool useShortTimeout) async {
    try {
      final url = 'http://${targetDevice.ipAddress}:${targetDevice.port}/sync';
      developer.log('Sending HTTP sync to: $url');

      // Add security and compression headers
      final headers = {
        'Content-Type': 'application/octet-stream',
        'X-Client-ID': deviceId,
        'X-Client-Name': deviceName,
        'X-Client-Type': Platform.operatingSystem,
        'X-Content-Encoding': 'gzip',
      };

      // Use a shorter timeout for parallel attempts
      final timeout = useShortTimeout ? Duration(milliseconds: 1500) : Duration(seconds: 4);

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: compressedData,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        developer.log('Successfully sent sync batch via HTTP');
        return true;
      } else {
        developer.log('Failed to send sync batch via HTTP. Status code: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      developer.log('Error in HTTP sync: $e');
      return false;
    }
  }

  // Send sync data via chunked HTTP POST for larger datasets
  Future<bool> _sendSyncViaChunkedHttp(DeviceInfo targetDevice, List<int> compressedData) async {
    try {
      final url = 'http://${targetDevice.ipAddress}:${targetDevice.port}/sync';
      developer.log('Sending chunked HTTP sync to: $url');

      final client = http.Client();
      final request = http.Request('POST', Uri.parse(url));

      // Add security and compression headers
      request.headers['Content-Type'] = 'application/octet-stream';
      request.headers['X-Client-ID'] = deviceId;
      request.headers['X-Client-Name'] = deviceName;
      request.headers['X-Client-Type'] = Platform.operatingSystem;
      request.headers['X-Content-Encoding'] = 'gzip';
      request.headers['Transfer-Encoding'] = 'chunked';

      // Set the body bytes directly
      request.bodyBytes = compressedData;

      final streamedResponse = await client.send(request).timeout(Duration(seconds: 4));
      final response = await http.Response.fromStream(streamedResponse);
      client.close();

      if (response.statusCode == 200) {
        developer.log('Successfully sent sync batch via chunked HTTP');
        return true;
      } else {
        developer.log('Failed to send sync batch via chunked HTTP. Status code: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      developer.log('Error in chunked HTTP sync: $e');
      return false;
    }
  }

  // Send sync data via UDP for small datasets (fastest but less reliable)
  Future<bool> _sendSyncViaUdp(DeviceInfo targetDevice, SyncBatch batch) async {
    try {
      // Only use UDP for very small batches
      if (batch.items.length > 5) {
        return false; // Too many items for UDP
      }

      developer.log('Trying UDP sync to ${targetDevice.ipAddress}:${targetDevice.port}');
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final completer = Completer<bool>();

      // Set up a timeout
      final timeout = Timer(Duration(milliseconds: 800), () {
        if (!completer.isCompleted) {
          socket.close();
          completer.complete(false);
        }
      });

      // Listen for acknowledgement
      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null && datagram.address.address == targetDevice.ipAddress) {
            try {
              final response = String.fromCharCodes(datagram.data);
              try {
                final data = jsonDecode(response);
                if (data['status'] == 'success' && !completer.isCompleted) {
                  // Got success acknowledgement
                  timeout.cancel();
                  socket.close();
                  completer.complete(true);
                }
              } catch (e) {
                // Ignore parsing errors
              }
            } catch (e) {
              // Ignore processing errors
            }
          }
        }
      });

      // Prepare sync message
      final syncMessage = jsonEncode({
        'id': deviceId,
        'name': deviceName,
        'role': deviceRole.index,
        'action': 'sync',
        'batch': batch.toMap(),
      });

      // Send the message
      socket.send(
        utf8.encode(syncMessage),
        InternetAddress(targetDevice.ipAddress),
        targetDevice.port
      );

      return await completer.future;
    } catch (e) {
      developer.log('Error in UDP sync: $e');
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
