import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/transaction_item.dart';
import '../services/transaction_repository.dart';
import '../services/sms_import_service.dart';
import '../widgets/edit_transaction_sheet.dart';
import '../widgets/transaction_tile.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final repo = TransactionRepository();
  final smsImport = SmsImportService();
  List<TransactionItem> transactions = [];
  String _selectedShopType = 'All';
  String _sort = 'latest';
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateSearchController = TextEditingController();
  final TextEditingController _vendorSearchController = TextEditingController();
  final TextEditingController _categorySearchController = TextEditingController();
  bool _loading = true;
  static const List<String> _defaultShopTypes = ['Anonymous', 'Shopping', 'Food', 'Travel', 'Salary'];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await repo.applyFreshStartOnce();
    await repo.normalizeLegacyImportedSms();
    await _autoImportSmsOnOpen();
    await smsImport.startIncomingSmsListener(
      onForegroundTransaction: (tx) async {
        await repo.ingestParsedSms([tx]);
        if (!mounted) return;
        await _load();
      },
    );
    await _load();
  }

  Future<void> _autoImportSmsOnOpen() async {
    final granted = await smsImport.ensureSmsPermission();
    if (!granted) return;
    final pending = await smsImport.consumePendingBackgroundSms();
    await repo.ingestParsedSms(pending);
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
  void dispose() {
    _amountController.dispose();
    _dateSearchController.dispose();
    _vendorSearchController.dispose();
    _categorySearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spent = transactions.where((e) => !e.isCredit).fold<double>(0, (a, b) => a + b.amount);
    final received = transactions.where((e) => e.isCredit).fold<double>(0, (a, b) => a + b.amount);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.menu_book_rounded, size: 20, color: Theme.of(context).colorScheme.onPrimaryContainer),
                  Positioned(
                    right: 3,
                    bottom: 3,
                    child: Icon(Icons.edit, size: 11, color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ),
          title: const Text('Expense Tracker'),
          actions: [
            IconButton(
              onPressed: () async {
                final granted = await smsImport.ensureSmsPermission();
                if (!granted) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('SMS permission denied. Please allow to import transactions.')),
                  );
                  return;
                }
                final rows = await smsImport.fetchRecentTransactions(limit: 120);
                final inserted = await repo.ingestParsedSms(rows);
                await _load();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('SMS import complete: $inserted transaction(s) added.')),
                );
              },
              icon: const Icon(Icons.sms),
              tooltip: 'Import SMS',
            ),
            IconButton(
              onPressed: () async {
                final exportFile = await repo.exportTransactionsCsvFile();
                await Share.shareXFiles(
                  [XFile(exportFile.path)],
                  text: 'Expense Tracker CSV export',
                  subject: 'Expense Tracker Export',
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CSV ready. Use share options to save or send it.')),
                );
              },
              icon: const Icon(Icons.download),
              tooltip: 'Export CSV',
            )
          ],
          bottom: const TabBar(tabs: [Tab(text: 'Date'), Tab(text: 'Vendor'), Tab(text: 'Category')]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openAddExpenseSheet,
          icon: const Icon(Icons.add),
          label: const Text('Add Expense'),
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
    final dynamicShopTypes = {
      ..._defaultShopTypes,
      ...transactions.map((tx) => tx.shopType).where((type) => type.trim().isNotEmpty),
    }.toList()
      ..sort();
    final filterShopTypes = ['All', ...dynamicShopTypes];

    final dateQuery = _dateSearchController.text.trim().toLowerCase();
    final filteredTransactions = dateQuery.isEmpty
        ? transactions
        : transactions.where((tx) {
            final vendor = (tx.vendorName ?? tx.rawVendorName).toLowerCase();
            final category = tx.shopType.toLowerCase();
            return vendor.contains(dateQuery) || category.contains(dateQuery);
          }).toList();

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
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            controller: _dateSearchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Search date tab',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedShopType,
                  items: filterShopTypes
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
            itemCount: filteredTransactions.length,
            itemBuilder: (context, index) {
              final tx = filteredTransactions[index];
              return Card(
                color: tx.isClassified ? null : Colors.yellow.shade100,
                child: TransactionTile(
                  tx: tx,
                  onLongPress: () => _confirmDelete(tx),
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => EditTransactionSheet(
                      tx: tx,
                      shopTypes: dynamicShopTypes,
                      onSave: (vendorName, shopType, description) async {
                        await repo.updateClassification(tx, vendorName, shopType, description);
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
    final map = <String, ({double total, DateTime latest})>{};
    for (final tx in transactions) {
      final key = tx.vendorName ?? tx.rawVendorName;
      final existing = map[key];
      map[key] = (
        total: (existing?.total ?? 0) + tx.amount,
        latest: existing == null || tx.timestamp.isAfter(existing.latest) ? tx.timestamp : existing.latest
      );
    }
    final query = _vendorSearchController.text.trim().toLowerCase();
    final entries = map.entries
        .where((e) => query.isEmpty || e.key.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) => b.value.latest.compareTo(a.value.latest));
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            controller: _vendorSearchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Search vendor', prefixIcon: Icon(Icons.search)),
          ),
        ),
        ...entries
          .map((e) => ListTile(title: Text(e.key), trailing: Text('₹${e.value.total.toStringAsFixed(2)}')))
          .toList(),
      ],
    );
  }

  Widget _categoryView() {
    final map = <String, ({double total, DateTime latest})>{};
    for (final tx in transactions) {
      final existing = map[tx.shopType];
      map[tx.shopType] = (
        total: (existing?.total ?? 0) + tx.amount,
        latest: existing == null || tx.timestamp.isAfter(existing.latest) ? tx.timestamp : existing.latest
      );
    }
    final query = _categorySearchController.text.trim().toLowerCase();
    final entries = map.entries
        .where((e) => query.isEmpty || e.key.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) => b.value.latest.compareTo(a.value.latest));
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            controller: _categorySearchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Search category', prefixIcon: Icon(Icons.search)),
          ),
        ),
        ...entries
          .map(
            (e) => ListTile(
              title: Text(e.key),
              trailing: Text(
                '₹${e.value.total.toStringAsFixed(2)}',
                style: TextStyle(color: e.key == 'Salary' ? Colors.green : Colors.red),
              ),
            ),
          )
          .toList(),
      ],
    );
  }

  Future<void> _confirmDelete(TransactionItem tx) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text('Delete ${tx.vendorName ?? tx.rawVendorName} for ₹${tx.amount.toStringAsFixed(2)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (shouldDelete != true) return;
    await repo.deleteTransaction(tx.id);
    await _load();
  }

  Future<void> _openAddExpenseSheet() async {
    final amountController = TextEditingController();
    final vendorController = TextEditingController();
    final descriptionController = TextEditingController();
    final customTypeController = TextEditingController();
    var isCredit = false;
    var selectedType = 'Anonymous';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setInnerState) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Add Transaction', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount'),
                ),
                TextField(controller: vendorController, decoration: const InputDecoration(labelText: 'Shop/Vendor')),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  items: _defaultShopTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setInnerState(() => selectedType = v ?? 'Anonymous'),
                  decoration: const InputDecoration(labelText: 'Shop type'),
                ),
                TextField(controller: customTypeController, decoration: const InputDecoration(labelText: 'New shop type (optional)')),
                TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description (optional)')),
                SwitchListTile(
                  value: isCredit,
                  title: const Text('Mark as income'),
                  onChanged: (value) => setInnerState(() => isCredit = value),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text.trim());
                    final rawVendor = vendorController.text.trim();
                    if (amount == null || amount <= 0 || rawVendor.isEmpty) return;
                    final resolvedType = customTypeController.text.trim().isEmpty ? selectedType : customTypeController.text.trim();
                    await repo.addManualTransaction(
                      amount: amount,
                      type: isCredit ? 'credit' : 'debit',
                      rawVendorName: rawVendor,
                      vendorName: rawVendor,
                      shopType: resolvedType,
                      description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                    );
                    if (!mounted) return;
                    Navigator.pop(context);
                    await _load();
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
