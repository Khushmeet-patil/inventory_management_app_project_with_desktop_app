class Product {
  final int id;
  final String barcode;
  final String name;
  int? quantity; // Making quantity optional
  final double pricePerQuantity;
  final String? photo; // Path to the product image
  final String? unitType; // 'pcs' or 'set'
  final String? size; // Size in different units
  final String? color;
  final String? material;
  final String? weight;
  final double? rentPrice; // Price for renting
  final DateTime createdAt;
  DateTime updatedAt;
  String? syncId; // Unique ID for synchronization
  DateTime? lastSynced; // Last time this product was synced

  Product({
    required this.id,
    required this.barcode,
    required this.name,
    this.quantity,
    required this.pricePerQuantity,
    this.photo,
    this.unitType,
    this.size,
    this.color,
    this.material,
    this.weight,
    this.rentPrice,
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
      'photo': photo,
      'unit_type': unitType,
      'size': size,
      'color': color,
      'material': material,
      'weight': weight,
      'rent_price': rentPrice,
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
    String? photo,
    String? unitType,
    String? size,
    String? color,
    String? material,
    String? weight,
    double? rentPrice,
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
      photo: photo ?? this.photo,
      unitType: unitType ?? this.unitType,
      size: size ?? this.size,
      color: color ?? this.color,
      material: material ?? this.material,
      weight: weight ?? this.weight,
      rentPrice: rentPrice ?? this.rentPrice,
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
      quantity: map['quantity'] != null ? map['quantity'] as int : null,
      pricePerQuantity: (map['price_per_quantity'] as num).toDouble(),
      photo: map['photo'] as String?,
      unitType: map['unit_type'] as String?,
      size: map['size'] as String?,
      color: map['color'] as String?,
      material: map['material'] as String?,
      weight: map['weight'] as String?,
      rentPrice: map['rent_price'] != null ? (map['rent_price'] as num).toDouble() : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      syncId: map['syncId'] as String?,
      lastSynced: map['lastSynced'] != null ? DateTime.parse(map['lastSynced'] as String) : null,
    );
  }
}