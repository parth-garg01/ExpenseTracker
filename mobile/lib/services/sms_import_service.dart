import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';

import '../models/parsed_sms_transaction.dart';

class SmsImportService {
  final Telephony _telephony = Telephony.instance;

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
    );

    final parsed = <ParsedSmsTransaction>[];
    for (final sms in messages.take(limit)) {
      final body = sms.body ?? '';
      final sender = sms.address ?? 'UNKNOWN';
      final tx = _parseSms(sender: sender, body: body, epochMs: sms.date ?? 0);
      if (tx != null) parsed.add(tx);
    }
    return parsed;
  }

  ParsedSmsTransaction? _parseSms({required String sender, required String body, required int epochMs}) {
    final lower = body.toLowerCase();
    final hasTxKeyword = lower.contains('debited') || lower.contains('credited') || lower.contains('spent') || lower.contains('received') || lower.contains('paid');
    if (!hasTxKeyword) return null;

    final amountRegex = RegExp(r'(?:inr|rs\.?|₹)\s*(\d+(?:\.\d{1,2})?)', caseSensitive: false);
    final amountMatch = amountRegex.firstMatch(body);
    if (amountMatch == null) return null;

    final amount = double.tryParse(amountMatch.group(1) ?? '');
    if (amount == null) return null;

    final type = (lower.contains('credited') || lower.contains('received')) ? 'credit' : 'debit';

    final vendorRegex = RegExp(r'(?:to|at|from)\s+([A-Za-z0-9 _\-.]{2,40})', caseSensitive: false);
    final vendorMatch = vendorRegex.firstMatch(body);
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
