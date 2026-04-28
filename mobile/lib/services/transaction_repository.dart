import 'dart:math';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sqflite/sqflite.dart';

import '../models/transaction_item.dart';
import 'local_database.dart';
import 'sync_service.dart';

class TransactionRepository {
  TransactionRepository({SyncService? syncService}) : _syncService = syncService ?? SyncService();

  final SyncService _syncService;

  String get userId =>
      dotenv.env['API_KEY_02_USER_ID'] ?? '550e8400-e29b-41d4-a716-446655440000';

  Future<void> seedIfEmpty() async {
    final database = await LocalDatabase.instance.db;
    final count = Sqflite.firstIntValue(await database.rawQuery('SELECT COUNT(*) FROM transactions')) ?? 0;
    if (count > 0) return;

    final now = DateTime.now().toUtc();
    final seed = [
      TransactionItem(
        id: _id(),
        userId: userId,
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
        userId: userId,
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
        userId: userId,
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
    final where = <String>['user_id = ?'];
    final args = <Object>[userId];

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
      whereArgs: [tx.id, userId],
    );
  }

  Future<void> addLocal(TransactionItem tx) async {
    final database = await LocalDatabase.instance.db;
    await database.insert('transactions', tx.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> syncNow() async {
    final database = await LocalDatabase.instance.db;
    final unsyncedRows = await database.query('transactions', where: 'user_id = ? AND is_synced = 0', whereArgs: [userId]);
    final unsynced = unsyncedRows.map(TransactionItem.fromMap).toList();

    await _syncService.pushChanges(userId, unsynced);

    if (unsynced.isNotEmpty) {
      await database.update('transactions', {'is_synced': 1}, where: 'user_id = ? AND is_synced = 0', whereArgs: [userId]);
    }

    final since = await _lastSyncTime(database);
    final remote = await _syncService.pullChanges(userId, since);
    for (final raw in remote) {
      final incoming = TransactionItem.fromMap(raw);
      final local = await database.query('transactions', where: 'id = ? AND user_id = ?', whereArgs: [incoming.id, userId], limit: 1);

      if (local.isEmpty) {
        await database.insert('transactions', incoming.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        continue;
      }

      final localTx = TransactionItem.fromMap(local.first);
      if (incoming.updatedAt.isAfter(localTx.updatedAt)) {
        await database.update('transactions', incoming.toMap(), where: 'id = ? AND user_id = ?', whereArgs: [incoming.id, userId]);
      }
    }
  }

  Future<String?> _lastSyncTime(Database database) async {
    final rows = await database.rawQuery('SELECT MAX(updated_at) as last_time FROM transactions WHERE user_id = ?', [userId]);
    if (rows.isEmpty) return null;
    return rows.first['last_time'] as String?;
  }

  String _id() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rnd = Random().nextInt(1 << 20);
    return '$now$rnd';
  }
}
