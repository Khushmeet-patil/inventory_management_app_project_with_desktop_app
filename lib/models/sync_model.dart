import 'package:uuid/uuid.dart';
import 'product_model.dart';
import 'history_model.dart';

enum SyncOperation { add, update, delete }
enum SyncStatus { pending, completed, failed }
enum DeviceRole { server, client }

class SyncItem {
  final String id;
  final String entityId;
  final String entityType; // 'product' or 'history'
  final SyncOperation operation;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  SyncStatus status;
  String? errorMessage;

  SyncItem({
    required this.id,
    required this.entityId,
    required this.entityType,
    required this.operation,
    required this.data,
    required this.timestamp,
    this.status = SyncStatus.pending,
    this.errorMessage,
  });

  factory SyncItem.fromProduct(Product product, SyncOperation operation) {
    return SyncItem(
      id: const Uuid().v4(),
      entityId: product.syncId ?? product.id.toString(),
      entityType: 'product',
      operation: operation,
      data: product.toMap(),
      timestamp: DateTime.now(),
    );
  }

  factory SyncItem.fromHistory(ProductHistory history, SyncOperation operation) {
    return SyncItem(
      id: const Uuid().v4(),
      entityId: history.syncId ?? history.id.toString(),
      entityType: 'history',
      operation: operation,
      data: history.toMap(includeId: true),
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entity_id': entityId,
      'entity_type': entityType,
      'operation': operation.index,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'status': status.index,
      'error_message': errorMessage,
    };
  }

  factory SyncItem.fromMap(Map<String, dynamic> map) {
    return SyncItem(
      id: map['id'] as String,
      entityId: map['entity_id'] as String,
      entityType: map['entity_type'] as String,
      operation: SyncOperation.values[map['operation'] as int],
      data: Map<String, dynamic>.from(map['data'] as Map),
      timestamp: DateTime.parse(map['timestamp'] as String),
      status: SyncStatus.values[map['status'] as int],
      errorMessage: map['error_message'] as String?,
    );
  }
}

class SyncBatch {
  final String id;
  final String deviceId;
  final List<SyncItem> items;
  final DateTime timestamp;
  
  SyncBatch({
    required this.id,
    required this.deviceId,
    required this.items,
    required this.timestamp,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'items': items.map((item) => item.toMap()).toList(),
      'timestamp': timestamp.toIso8601String(),
    };
  }
  
  factory SyncBatch.fromMap(Map<String, dynamic> map) {
    return SyncBatch(
      id: map['id'] as String,
      deviceId: map['device_id'] as String,
      items: (map['items'] as List)
          .map((item) => SyncItem.fromMap(item as Map<String, dynamic>))
          .toList(),
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}

class DeviceInfo {
  final String id;
  final String name;
  final String ipAddress;
  final int port;
  final DeviceRole role;
  final DateTime lastSeen;
  
  DeviceInfo({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.port,
    required this.role,
    required this.lastSeen,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'ip_address': ipAddress,
      'port': port,
      'role': role.index,
      'last_seen': lastSeen.toIso8601String(),
    };
  }
  
  factory DeviceInfo.fromMap(Map<String, dynamic> map) {
    return DeviceInfo(
      id: map['id'] as String,
      name: map['name'] as String,
      ipAddress: map['ip_address'] as String,
      port: map['port'] as int,
      role: DeviceRole.values[map['role'] as int],
      lastSeen: DateTime.parse(map['last_seen'] as String),
    );
  }
}
