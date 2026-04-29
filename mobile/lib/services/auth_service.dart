import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  String get _baseUrl => dotenv.env['API_KEY_01_API_BASE_URL'] ?? 'http://10.0.2.2:8000';

  Future<Map<String, String>> register(String email, String password) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode >= 400) throw Exception('Register failed');
    return _saveSession(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Map<String, String>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode >= 400) throw Exception('Login failed');
    return _saveSession(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Map<String, String>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userId = prefs.getString('user_id');
    if (token == null || userId == null) return null;
    return {'token': token, 'user_id': userId};
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
  }

  Future<Map<String, String>> _saveSession(Map<String, dynamic> payload) async {
    final token = payload['access_token'] as String;
    final userId = payload['user_id'] as String;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('user_id', userId);
    return {'token': token, 'user_id': userId};
  }
}
