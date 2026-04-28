import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction_item.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.tx,
    required this.onTap,
  });

  final TransactionItem tx;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amountColor = tx.isCredit ? Colors.green : Colors.red;
    return ListTile(
      onTap: onTap,
      title: Text(tx.vendorName ?? tx.rawVendorName),
      subtitle: Text('${tx.shopType} • ${DateFormat('dd MMM, hh:mm a').format(tx.timestamp)}'),
      trailing: Text(
        '${tx.isCredit ? '+' : '-'}₹${tx.amount.toStringAsFixed(2)}',
        style: TextStyle(color: amountColor, fontWeight: FontWeight.w700),
      ),
    );
  }
}
