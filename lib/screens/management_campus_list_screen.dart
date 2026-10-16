import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import 'management_campus_detail_screen.dart';

class ManagementCampusListScreen extends StatefulWidget {
  const ManagementCampusListScreen({super.key});

  @override
  State<ManagementCampusListScreen> createState() => _ManagementCampusListScreenState();
}

class _ManagementCampusListScreenState extends State<ManagementCampusListScreen> {
  final DataService _dataService = DataService();
  final AuthService _authService = AuthService();
  bool isLoading = true;
  List<String> schoolNames = [];

  static const bgColor = Color(0xFFF5F1E8);
  static const itemColor = Color(0xFF2B262C);

  @override
  void initState() {
    super.initState();
    _loadCampuses();
  }

  Future<void> _loadCampuses() async {
    setState(() => isLoading = true);
    final names = await _dataService.getSyedanwalaSchoolNames();
    if (mounted) {
      setState(() {
        schoolNames = names;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Syedanwala Campuses', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: itemColor)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: itemColor),
            tooltip: 'Sign Out',
            onPressed: () => _authService.signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: itemColor))
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select School Campus', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: itemColor, letterSpacing: -0.5)),
                    const SizedBox(height: 6),
                    Text('Choose a Syedanwala campus to view its results, classes, and student profiles.', style: GoogleFonts.inter(color: itemColor.withValues(alpha: 0.6))),
                    const SizedBox(height: 24),
                    Expanded(
                      child: schoolNames.isEmpty
                          ? Center(child: Text('No Syedanwala campuses found.', style: GoogleFonts.inter(color: itemColor.withValues(alpha: 0.6))))
                          : ListView.builder(
                              itemCount: schoolNames.length,
                              itemBuilder: (context, index) {
                                final sName = schoolNames[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: itemColor.withValues(alpha: 0.1)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: itemColor.withValues(alpha: 0.03),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                    leading: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(color: itemColor.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14)),
                                      child: const Icon(Icons.school_rounded, color: itemColor, size: 28),
                                    ),
                                    title: Text(sName, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: itemColor)),
                                    subtitle: const Padding(
                                      padding: EdgeInsets.only(top: 4.0),
                                      child: Text('Tap to open campus dashboard & student records', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: itemColor, borderRadius: BorderRadius.circular(10)),
                                      child: const Icon(Icons.arrow_forward_rounded, color: bgColor, size: 18),
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => ManagementCampusDetailScreen(schoolName: sName)),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
