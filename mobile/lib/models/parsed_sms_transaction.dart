class ParsedSmsTransaction {
  ParsedSmsTransaction({
    required this.sender,
    required this.body,
    required this.timestamp,
    required this.amount,
    required this.type,
    required this.rawVendorName,
  });

  final String sender;
  final String body;
  final DateTime timestamp;
  final double amount;
  final String type;
  final String rawVendorName;
}
