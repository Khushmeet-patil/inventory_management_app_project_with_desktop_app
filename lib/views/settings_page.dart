import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
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
  final SettingsController _controller = Get.put(SettingsController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Settings'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
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
            const Text(
              'Device Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                          const Text('Device Name: ', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      const Text('IP Address: ', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          const Text('Device Name: ', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          const Text('IP Address: ', style: TextStyle(fontWeight: FontWeight.bold)),
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
            const Text('Use Manual IP', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        Obx(() => _controller.useManualIp.value
            ? Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Manual IP Address',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
            const Text(
              'Network Mode',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                              _controller.isServer.value ? 'Server Mode' : 'Client Mode',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            )),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Server Mode: This device will store the main database and serve other devices.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Client Mode: This device will sync with the server.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: Obx(() => ElevatedButton(
                          onPressed: _controller.isInitialized.value
                              ? null
                              : () => _controller.initialize(),
                          child: Text(_controller.isInitialized.value
                              ? 'Network Initialized'
                              : 'Initialize Network'),
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
                              _controller.isServer.value ? 'Server Mode (Desktop)' : 'Client Mode (Mobile)',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            )),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Server Mode: This device will store the main database and serve other devices.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Client Mode: This device will sync with the server.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: Obx(() => ElevatedButton(
                          onPressed: _controller.isInitialized.value
                              ? null
                              : () => _controller.initialize(),
                          child: Text(_controller.isInitialized.value
                              ? 'Network Initialized'
                              : 'Initialize Network'),
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

  Widget _buildSyncSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Synchronization',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 300) {
                  // Very narrow layout - stack vertically
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Obx(() => Text(_controller.syncStatus, overflow: TextOverflow.ellipsis)),
                      const SizedBox(height: 8),
                      const Text('Pending Items: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Obx(() => Text('${_controller.pendingSyncItems}')),
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
                              : const Text('Sync Now'),
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
                          const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Obx(() => Text(_controller.syncStatus, overflow: TextOverflow.ellipsis)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Pending Items: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Obx(() => Text('${_controller.pendingSyncItems}')),
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
                              : const Text('Sync Now'),
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
                const Text(
                  'Discovered Devices',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      : const Text('Discover'),
                )),
              ],
            ),
            const SizedBox(height: 8),
            _buildManualServerIpInput(),
            const SizedBox(height: 8),
            SizedBox(
              height: 300, // Fixed height for mobile
              child: Obx(() => _controller.discoveredDevices.isEmpty
                  ? const Center(child: Text('No devices discovered'))
                  : ListView.builder(
                      itemCount: _controller.discoveredDevices.length,
                      itemBuilder: (context, index) {
                        final device = _controller.discoveredDevices[index];
                        return _buildDeviceListTile(device);
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
                const Text(
                  'Discovered Devices',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      : const Text('Discover'),
                )),
              ],
            ),
            const SizedBox(height: 8),
            _buildManualServerIpInput(),
            const SizedBox(height: 8),
            SizedBox(
              height: 400, // Taller for desktop
              child: Obx(() => _controller.discoveredDevices.isEmpty
                  ? const Center(child: Text('No devices discovered'))
                  : ListView.builder(
                      itemCount: _controller.discoveredDevices.length,
                      itemBuilder: (context, index) {
                        final device = _controller.discoveredDevices[index];
                        return _buildDeviceListTile(device);
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
          const Text('Can\'t find server? Enter IP manually:', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: textController,
                  decoration: const InputDecoration(
                    labelText: 'Server IP Address',
                    hintText: 'e.g., 192.168.1.100',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

  Widget _buildDeviceListTile(DeviceInfo device) {
    return ListTile(
      leading: Icon(
        device.role == DeviceRole.server
            ? Icons.computer
            : Icons.phone_android,
        color: Colors.teal,
      ),
      title: Text(device.name),
      subtitle: Text('${device.ipAddress}:${device.port}'),
      trailing: Text(
        device.role == DeviceRole.server ? 'Server' : 'Client',
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
        title: const Text('Change Device Name'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            labelText: 'Device Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _controller.setDeviceName(textController.text);
              Get.back();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
