import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._();
  LocalDatabase._();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'expense_tracker.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE transactions (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            amount REAL NOT NULL,
            type TEXT NOT NULL,
            raw_vendor_name TEXT NOT NULL,
            vendor_name TEXT,
            shop_type TEXT NOT NULL DEFAULT 'Anonymous',
            tx_timestamp TEXT NOT NULL,
            description TEXT,
            is_synced INTEGER NOT NULL DEFAULT 0,
            updated_at TEXT NOT NULL
          )
        ''');
        await database.execute('CREATE INDEX idx_tx_user_time ON transactions(user_id, tx_timestamp)');
        await database.execute('''
          CREATE TABLE vendor_rules (
            normalized_raw_vendor_name TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            vendor_name TEXT NOT NULL,
            shop_type TEXT NOT NULL,
            is_synced INTEGER NOT NULL DEFAULT 0,
            updated_at TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE sms_ingest_log (
            sms_key TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }
}
