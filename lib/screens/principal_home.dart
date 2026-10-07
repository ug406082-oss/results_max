import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';

class PrincipalHomeScreen extends StatefulWidget {
  const PrincipalHomeScreen({super.key});

  @override
  State<PrincipalHomeScreen> createState() => _PrincipalHomeScreenState();
}

class _PrincipalHomeScreenState extends State<PrincipalHomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const SettingsScreen(role: 'principal'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
