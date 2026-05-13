import 'dart:convert';

import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';

import '../models/parsed_sms_transaction.dart';

class SmsImportService {
  final Telephony _telephony = Telephony.instance;
  static const _pendingKey = 'pending_sms_events_v1';
  static final RegExp _strictUpiBankAlert = RegExp(
    r'(?i)\b(?:icici|hdfc|sbi|axis|kotak|bank)\b.*\b(?:acct|a\/c|account)\b.*\bdebited\b.*\bupi:\d+',
  );
  static final RegExp _debitedAmountRegex = RegExp(
    r'(?i)\bdebited\s+for\s+(?:inr|rs\.?|₹)\s*(\d+(?:\.\d{1,2})?)',
  );
  static final RegExp _creditedPartyRegex = RegExp(r';\s*([^;]+?)\s+credited\.', caseSensitive: false);

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
    final lower = body.toLowerCase();
    if (!_strictUpiBankAlert.hasMatch(body)) return null;
    final amountMatch = _debitedAmountRegex.firstMatch(body);
    if (amountMatch == null) return null;
    final amount = double.tryParse(amountMatch.group(1) ?? '');
    if (amount == null) return null;
    final type = lower.contains('debited') ? 'debit' : 'credit';
    final vendorMatch = _creditedPartyRegex.firstMatch(body);
    final vendor = (vendorMatch?.group(1)?.trim().isNotEmpty ?? false) ? vendorMatch!.group(1)!.trim() : sender;
    return ParsedSmsTransaction(
      sender: sender,
      body: body,
      timestamp: DateTime.fromMillisecondsSinceEpoch(sms.date ?? DateTime.now().millisecondsSinceEpoch, isUtc: true),
      amount: amount,
      type: type,
      rawVendorName: vendor,
    );
  }

  ParsedSmsTransaction? _parseSms({required String sender, required String body, required int epochMs}) {
    final lower = body.toLowerCase();
    if (!_strictUpiBankAlert.hasMatch(body)) return null;

    final amountMatch = _debitedAmountRegex.firstMatch(body);
    if (amountMatch == null) return null;

    final amount = double.tryParse(amountMatch.group(1) ?? '');
    if (amount == null) return null;

    final type = lower.contains('debited') ? 'debit' : 'credit';

    final vendorMatch = _creditedPartyRegex.firstMatch(body);
    final vendor = (vendorMatch?.group(1)?.trim().isNotEmpty ?? false) ? vendorMatch!.group(1)!.trim() : sender;

    return ParsedSmsTransaction(
      sender: sender,
      body: body,
      timestamp: DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true),
      amount: amount,
      type: type,
      rawVendorName: vendor,
    );
  }
}
