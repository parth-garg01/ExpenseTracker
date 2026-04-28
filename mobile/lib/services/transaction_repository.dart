import 'package:flutter/material.dart';

import '../models/transaction_item.dart';

class TransactionRepository {
  final List<TransactionItem> _items = [
    TransactionItem(
      id: '1',
      amount: 499.0,
      type: 'debit',
      rawVendorName: 'AMZN INDIA',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      vendorName: 'Amazon',
      shopType: 'Shopping',
    ),
    TransactionItem(
      id: '2',
      amount: 25000.0,
      type: 'credit',
      rawVendorName: 'ACME PAYROLL',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      vendorName: 'ACME Corp',
      shopType: 'Salary',
    ),
    TransactionItem(
      id: '3',
      amount: 150.0,
      type: 'debit',
      rawVendorName: 'UPI-XYZ-STORE',
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      shopType: 'Anonymous',
    ),
  ];

  final List<String> shopTypes = ['Anonymous', 'Shopping', 'Food', 'Travel', 'Salary'];

  List<TransactionItem> all() => List.unmodifiable(_items);

  void updateClassification(TransactionItem tx, String vendorName, String shopType, String? description) {
    tx.vendorName = vendorName.trim().isEmpty ? null : vendorName.trim();
    tx.shopType = shopType;
    tx.description = description;
  }

  Color amountColor(TransactionItem tx) => tx.isCredit ? Colors.green : Colors.red;
}
