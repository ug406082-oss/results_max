import 'package:flutter/material.dart';
import 'management_campus_list_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';

class ManagementHomeScreen extends StatefulWidget {
  const ManagementHomeScreen({super.key});

  @override
  State<ManagementHomeScreen> createState() => _ManagementHomeScreenState();
}

class _ManagementHomeScreenState extends State<ManagementHomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const ManagementCampusListScreen(),
    const DashboardScreen(),
    const SettingsScreen(role: 'management'),
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
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Campuses',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Advanced',
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
