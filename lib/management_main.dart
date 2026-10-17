import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/management_home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ResultMaxManagementApp());
}

class ResultMaxManagementApp extends StatelessWidget {
  const ResultMaxManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFF5F1E8);
    const itemColor = Color(0xFF2B262C);

    return MaterialApp(
      title: 'ResultMax Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: itemColor,
          primary: itemColor,
          surface: bgColor,
        ),
        textTheme: GoogleFonts.interTextTheme().apply(
          bodyColor: itemColor,
          displayColor: itemColor,
        ),
        scaffoldBackgroundColor: bgColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: itemColor),
          titleTextStyle: TextStyle(
            color: itemColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const ManagementAuthWrapper(),
    );
  }
}

class ManagementAuthWrapper extends StatefulWidget {
  const ManagementAuthWrapper({super.key});

  @override
  State<ManagementAuthWrapper> createState() => _ManagementAuthWrapperState();
}

class _ManagementAuthWrapperState extends State<ManagementAuthWrapper> {
  final AuthService _authService = AuthService();
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    try {
      await _authService.trySilentAutoLogin();
    } catch (_) {}
    if (mounted) setState(() => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2B262C)),
        ),
      );
    }

    if (!_authService.isLoggedIn) {
      return const LoginScreen();
    }

    return const ManagementHomeScreen();
  }
}
