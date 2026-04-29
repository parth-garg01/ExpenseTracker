import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

import '../models/transaction_item.dart';

class SyncService {
  String get _baseUrl => dotenv.env['API_KEY_01_API_BASE_URL'] ?? 'http://10.0.2.2:8000';
  final AuthService _auth = AuthService();

  Future<void> pushChanges(String userId, List<TransactionItem> unsynced) async {
    if (unsynced.isEmpty) return;
    final session = await _auth.getSession();
    if (session == null) return;
    await http.post(
      Uri.parse('$_baseUrl/api/sync/push'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${session['token']}'},
      body: jsonEncode({
        'transactions': unsynced.map((t) => t.toMap()).toList(),
      }),
    );
  }

  Future<List<Map<String, dynamic>>> pullChanges(String userId, String? since) async {
    final session = await _auth.getSession();
    if (session == null) return [];
    final uri = Uri.parse('$_baseUrl/api/sync/pull').replace(queryParameters: {'since': since ?? ''});
    final response = await http.get(uri, headers: {'Authorization': 'Bearer ${session['token']}'});
    if (response.statusCode != 200) return [];
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return ((payload['transactions'] as List?) ?? []).cast<Map<String, dynamic>>();
  }
}
