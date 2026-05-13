import 'dart:convert';

import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';

import '../models/parsed_sms_transaction.dart';

class SmsImportService {
  final Telephony _telephony = Telephony.instance;
  static const _pendingKey = 'pending_sms_events_v1';
  static final RegExp _iciciStrictPattern = RegExp(
    r'^ICICI Bank Acct [A-Za-z0-9*Xx]{3,} debited for Rs\.?\s*(\d+(?:\.\d{1,2})?) on \d{2}-[A-Za-z]{3}-\d{2};\s*([A-Za-z0-9 .&\-]{2,60}?)\s+credited\.\s*UPI:(\d{10,20})\.\s*Call \d+ for dispute\.\s*SMS BLOCK \d+ to \d+\.$',
    caseSensitive: false,
  );

  Future<bool> ensureSmsPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  Future<List<ParsedSmsTransaction>> fetchRecentTransactions({int limit = 200}) async {
    final granted = await Permission.sms.isGranted;
    if (!granted) return [];

    final messages = await _telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    ).timeout(const Duration(seconds: 10), onTimeout: () => <SmsMessage>[]);

    final parsed = <ParsedSmsTransaction>[];
    for (final sms in messages.take(limit)) {
      final body = sms.body ?? '';
      final sender = sms.address ?? 'UNKNOWN';
      final tx = _parseSms(sender: sender, body: body, epochMs: sms.date ?? 0);
      if (tx != null) parsed.add(tx);
    }
    return parsed;
  }

  Future<void> startIncomingSmsListener({
    required void Function(ParsedSmsTransaction tx) onForegroundTransaction,
  }) async {
    final granted = await Permission.sms.isGranted;
    if (!granted) return;
    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage sms) {
        final tx = _parseSms(
          sender: sms.address ?? 'UNKNOWN',
          body: sms.body ?? '',
          epochMs: sms.date ?? DateTime.now().millisecondsSinceEpoch,
        );
        if (tx != null) onForegroundTransaction(tx);
      },
      onBackgroundMessage: backgroundMessageHandler,
      listenInBackground: true,
    );
  }

  Future<List<ParsedSmsTransaction>> consumePendingBackgroundSms() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_pendingKey) ?? <String>[];
    if (raw.isEmpty) return [];
    final parsed = <ParsedSmsTransaction>[];
    for (final item in raw) {
      try {
        final map = jsonDecode(item) as Map<String, dynamic>;
        parsed.add(
          ParsedSmsTransaction(
            sender: map['sender'] as String,
            body: map['body'] as String,
            timestamp: DateTime.parse(map['timestamp'] as String),
            amount: (map['amount'] as num).toDouble(),
            type: map['type'] as String,
            rawVendorName: map['rawVendorName'] as String,
          ),
        );
      } catch (_) {}
    }
    await prefs.remove(_pendingKey);
    return parsed;
  }

  static Future<void> _queueBackgroundTx(ParsedSmsTransaction tx) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_pendingKey) ?? <String>[];
    list.add(
      jsonEncode({
        'sender': tx.sender,
        'body': tx.body,
        'timestamp': tx.timestamp.toIso8601String(),
        'amount': tx.amount,
        'type': tx.type,
        'rawVendorName': tx.rawVendorName,
      }),
    );
    await prefs.setStringList(_pendingKey, list);
  }

  @pragma('vm:entry-point')
  static void backgroundMessageHandler(SmsMessage sms) async {
    final tx = _tryParseBackgroundSms(sms);
    if (tx != null) {
      await _queueBackgroundTx(tx);
    }
  }

  static ParsedSmsTransaction? _tryParseBackgroundSms(SmsMessage sms) {
    final sender = sms.address ?? 'UNKNOWN';
    final body = sms.body ?? '';
    final parsed = _parseStrictIciciUpiDebit(sender: sender, body: body);
    if (parsed == null) return null;
    return ParsedSmsTransaction(
      sender: parsed.sender,
      body: parsed.body,
      timestamp: DateTime.fromMillisecondsSinceEpoch(sms.date ?? DateTime.now().millisecondsSinceEpoch, isUtc: true),
      amount: parsed.amount,
      type: parsed.type,
      rawVendorName: parsed.rawVendorName,
    );
  }

  ParsedSmsTransaction? _parseSms({required String sender, required String body, required int epochMs}) {
    final parsed = _parseStrictIciciUpiDebit(sender: sender, body: body);
    if (parsed == null) return null;

    return ParsedSmsTransaction(
      sender: parsed.sender,
      body: parsed.body,
      timestamp: DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true),
      amount: parsed.amount,
      type: parsed.type,
      rawVendorName: parsed.rawVendorName,
    );
  }

  static ParsedSmsTransaction? _parseStrictIciciUpiDebit({required String sender, required String body}) {
    final normalized = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    final match = _iciciStrictPattern.firstMatch(normalized);
    if (match == null) return null;
    final amount = double.tryParse(match.group(1) ?? '');
    if (amount == null) return null;
    final vendor = (match.group(2) ?? sender).trim();
    return ParsedSmsTransaction(
      sender: sender,
      body: normalized,
      timestamp: DateTime.now().toUtc(),
      amount: amount,
      type: 'debit',
      rawVendorName: vendor,
    );
  }
}
