import 'package:flutter/material.dart';

import '../models/transaction_item.dart';
import '../services/transaction_repository.dart';
import '../widgets/edit_transaction_sheet.dart';
import '../widgets/transaction_tile.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onLogout});
  final VoidCallback onLogout;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final repo = TransactionRepository();
  List<TransactionItem> transactions = [];
  String _selectedShopType = 'All';
  String _sort = 'latest';
  final TextEditingController _amountController = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await repo.seedIfEmpty();
    await repo.syncNow();
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final amountGt = double.tryParse(_amountController.text.trim());
    final latestFirst = _sort != 'oldest';
    final data = await repo.all(shopType: _selectedShopType, amountGt: amountGt, latestFirst: latestFirst);
    setState(() {
      transactions = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final spent = transactions.where((e) => !e.isCredit).fold<double>(0, (a, b) => a + b.amount);
    final received = transactions.where((e) => e.isCredit).fold<double>(0, (a, b) => a + b.amount);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Smart Expense Tracker'),
          actions: [
            IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout)),
            IconButton(
              onPressed: () async {
                await repo.syncNow();
                await _load();
              },
              icon: const Icon(Icons.sync),
            )
          ],
          bottom: const TabBar(tabs: [Tab(text: 'Date'), Tab(text: 'Vendor'), Tab(text: 'Category')]),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _dateView(spent, received),
                  _vendorView(),
                  _categoryView(),
                ],
              ),
      ),
    );
  }

  Widget _dateView(double spent, double received) {
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
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedShopType,
                  items: const ['All', 'Anonymous', 'Shopping', 'Food', 'Travel', 'Salary']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) async {
                    setState(() => _selectedShopType = v ?? 'All');
                    await _load();
                  },
                  decoration: const InputDecoration(labelText: 'Shop type'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount > X'),
                  onSubmitted: (_) async => _load(),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonFormField<String>(
            value: _sort,
            items: const [
              DropdownMenuItem(value: 'latest', child: Text('Latest first')),
              DropdownMenuItem(value: 'oldest', child: Text('Oldest first')),
            ],
            onChanged: (v) async {
              setState(() => _sort = v ?? 'latest');
              await _load();
            },
            decoration: const InputDecoration(labelText: 'Sort by date'),
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
                      shopTypes: const ['Anonymous', 'Shopping', 'Food', 'Travel', 'Salary'],
                      onSave: (vendorName, shopType, description) async {
                        await repo.updateClassification(tx, vendorName, shopType, description);
                        await repo.syncNow();
                        await _load();
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

  Widget _vendorView() {
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

  Widget _categoryView() {
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
