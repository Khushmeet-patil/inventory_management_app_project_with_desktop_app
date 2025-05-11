import 'package:get/get.dart';
import '../models/sync_model.dart';
import '../services/network_service.dart';
import '../services/sync_service.dart';
import '../services/database_services.dart';

class SettingsController extends GetxController {
  final NetworkService _networkService = NetworkService.instance;
  final SyncService _syncService = SyncService.instance;
  final DatabaseService _dbService = DatabaseService.instance;

  final RxBool isServer = false.obs;
  final RxString deviceName = ''.obs;
  final RxString ipAddress = 'Unknown'.obs;
  final RxString manualIpAddress = ''.obs;
  final RxBool useManualIp = false.obs;
  final RxList<DeviceInfo> discoveredDevices = <DeviceInfo>[].obs;
  final RxBool isDiscovering = false.obs;
  final RxBool isInitialized = false.obs;

  @override
  void onInit() {
    super.onInit();
    deviceName.value = _networkService.deviceName;
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
      final devices = await _networkService.discoverDevices();
      discoveredDevices.value = devices;

      // Save discovered devices to database
      for (final device in devices) {
        await _dbService.saveDevice(device);
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
