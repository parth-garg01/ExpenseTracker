class TransactionItem {
  TransactionItem({
    required this.id,
    required this.amount,
    required this.type,
    required this.rawVendorName,
    required this.timestamp,
    this.vendorName,
    this.shopType = 'Anonymous',
    this.description,
  });

  final String id;
  final double amount;
  final String type;
  final String rawVendorName;
  final DateTime timestamp;
  String? vendorName;
  String shopType;
  String? description;

  bool get isCredit => type == 'credit';
  bool get isClassified => vendorName != null && shopType != 'Anonymous';
}
