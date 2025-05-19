import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
import '../controllers/language_controller.dart';
import '../models/sync_model.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget desktop;

  const ResponsiveLayout({
    Key? key,
    required this.mobile,
    required this.desktop,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return mobile;
        }
        return desktop;
      },
    );
  }
}

class SettingsPage extends StatelessWidget {
  final SettingsController _controller = Get.find<SettingsController>();
  final LanguageController _languageController = Get.find<LanguageController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('settings_title'.tr),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ResponsiveLayout(
                  mobile: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLanguageSection(),
                      const SizedBox(height: 16),
                      _buildDeviceInfoSection(),
                      const SizedBox(height: 16),
                      _buildNetworkModeSection(),
                      const SizedBox(height: 16),
                      _buildSyncSection(),
                      const SizedBox(height: 16),
                      _buildDevicesSectionMobile(),
                    ],
                  ),
                  desktop: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLanguageSection(),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 1,
                            child: _buildDeviceInfoSection(),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: _buildNetworkModeSection(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 1,
                            child: _buildSyncSection(),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: _buildDevicesSectionDesktop(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDeviceInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'device_info'.tr,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 300) {
                  // Very narrow layout - stack vertically
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('device_name'.tr + ': ', style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _showDeviceNameDialog(),
                          ),
                        ],
                      ),
                      Obx(() => Text(_controller.deviceName.value)),
                      const SizedBox(height: 8),
                      Text('ip_address'.tr + ': ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Obx(() => Text(_controller.ipAddress.value)),
                      const SizedBox(height: 8),
                      _buildManualIpSection(compact: true),
                    ],
                  );
                } else {
                  // Standard layout
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('device_name'.tr + ': ', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Obx(() => Text(_controller.deviceName.value)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showDeviceNameDialog(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('ip_address'.tr + ': ', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Obx(() => Text(_controller.ipAddress.value)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildManualIpSection(),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualIpSection({bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Obx(() => Checkbox(
              value: _controller.useManualIp.value,
              onChanged: (value) => _controller.toggleUseManualIp(value ?? false),
            )),
            Text('use_manual_ip'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        Obx(() => _controller.useManualIp.value
            ? Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'manual_ip_address'.tr,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        controller: TextEditingController(text: _controller.manualIpAddress.value),
                        onSubmitted: (value) => _controller.setManualIpAddress(value),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: () => _controller.setManualIpAddress(
                          TextEditingController(text: _controller.manualIpAddress.value).text),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink()),
      ],
    );
  }

  Widget _buildNetworkModeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'network_mode'.tr,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 300) {
                  // Very narrow layout - stack vertically
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Obx(() => Switch(
                            value: _controller.isServer.value,
                            onChanged: (value) => _controller.toggleServerMode(),
                          )),
                          Expanded(
                            child: Obx(() => Text(
                              _controller.isServer.value ? 'server_mode'.tr : 'client_mode'.tr,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            )),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'server_description'.tr,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'client_description'.tr,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      // Connection status indicator
                      _buildConnectionStatusIndicator(compact: true),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: Obx(() => ElevatedButton(
                          onPressed: _controller.isInitialized.value
                              ? null
                              : () => _controller.initialize(),
                          child: Text(_controller.isInitialized.value
                              ? 'network_initialized'.tr
                              : 'initialize_network'.tr),
                        )),
                      ),
                    ],
                  );
                } else {
                  // Standard layout
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Obx(() => Switch(
                            value: _controller.isServer.value,
                            onChanged: (value) => _controller.toggleServerMode(),
                          )),
                          Expanded(
                            child: Obx(() => Text(
                              _controller.isServer.value ? 'server_mode_desktop'.tr : 'client_mode_mobile'.tr,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            )),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'server_description'.tr,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'client_description'.tr,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      // Connection status indicator
                      _buildConnectionStatusIndicator(),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: Obx(() => ElevatedButton(
                          onPressed: _controller.isInitialized.value
                              ? null
                              : () => _controller.initialize(),
                          child: Text(_controller.isInitialized.value
                              ? 'network_initialized'.tr
                              : 'initialize_network'.tr),
                        )),
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // Build connection status indicator widget
  Widget _buildConnectionStatusIndicator({bool compact = false}) {
    final networkService = _controller.networkService;

    return Obx(() {
      final isServer = _controller.isServer.value;
      final isConnected = networkService.isConnectedToServer.value;
      final serverName = networkService.connectedServerName.value;
      final serverIp = networkService.connectedServerIp.value;

      if (isServer) {
        // Server status
        return Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: networkService.isServerRunning ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.computer,
                color: networkService.isServerRunning ? Colors.green : Colors.grey,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  networkService.isServerRunning
                      ? 'Server running on ${networkService.ipAddress}:${networkService.serverPort}'
                      : 'Server not running',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        );
      } else {
        // Client status
        return Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isConnected ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                isConnected ? Icons.link : Icons.link_off,
                color: isConnected ? Colors.green : Colors.orange,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  isConnected
                      ? compact
                          ? 'Connected to $serverName'
                          : 'Connected to $serverName ($serverIp)'
                      : 'Not connected to any server',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        );
      }
    });
  }

  Widget _buildSyncSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'synchronization'.tr,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 300) {
                  // Very narrow layout - stack vertically
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('status'.tr + ': ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Obx(() => Text(_controller.syncStatus, overflow: TextOverflow.ellipsis)),
                      const SizedBox(height: 8),
                      Text('pending_items'.tr + ': ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Obx(() => Text('${_controller.pendingSyncItems}')),
                      const SizedBox(height: 8),
                      // Auto-sync toggle
                      Row(
                        children: [
                          Obx(() => Checkbox(
                            value: _controller.syncService.autoSyncEnabled.value,
                            onChanged: (value) => _controller.syncService.autoSyncEnabled.value = value ?? true,
                          )),
                          Text('auto_sync'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: Obx(() => ElevatedButton(
                          onPressed: _controller.isSyncing || !_controller.isInitialized.value
                              ? null
                              : () => _controller.syncNow(),
                          child: _controller.isSyncing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text('sync_now'.tr),
                        )),
                      ),
                    ],
                  );
                } else {
                  // Standard layout
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('status'.tr + ': ', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Obx(() => Text(_controller.syncStatus, overflow: TextOverflow.ellipsis)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('pending_items'.tr + ': ', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Obx(() => Text('${_controller.pendingSyncItems}')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Auto-sync toggle
                      Row(
                        children: [
                          Obx(() => Checkbox(
                            value: _controller.syncService.autoSyncEnabled.value,
                            onChanged: (value) => _controller.syncService.autoSyncEnabled.value = value ?? true,
                          )),
                          Text('auto_sync'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: Obx(() => ElevatedButton(
                          onPressed: _controller.isSyncing || !_controller.isInitialized.value
                              ? null
                              : () => _controller.syncNow(),
                          child: _controller.isSyncing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text('sync_now'.tr),
                        )),
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesSectionMobile() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'discovered_devices'.tr,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Obx(() => ElevatedButton(
                  onPressed: _controller.isDiscovering.value || !_controller.isInitialized.value
                      ? null
                      : () => _controller.discoverDevices(),
                  child: _controller.isDiscovering.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('discover'.tr),
                )),
              ],
            ),
            const SizedBox(height: 8),
            _buildManualServerIpInput(),
            const SizedBox(height: 8),
            Container(
              constraints: BoxConstraints(maxHeight: 300),
              child: Obx(() => _controller.discoveredDevices.isEmpty
                  ? Center(child: Text('no_devices'.tr))
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: _controller.discoveredDevices.length,
                      itemBuilder: (context, index) {
                        final device = _controller.discoveredDevices[index];
                        return _buildDeviceListTile(device, context);
                      },
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesSectionDesktop() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'discovered_devices'.tr,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Obx(() => ElevatedButton(
                  onPressed: _controller.isDiscovering.value || !_controller.isInitialized.value
                      ? null
                      : () => _controller.discoverDevices(),
                  child: _controller.isDiscovering.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('discover'.tr),
                )),
              ],
            ),
            const SizedBox(height: 8),
            _buildManualServerIpInput(),
            const SizedBox(height: 8),
            Container(
              constraints: BoxConstraints(maxHeight: 400),
              child: Obx(() => _controller.discoveredDevices.isEmpty
                  ? Center(child: Text('no_devices'.tr))
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: _controller.discoveredDevices.length,
                      itemBuilder: (context, index) {
                        final device = _controller.discoveredDevices[index];
                        return _buildDeviceListTile(device, context);
                      },
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualServerIpInput() {
    final TextEditingController textController = TextEditingController();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('manual_server_prompt'.tr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: textController,
                  decoration: InputDecoration(
                    labelText: 'server_ip_label'.tr,
                    hintText: 'server_ip_hint'.tr,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      _controller.setServerIpAddress(value);
                    }
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  if (textController.text.isNotEmpty) {
                    _controller.setServerIpAddress(textController.text);
                    textController.clear();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceListTile(DeviceInfo device, BuildContext context) {
    return ListTile(
      leading: Icon(
        device.role == DeviceRole.server
            ? Icons.computer
            : Icons.phone_android,
        color: Theme.of(context).primaryColor,
      ),
      title: Text(device.name),
      subtitle: Text('${device.ipAddress}:${device.port}'),
      trailing: Text(
        device.role == DeviceRole.server ? 'server'.tr : 'client'.tr,
        style: TextStyle(
          color: device.role == DeviceRole.server
              ? Colors.red
              : Colors.blue,
        ),
      ),
    );
  }

  void _showDeviceNameDialog() {
    final TextEditingController textController = TextEditingController(
      text: _controller.deviceName.value,
    );

    Get.dialog(
      AlertDialog(
        title: Text('change_device_name'.tr),
        content: TextField(
          controller: textController,
          decoration: InputDecoration(
            labelText: 'device_name'.tr,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              _controller.setDeviceName(textController.text);
              Get.back();
            },
            child: Text('save'.tr),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSection() {
    return Builder(
      builder: (BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'language_settings'.tr,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('current_language'.tr + ': ', style: const TextStyle(fontWeight: FontWeight.bold)),
                Obx(() => Text(
                  '${_languageController.getLanguageFlag(_languageController.currentLanguage.value)} '
                  '${_languageController.getLanguageName(_languageController.currentLanguage.value)}',
                )),
              ],
            ),
            const SizedBox(height: 16),
            Text('select_language'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: _languageController.availableLanguages.map((language) {
                return InkWell(
                  onTap: () => _languageController.changeLanguage(language['code']),
                  child: Chip(
                    backgroundColor: _languageController.currentLanguage.value == language['code']
                        ? Theme.of(context).primaryColor.withOpacity(0.2)
                        : null,
                    avatar: Text(language['flag']),
                    label: Text(language['name']),
                    side: BorderSide(
                      color: _languageController.currentLanguage.value == language['code']
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade300,
                      width: _languageController.currentLanguage.value == language['code'] ? 2 : 1,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
      },
    );
  }
}
