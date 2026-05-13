import 'dart:math';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/transaction_item.dart';
import '../models/parsed_sms_transaction.dart';
import 'local_database.dart';

class TransactionRepository {
  TransactionRepository();

  Future<String> get userId async =>
      dotenv.env['API_KEY_02_USER_ID'] ?? '550e8400-e29b-41d4-a716-446655440000';

  Future<void> seedIfEmpty() async {
    final database = await LocalDatabase.instance.db;
    final count = Sqflite.firstIntValue(await database.rawQuery('SELECT COUNT(*) FROM transactions')) ?? 0;
    if (count > 0) return;

    final now = DateTime.now().toUtc();
    final uid = await userId;
    final seed = [
      TransactionItem(
        id: _id(),
        userId: uid,
        amount: 499,
        type: 'debit',
        rawVendorName: 'AMZN INDIA',
        vendorName: 'Amazon',
        shopType: 'Shopping',
        timestamp: now.subtract(const Duration(hours: 2)),
        updatedAt: now,
      ),
      TransactionItem(
        id: _id(),
        userId: uid,
        amount: 25000,
        type: 'credit',
        rawVendorName: 'ACME PAYROLL',
        vendorName: 'ACME Corp',
        shopType: 'Salary',
        timestamp: now.subtract(const Duration(days: 1)),
        updatedAt: now,
      ),
      TransactionItem(
        id: _id(),
        userId: uid,
        amount: 150,
        type: 'debit',
        rawVendorName: 'UPI-XYZ-STORE',
        shopType: 'Anonymous',
        timestamp: now.subtract(const Duration(days: 3)),
        updatedAt: now,
      ),
    ];

    final batch = database.batch();
    for (final tx in seed) {
      batch.insert('transactions', tx.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<TransactionItem>> all({
    String? shopType,
    double? amountGt,
    DateTime? startDate,
    DateTime? endDate,
    bool latestFirst = true,
  }) async {
    final database = await LocalDatabase.instance.db;
    final uid = await userId;
    final where = <String>['user_id = ?'];
    final args = <Object>[uid];

    if (shopType != null && shopType != 'All') {
      where.add('shop_type = ?');
      args.add(shopType);
    }
    if (amountGt != null) {
      where.add('amount > ?');
      args.add(amountGt);
    }
    if (startDate != null) {
      where.add('tx_timestamp >= ?');
      args.add(startDate.toUtc().toIso8601String());
    }
    if (endDate != null) {
      where.add('tx_timestamp <= ?');
      args.add(endDate.toUtc().toIso8601String());
    }

    final rows = await database.query(
      'transactions',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: latestFirst ? 'tx_timestamp DESC' : 'tx_timestamp ASC',
      limit: 500,
    );

    return rows.map(TransactionItem.fromMap).toList();
  }

  Future<void> updateClassification(TransactionItem tx, String vendorName, String shopType, String? description) async {
    final database = await LocalDatabase.instance.db;
    final uid = await userId;
    final now = DateTime.now().toUtc();
    await database.update(
      'transactions',
      {
        'vendor_name': vendorName.trim().isEmpty ? null : vendorName.trim(),
        'shop_type': shopType,
        'description': description,
        'is_synced': 0,
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [tx.id, uid],
    );

    final nowIso = now.toIso8601String();
    await database.insert(
      'vendor_rules',
      {
        'normalized_raw_vendor_name': _normalize(tx.rawVendorName),
        'user_id': uid,
        'vendor_name': vendorName.trim().isEmpty ? tx.rawVendorName : vendorName.trim(),
        'shop_type': shopType,
        'is_synced': 0,
        'updated_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> addLocal(TransactionItem tx) async {
    final database = await LocalDatabase.instance.db;
    final uid = await userId;
    final rules = await database.query(
      'vendor_rules',
      where: 'normalized_raw_vendor_name = ? AND user_id = ?',
      whereArgs: [_normalize(tx.rawVendorName), uid],
      limit: 1,
    );
    if (rules.isNotEmpty) {
      final rule = rules.first;
      tx.vendorName = rule['vendor_name'] as String?;
      tx.shopType = (rule['shop_type'] as String?) ?? tx.shopType;
      tx.updatedAt = DateTime.now().toUtc();
      tx.isSynced = false;
    }
    await database.insert('transactions', tx.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> ingestParsedSms(List<ParsedSmsTransaction> smsRows) async {
    final database = await LocalDatabase.instance.db;
    final uid = await userId;
    var inserted = 0;

    for (final sms in smsRows) {
      final smsKey = _smsKey(sms);
      final seen = await database.query(
        'sms_ingest_log',
        where: 'sms_key = ? AND user_id = ?',
        whereArgs: [smsKey, uid],
        limit: 1,
      );
      if (seen.isNotEmpty) continue;

      final tx = TransactionItem(
        id: _id(),
        userId: uid,
        amount: sms.amount,
        type: sms.type,
        rawVendorName: sms.rawVendorName,
        timestamp: sms.timestamp,
        updatedAt: DateTime.now().toUtc(),
        description: 'Imported from SMS',
      );
      await addLocal(tx);
      await database.insert(
        'sms_ingest_log',
        {'sms_key': smsKey, 'user_id': uid, 'created_at': DateTime.now().toUtc().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      inserted += 1;
    }

    return inserted;
  }

  Future<void> syncNow() async {
    return;
  }

  Future<void> addManualTransaction({
    required double amount,
    required String type,
    required String rawVendorName,
    String? vendorName,
    required String shopType,
    String? description,
    DateTime? timestamp,
  }) async {
    final tx = TransactionItem(
      id: _id(),
      userId: await userId,
      amount: amount,
      type: type,
      rawVendorName: rawVendorName,
      vendorName: vendorName,
      shopType: shopType,
      description: description,
      timestamp: (timestamp ?? DateTime.now()).toUtc(),
      updatedAt: DateTime.now().toUtc(),
      isSynced: false,
    );
    await addLocal(tx);
  }

  Future<void> deleteTransaction(String transactionId) async {
    final database = await LocalDatabase.instance.db;
    final uid = await userId;
    await database.delete('transactions', where: 'id = ? AND user_id = ?', whereArgs: [transactionId, uid]);
  }

  Future<String> exportTransactionsCsv() async {
    final database = await LocalDatabase.instance.db;
    final uid = await userId;
    final rows = await database.query(
      'transactions',
      where: 'user_id = ?',
      whereArgs: [uid],
      orderBy: 'tx_timestamp DESC',
    );

    final buffer = StringBuffer();
    buffer.writeln('id,user_id,amount,type,raw_vendor_name,vendor_name,shop_type,tx_timestamp,description,is_synced,updated_at');
    for (final row in rows) {
      buffer.writeln([
        _csv(row['id']),
        _csv(row['user_id']),
        _csv(row['amount']),
        _csv(row['type']),
        _csv(row['raw_vendor_name']),
        _csv(row['vendor_name']),
        _csv(row['shop_type']),
        _csv(row['tx_timestamp']),
        _csv(row['description']),
        _csv(row['is_synced']),
        _csv(row['updated_at']),
      ].join(','));
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'transactions_export_${DateTime.now().toUtc().millisecondsSinceEpoch}.csv';
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(buffer.toString());
    return file.path;
  }

  Future<File> exportTransactionsCsvFile() async {
    final path = await exportTransactionsCsv();
    return File(path);
  }

  String _id() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rnd = Random().nextInt(1 << 20);
    return '$now$rnd';
  }

  String _normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\\s+'), ' ').trim();
  }

  String _smsKey(ParsedSmsTransaction sms) {
    return '${sms.sender}|${sms.timestamp.millisecondsSinceEpoch}|${sms.body.hashCode}';
  }

  String _csv(Object? value) {
    if (value == null) return '""';
    final raw = value.toString().replaceAll('"', '""');
    return '"$raw"';
  }
}
