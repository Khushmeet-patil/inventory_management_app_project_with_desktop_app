enum HistoryType { rental, return_product, added_stock }

class ProductHistory {
  final int id;
  final int productId;
  final String productName;
  final String barcode;
  final int quantity;
  final HistoryType type;
  final String? givenTo;
  final String? agency;
  final DateTime rentedDate;
  final DateTime? returnDate;
  final int? rentalDays;
  final String? notes;
  final DateTime createdAt;
  String? syncId; // Unique ID for synchronization
  DateTime? lastSynced; // Last time this history was synced
  final String? transactionId; // ID to group items rented in the same transaction

  ProductHistory({
    required this.id,
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.quantity,
    required this.type,
    this.givenTo,
    this.agency,
    required this.rentedDate,
    this.returnDate,
    this.rentalDays,
    this.notes,
    required this.createdAt,
    this.syncId,
    this.lastSynced,
    this.transactionId,
  });

  factory ProductHistory.fromMap(Map<String, dynamic> map) {
    return ProductHistory(
      id: map['id'] as int,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String,
      barcode: map['barcode'] as String,
      quantity: map['quantity'] as int,
      type: HistoryType.values[map['type'] as int],
      givenTo: map['given_to'] as String?,
      agency: map['agency'] as String?,
      rentedDate: DateTime.parse(map['rented_date'] as String),
      returnDate: map['return_date'] != null ? DateTime.parse(map['return_date'] as String) : null,
      rentalDays: map['rental_days'] as int?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      syncId: map['sync_id'] as String?,
      lastSynced: map['last_synced'] != null ? DateTime.parse(map['last_synced'] as String) : null,
      transactionId: map['transaction_id'] as String?,
    );
  }

  Map<String, dynamic> toMap({bool includeId = false}) {
    final map = {
      'product_id': productId,
      'product_name': productName,
      'barcode': barcode,
      'quantity': quantity,
      'type': type.index,
      'given_to': givenTo,
      'agency': agency,
      'rented_date': rentedDate.toIso8601String(),
      'return_date': returnDate?.toIso8601String(),
      'rental_days': rentalDays,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'sync_id': syncId,
      'last_synced': lastSynced?.toIso8601String(),
      'transaction_id': transactionId,
    };
    if (includeId) {
      map['id'] = id;
    }
    return map;
  }

  ProductHistory copyWith({
    int? id,
    int? productId,
    String? productName,
    String? barcode,
    int? quantity,
    HistoryType? type,
    String? givenTo,
    String? agency,
    DateTime? rentedDate,
    DateTime? returnDate,
    int? rentalDays,
    String? notes,
    DateTime? createdAt,
    String? syncId,
    DateTime? lastSynced,
    String? transactionId,
  }) {
    return ProductHistory(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      barcode: barcode ?? this.barcode,
      quantity: quantity ?? this.quantity,
      type: type ?? this.type,
      givenTo: givenTo ?? this.givenTo,
      agency: agency ?? this.agency,
      rentedDate: rentedDate ?? this.rentedDate,
      returnDate: returnDate ?? this.returnDate,
      rentalDays: rentalDays ?? this.rentalDays,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      syncId: syncId ?? this.syncId,
      lastSynced: lastSynced ?? this.lastSynced,
      transactionId: transactionId ?? this.transactionId,
    );
  }
}