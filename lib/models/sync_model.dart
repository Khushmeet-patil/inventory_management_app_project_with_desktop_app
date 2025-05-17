import 'dart:convert';
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
    try {
      // Ensure data is properly serializable
      final serializedData = Map<String, dynamic>.from(data);

      // Convert any non-serializable values to strings
      serializedData.forEach((key, value) {
        if (value is DateTime) {
          serializedData[key] = value.toIso8601String();
        }
      });

      // Convert the data map to a JSON string for database storage
      final jsonData = jsonEncode(serializedData);

      return {
        'id': id,
        'entity_id': entityId,
        'entity_type': entityType,
        'operation': operation.index,
        'data': jsonData, // Store as JSON string, not as a Map
        'timestamp': timestamp.toIso8601String(),
        'status': status.index,
        'error_message': errorMessage,
      };
    } catch (e) {
      print('Error serializing SyncItem: $e');
      print('Problematic data: $data');
      // Provide a fallback with minimal data
      return {
        'id': id,
        'entity_id': entityId,
        'entity_type': entityType,
        'operation': operation.index,
        'data': jsonEncode({'error': 'Failed to serialize data: $e'}), // Still encode as JSON string
        'timestamp': timestamp.toIso8601String(),
        'status': status.index, // Use current status instead of error
        'error_message': 'Serialization error: $e',
      };
    }
  }

  factory SyncItem.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> dataMap;
    try {
      // Handle data field which could be a JSON string or a Map
      if (map['data'] is String) {
        // Parse JSON string
        dataMap = jsonDecode(map['data'] as String);
      } else if (map['data'] is Map) {
        // Already a Map
        dataMap = Map<String, dynamic>.from(map['data'] as Map);
      } else {
        // Fallback
        dataMap = {};
        print('Warning: Unexpected data type in SyncItem: ${map['data'].runtimeType}');
      }
    } catch (e) {
      print('Error parsing data in SyncItem.fromMap: $e');
      dataMap = {};
    }

    return SyncItem(
      id: map['id'] as String,
      entityId: map['entity_id'] as String,
      entityType: map['entity_type'] as String,
      operation: SyncOperation.values[map['operation'] as int],
      data: dataMap,
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
