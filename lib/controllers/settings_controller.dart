import 'dart:io' show Platform;
import 'package:get/get.dart';
import '../models/sync_model.dart';
import '../services/network_service.dart';
import '../services/sync_service.dart';
import '../services/database_services.dart';
import '../utils/toast_util.dart';

class SettingsController extends GetxController {
  final NetworkService _networkService = NetworkService.instance;
  final SyncService _syncService = SyncService.instance;
  final DatabaseService _dbService = DatabaseService.instance;

  // Public getters for services
  NetworkService get networkService => _networkService;
  SyncService get syncService => _syncService;

  final RxBool isServer = false.obs;
  final RxString deviceName = ''.obs;
  final RxString ipAddress = 'Unknown'.obs;
  final RxString manualIpAddress = ''.obs;
  final RxBool useManualIp = false.obs;
  final RxList<DeviceInfo> discoveredDevices = <DeviceInfo>[].obs;
  final RxBool isDiscovering = false.obs;
  final RxBool isInitialized = false.obs;

  // Flag to track if auto-initialization has been performed
  final RxBool autoInitialized = false.obs;

  @override
  void onInit() {
    super.onInit();
    deviceName.value = _networkService.deviceName;

    // Auto-detect platform and set role
    _detectPlatformAndSetRole();
  }

  // Automatically detect platform and set the appropriate role
  void _detectPlatformAndSetRole() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop platforms should be servers by default
      isServer.value = true;
      print('Desktop platform detected: Setting as SERVER');
    } else {
      // Mobile platforms should be clients by default
      isServer.value = false;
      print('Mobile platform detected: Setting as CLIENT');
    }
  }

  // Auto-initialize the network service based on platform
  Future<void> autoInitialize() async {
    if (autoInitialized.value) return;

    print('Auto-initializing network service...');
    await initialize();

    // If we're a client, automatically discover servers with more aggressive settings
    if (!isServer.value) {
      print('Auto-discovering servers with aggressive settings...');

      // Try multiple discovery attempts with short delays between them
      bool serverFound = false;
      for (int i = 0; i < 3 && !serverFound; i++) {
        await discoverDevices();

        // Check if we found any servers
        if (discoveredDevices.any((device) => device.role == DeviceRole.server)) {
          serverFound = true;
          print('Servers found, initiating sync...');
          await syncNow();
          ToastUtil.showInfo('Connected to server');
          break;
        }

        // Short delay before trying again
        if (i < 2 && !serverFound) {
          await Future.delayed(Duration(milliseconds: 500));
        }
      }

      // If no server was found after multiple attempts, show a message
      if (!serverFound) {
        ToastUtil.showInfo('No server found. Will keep searching in background.');
      }
    } else {
      ToastUtil.showInfo('Server initialized');
    }

    autoInitialized.value = true;
  }

  Future<void> initialize() async {
    if (isInitialized.value) return;

    final role = isServer.value ? DeviceRole.server : DeviceRole.client;
    String? customIp = useManualIp.value ? manualIpAddress.value : null;

    await _syncService.initialize(
      role: role,
      customDeviceName: deviceName.value,
      customIpAddress: customIp,
    );

    ipAddress.value = _networkService.ipAddress ?? 'Unknown';
    isInitialized.value = true;

    // Save local device info to database
    await _dbService.saveDevice(_networkService.getLocalDeviceInfo());
  }

  Future<void> discoverDevices() async {
    if (!isInitialized.value) {
      await initialize();
    }

    isDiscovering.value = true;

    try {
      // Use more aggressive discovery for faster server finding
      final devices = await _networkService.discoverDevices();
      discoveredDevices.value = devices;

      // Save discovered devices to database
      for (final device in devices) {
        await _dbService.saveDevice(device);
      }

      // Update connection status based on discovered devices
      final connectedToServer = _networkService.isConnectedToServer.value;
      final serverName = _networkService.connectedServerName.value;

      if (connectedToServer && serverName.isNotEmpty) {
        print('Connected to server: $serverName');
      }
    } finally {
      isDiscovering.value = false;
    }
  }

  Future<void> toggleServerMode() async {
    if (isInitialized.value) {
      // Need to restart services
      await _networkService.stopServer();
      isInitialized.value = false;
    }

    isServer.value = !isServer.value;
  }

  Future<void> syncNow() async {
    if (!isInitialized.value) {
      await initialize();
    }

    await _syncService.forceSync();
  }

  Future<void> setDeviceName(String name) async {
    deviceName.value = name;

    if (isInitialized.value) {
      // Need to restart services
      await _networkService.stopServer();
      isInitialized.value = false;
      await initialize();
    }
  }

  Future<void> setManualIpAddress(String ip) async {
    manualIpAddress.value = ip;

    if (isInitialized.value) {
      // Need to restart services
      await _networkService.stopServer();
      isInitialized.value = false;
      await initialize();
    }
  }

  Future<void> toggleUseManualIp(bool value) async {
    useManualIp.value = value;

    if (isInitialized.value) {
      // Need to restart services
      await _networkService.stopServer();
      isInitialized.value = false;
      await initialize();
    }
  }

  Future<void> setServerIpAddress(String ip) async {
    print('Setting manual server IP: $ip');

    // Try to ping the server first to verify it's reachable
    final success = await _networkService.pingDevice(ip, _networkService.serverPort);

    if (!success) {
      // Even if ping fails, we'll still add it as a manual entry
      print('Warning: Could not ping server at $ip, but adding it anyway');
    }

    // Find the server device or create a new one
    final serverIndex = discoveredDevices.indexWhere((d) =>
      d.role == DeviceRole.server && (d.id == 'manual-server' || d.ipAddress == ip)
    );

    if (serverIndex >= 0) {
      // Update existing server IP
      final server = discoveredDevices[serverIndex];
      final updatedServer = DeviceInfo(
        id: server.id,
        name: 'Manual Server',
        ipAddress: ip,
        port: _networkService.serverPort,
        role: DeviceRole.server,
        lastSeen: DateTime.now(),
      );
      discoveredDevices[serverIndex] = updatedServer;
      await _dbService.saveDevice(updatedServer);
      print('Updated existing server entry: ${updatedServer.ipAddress}');
    } else {
      // Create a new server entry
      final newServer = DeviceInfo(
        id: 'manual-server',
        name: 'Manual Server',
        ipAddress: ip,
        port: _networkService.serverPort,
        role: DeviceRole.server,
        lastSeen: DateTime.now(),
      );
      discoveredDevices.add(newServer);
      await _dbService.saveDevice(newServer);
      print('Added new manual server: ${newServer.ipAddress}');
    }

    // Force a sync to test the connection
    await Future.delayed(const Duration(seconds: 1));
    syncNow();
  }

  String get syncStatus => _syncService.syncStatus.value;
  bool get isSyncing => _syncService.isSyncing.value;
  int get pendingSyncItems => _syncService.pendingSyncItems.value;
}
