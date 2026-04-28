import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction_item.dart';
import '../services/transaction_repository.dart';
import '../widgets/edit_transaction_sheet.dart';
import '../widgets/transaction_tile.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final repo = TransactionRepository();
  String _selectedShopType = 'All';

  @override
  Widget build(BuildContext context) {
    final source = repo.all();
    final transactions = _selectedShopType == 'All'
        ? source
        : source.where((e) => e.shopType == _selectedShopType).toList();

    final spent = transactions.where((e) => !e.isCredit).fold<double>(0, (a, b) => a + b.amount);
    final received = transactions.where((e) => e.isCredit).fold<double>(0, (a, b) => a + b.amount);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Smart Expense Tracker'),
          bottom: const TabBar(tabs: [Tab(text: 'Date'), Tab(text: 'Vendor'), Tab(text: 'Category')]),
        ),
        body: TabBarView(
          children: [
            _dateView(transactions, spent, received),
            _vendorView(transactions),
            _categoryView(transactions),
          ],
        ),
      ),
    );
  }

  Widget _dateView(List<TransactionItem> transactions, double spent, double received) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Spent: ₹${spent.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red)),
              Text('Received: ₹${received.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonFormField<String>(
            value: _selectedShopType,
            items: ['All', ...repo.shopTypes].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _selectedShopType = v ?? 'All'),
            decoration: const InputDecoration(labelText: 'Filter by shop type'),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final tx = transactions[index];
              return Card(
                color: tx.isClassified ? null : Colors.yellow.shade100,
                child: TransactionTile(
                  tx: tx,
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => EditTransactionSheet(
                      tx: tx,
                      shopTypes: repo.shopTypes,
                      onSave: (vendorName, shopType, description) {
                        setState(() => repo.updateClassification(tx, vendorName, shopType, description));
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _vendorView(List<TransactionItem> transactions) {
    final map = <String, double>{};
    for (final tx in transactions) {
      final key = tx.vendorName ?? tx.rawVendorName;
      map[key] = (map[key] ?? 0) + tx.amount;
    }
    return ListView(
      children: map.entries
          .map((e) => ListTile(title: Text(e.key), trailing: Text('₹${e.value.toStringAsFixed(2)}')))
          .toList(),
    );
  }

  Widget _categoryView(List<TransactionItem> transactions) {
    final map = <String, double>{};
    for (final tx in transactions) {
      map[tx.shopType] = (map[tx.shopType] ?? 0) + tx.amount;
    }
    return ListView(
      children: map.entries
          .map(
            (e) => ListTile(
              title: Text(e.key),
              trailing: Text(
                '₹${e.value.toStringAsFixed(2)}',
                style: TextStyle(color: e.key == 'Salary' ? Colors.green : Colors.red),
              ),
            ),
          )
          .toList(),
    );
  }
}
