import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'manage_class_screen.dart';
import 'requests_screen.dart';
import 'attendance_log_screen.dart';
import 'profile_settings_screen.dart';
import 'admin_requests_screen.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';

class SettingsScreen extends StatelessWidget {
  final String role;
  const SettingsScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final bool isTeacher = role == 'teacher';
    final bool isPrincipal = role == 'principal';

    const itemColor = Color(0xFF2B262C);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F1E8),
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: itemColor)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: itemColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Database Management Section - Visible to Teacher and Principal
          if (isTeacher || isPrincipal) ...[
            _buildSectionHeader('Database Management'),
            _buildSettingsTile(
              context,
              icon: Icons.groups_outlined,
              title: 'Manage Class Data',
              subtitle: 'Update student names and class lists',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ManageClassScreen()),
                );
              },
            ),
          ],

          // Approval Section - ONLY visible to Principal
          if (isPrincipal) ...[
            _buildSettingsTile(
              context,
              icon: Icons.approval,
              title: 'Edit Requests',
              subtitle: 'Approve teacher requests to re-edit marks',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RequestsScreen()),
                );
              },
            ),
          ],

          // Admin Approvals Section - Visible to Admin
          if (role == 'admin') ...[
            _buildSectionHeader('System Approvals'),
            _buildSettingsTile(
              context,
              icon: Icons.admin_panel_settings_outlined,
              title: 'Principal ID Requests',
              subtitle: 'Approve or reject new school principal accounts',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminRequestsScreen()),
                );
              },
            ),
          ],

          const SizedBox(height: 10),
          _buildSectionHeader('General'),
          _buildSettingsTile(
            context,
            icon: Icons.person_outline,
            title: 'Profile Settings',
            subtitle: 'Create & lock personal teacher ID',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileSettingsScreen()),
              );
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.notifications_active_outlined,
            title: 'Notification Center & Attendance',
            subtitle: 'Batch attendance log (Open 1st-5th of month)',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AttendanceLogScreen()),
              );
            },
          ),

          const SizedBox(height: 10),
          _buildSectionHeader('System & Updates'),
          _buildSettingsTile(
            context,
            icon: Icons.system_update_rounded,
            title: 'Check for Updates',
            subtitle: 'Check PocketBase for a newer version of ResultMax',
            onTap: () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );
              final update = await DataService().checkForUpdates();
              if (context.mounted) {
                Navigator.pop(context); // pop progress
                if (update != null) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('New Update Available (${update['version_name']})'),
                      content: Text('A newer version of ResultMax is available on the server.\n\nDownload Link:\n${update['download_url']}'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                      ],
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('You are already using the latest version of ResultMax!')),
                  );
                }
              }
            },
          ),

          const SizedBox(height: 20),
          _buildSectionHeader('Account'),
          _buildSettingsTile(
            context,
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Sign out of your account',
            color: Colors.red,
            onTap: () async {
              await authService.signOut();
            },
          ),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'App Version 1.0.0',
              style: GoogleFonts.poppins(color: itemColor.withValues(alpha: 0.5), fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 10, top: 10),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2B262C)),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    final tileColor = color ?? const Color(0xFF2B262C);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: const Color(0xFF2B262C).withValues(alpha: 0.1)),
      ),
      color: Colors.white.withValues(alpha: 0.8),
      margin: const EdgeInsets.only(bottom: 15),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: tileColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: tileColor),
        ),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF2B262C))),
        subtitle: Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF2B262C).withValues(alpha: 0.6))),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF2B262C)),
        onTap: onTap,
      ),
    );
  }
}
