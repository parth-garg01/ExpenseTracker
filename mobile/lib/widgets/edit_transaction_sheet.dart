import 'package:flutter/material.dart';

import '../models/transaction_item.dart';

class EditTransactionSheet extends StatefulWidget {
  const EditTransactionSheet({
    super.key,
    required this.tx,
    required this.shopTypes,
    required this.onSave,
  });

  final TransactionItem tx;
  final List<String> shopTypes;
  final void Function(String vendorName, String shopType, String? description) onSave;

  @override
  State<EditTransactionSheet> createState() => _EditTransactionSheetState();
}

class _EditTransactionSheetState extends State<EditTransactionSheet> {
  late final TextEditingController _vendorController;
  late final TextEditingController _descriptionController;
  late String _shopType;

  @override
  void initState() {
    super.initState();
    _vendorController = TextEditingController(text: widget.tx.vendorName ?? '');
    _descriptionController = TextEditingController(text: widget.tx.description ?? '');
    _shopType = widget.tx.shopType;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _vendorController, decoration: const InputDecoration(labelText: 'Shop name')),
          DropdownButtonFormField<String>(
            value: _shopType,
            items: widget.shopTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (value) => setState(() => _shopType = value ?? 'Anonymous'),
            decoration: const InputDecoration(labelText: 'Shop type'),
          ),
          TextField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Description (optional)')),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              widget.onSave(_vendorController.text, _shopType, _descriptionController.text.isEmpty ? null : _descriptionController.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
