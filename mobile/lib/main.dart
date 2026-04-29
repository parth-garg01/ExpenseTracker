import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatefulWidget {
  const ExpenseTrackerApp({super.key});

  @override
  State<ExpenseTrackerApp> createState() => _ExpenseTrackerAppState();
}

class _ExpenseTrackerAppState extends State<ExpenseTrackerApp> {
  final AuthService _authService = AuthService();
  bool _ready = false;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final session = await _authService.getSession();
    if (!mounted) return;
    setState(() {
      _loggedIn = session != null;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Expense Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        useMaterial3: true,
      ),
      home: !_ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _loggedIn
              ? DashboardScreen(
                  onLogout: () async {
                    await _authService.logout();
                    if (!mounted) return;
                    setState(() => _loggedIn = false);
                  },
                )
              : AuthScreen(
                  onAuthenticated: () {
                    setState(() => _loggedIn = true);
                  },
                ),
    );
  }
}
