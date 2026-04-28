class TransactionItem {
  TransactionItem({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.rawVendorName,
    required this.timestamp,
    required this.updatedAt,
    this.vendorName,
    this.shopType = 'Anonymous',
    this.description,
    this.isSynced = false,
  });

  final String id;
  final String userId;
  final double amount;
  final String type;
  final String rawVendorName;
  final DateTime timestamp;
  DateTime updatedAt;
  String? vendorName;
  String shopType;
  String? description;
  bool isSynced;

  bool get isCredit => type == 'credit';
  bool get isClassified => vendorName != null && shopType != 'Anonymous';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'type': type,
      'raw_vendor_name': rawVendorName,
      'vendor_name': vendorName,
      'shop_type': shopType,
      'tx_timestamp': timestamp.toIso8601String(),
      'description': description,
      'is_synced': isSynced ? 1 : 0,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String,
      rawVendorName: map['raw_vendor_name'] as String,
      timestamp: DateTime.parse(map['tx_timestamp'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      vendorName: map['vendor_name'] as String?,
      shopType: (map['shop_type'] as String?) ?? 'Anonymous',
      description: map['description'] as String?,
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
    );
  }
}
