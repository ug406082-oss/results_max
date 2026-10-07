import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/data_service.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final DataService _dataService = DataService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _schoolNameController = TextEditingController();
  final _schoolIdController = TextEditingController();
  String selectedRole = 'teacher'; // 'teacher' or 'principal'
  bool isLoading = false;

  static const bgColor = Color(0xFFF5F1E8);
  static const itemColor = Color(0xFF2B262C);

  Future<void> _createPersonalId() async {
    String email = _emailController.text.trim();
    String schoolName = _schoolNameController.text.trim();
    String schoolId = _schoolIdController.text.trim();

    if (_nameController.text.trim().isEmpty || email.isEmpty || _passwordController.text.trim().isEmpty || schoolName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all required fields (including School Name)')));
      return;
    }
    if (!email.contains('@') || email.contains(' ')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid email address without spaces (e.g. user@school.com)')));
      return;
    }

    if (selectedRole == 'principal' && schoolId.isEmpty) {
      schoolId = 'SCH-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
    }

    setState(() => isLoading = true);
    try {
      if (selectedRole == 'principal') {
        await _dataService.requestPrincipalId(
          name: _nameController.text.trim(),
          email: email,
          password: _passwordController.text.trim(),
          schoolName: schoolName,
          schoolId: schoolId,
          role: selectedRole,
        );
      } else {
        await _dataService.requestTeacherId(
          name: _nameController.text.trim(),
          email: email,
          password: _passwordController.text.trim(),
          role: selectedRole,
          schoolName: schoolName,
          schoolId: schoolId,
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_generic_blocked_on_device', true);
      await prefs.setString('custom_staff_email', email);
      if (schoolId.isNotEmpty) {
        await prefs.setString('school_id', schoolId);
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Request Submitted Successfully'),
            content: Text('Your personal ${selectedRole.toUpperCase()} ID request has been submitted to administration.\n\nSchool ID: $schoolId\n(Give this School ID to teachers joining your school).'),
            actions: [
              TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text('OK')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Profile Settings & Custom ID', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: itemColor)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'Request your personal staff ID and password. Once approved by administration, you can log in with it, and generic login will be permanently disabled on this PC.',
                style: TextStyle(fontSize: 12, color: itemColor),
              ),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: selectedRole,
              decoration: const InputDecoration(labelText: 'Role / Designation', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                DropdownMenuItem(value: 'principal', child: Text('Principal')),
              ],
              onChanged: (v) => setState(() => selectedRole = v ?? 'teacher'),
            ),
            const SizedBox(height: 16),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'New Personal Email / ID', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _schoolNameController, decoration: const InputDecoration(labelText: 'School Name (e.g. Springfield High)', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(
              controller: _schoolIdController, 
              decoration: InputDecoration(
                labelText: selectedRole == 'principal' ? 'School ID (Auto-generated if left blank)' : 'School ID (Provided by Principal)',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: itemColor,
                  foregroundColor: bgColor,
                  padding: const EdgeInsets.all(15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: isLoading ? null : _createPersonalId,
                child: isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: bgColor))
                    : const Text('SUBMIT ID FOR APPROVAL', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
