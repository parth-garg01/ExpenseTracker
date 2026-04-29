import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onAuthenticated});

  final void Function() onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  bool _registerMode = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      if (_registerMode) {
        await _auth.register(_email.text.trim(), _password.text);
      } else {
        await _auth.login(_email.text.trim(), _password.text);
      }
      widget.onAuthenticated();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication failed')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_registerMode ? 'Register' : 'Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: _password, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loading ? null : _submit, child: Text(_registerMode ? 'Create account' : 'Login')),
            TextButton(
              onPressed: _loading ? null : () => setState(() => _registerMode = !_registerMode),
              child: Text(_registerMode ? 'Have an account? Login' : 'Need an account? Register'),
            )
          ],
        ),
      ),
    );
  }
}
