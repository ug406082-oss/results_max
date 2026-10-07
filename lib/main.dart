import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/teacher_home.dart';
import 'screens/principal_home.dart';
import 'screens/admin_home.dart';
import 'package:pocketbase/pocketbase.dart';

import 'screens/developer_home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ResultMaxApp());
}

class ResultMaxApp extends StatelessWidget {
  const ResultMaxApp({super.key});

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFF5F1E8);
    const itemColor = Color(0xFF2B262C);

    return MaterialApp(
      title: 'ResultMax',
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
        cardTheme: CardThemeData(
          color: Colors.white.withValues(alpha: 0.8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: itemColor.withValues(alpha: 0.1)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: bgColor,
          indicatorColor: itemColor.withValues(alpha: 0.1),
          labelTextStyle: WidgetStateProperty.all(
            GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: itemColor),
          ),
          iconTheme: WidgetStateProperty.all(
            const IconThemeData(color: itemColor),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthStoreEvent?>(
      stream: _authService.authStream,
      builder: (context, snapshot) {
        if (!_authService.isLoggedIn) {
          return const LoginScreen();
        }

        final uid = _authService.currentUserId;
        if (uid == null) return const LoginScreen();

        return FutureBuilder<String?>(
          future: _authService.getUserRole(uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF2B262C))));
            }

            final role = roleSnapshot.data?.toLowerCase().trim();
            if (role == 'teacher') {
              return const TeacherHomeScreen();
            } else if (role == 'principal') {
              return const PrincipalHomeScreen();
            } else if (role == 'management' || role == 'admin') {
              return const AdminHomeScreen();
            } else if (role == 'developer') {
              return const DeveloperHomeScreen();
            } else {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('No valid role found: "${roleSnapshot.data}"', style: const TextStyle(color: Color(0xFF2B262C))),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => _authService.signOut(),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2B262C), foregroundColor: Colors.white),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}
