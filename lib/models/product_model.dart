class Product {
  final int id;
  final String barcode;
  final String name;
  int quantity;
  final double pricePerQuantity;
  final DateTime createdAt;
  DateTime updatedAt;
  String? syncId; // Unique ID for synchronization
  DateTime? lastSynced; // Last time this product was synced

  Product({
    required this.id,
    required this.barcode,
    required this.name,
    required this.quantity,
    required this.pricePerQuantity,
    required this.createdAt,
    required this.updatedAt,
    this.syncId,
    this.lastSynced,
  });

  Map<String, dynamic> toMap({bool includeId = true}) {
    final map = {
      'barcode': barcode,
      'name': name,
      'quantity': quantity,
      'price_per_quantity': pricePerQuantity,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'syncId': syncId,
      'lastSynced': lastSynced?.toIso8601String(),
    };
    if (includeId) {
      map['id'] = id;
    }
    return map;
  }

  Product copyWith({
    int? id,
    String? barcode,
    String? name,
    int? quantity,
    double? pricePerQuantity,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncId,
    DateTime? lastSynced,
  }) {
    return Product(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      pricePerQuantity: pricePerQuantity ?? this.pricePerQuantity,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncId: syncId ?? this.syncId,
      lastSynced: lastSynced ?? this.lastSynced,
    );
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int,
      barcode: map['barcode'] as String,
      name: map['name'] as String,
      quantity: map['quantity'] as int,
      pricePerQuantity: (map['price_per_quantity'] as num).toDouble(),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      syncId: map['syncId'] as String?,
      lastSynced: map['lastSynced'] != null ? DateTime.parse(map['lastSynced'] as String) : null,
    );
  }
}