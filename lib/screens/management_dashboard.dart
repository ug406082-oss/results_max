import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/data_service.dart';
import 'dashboard_screen.dart';

class ManagementDashboard extends StatefulWidget {
  const ManagementDashboard({super.key});

  @override
  State<ManagementDashboard> createState() => _ManagementDashboardState();
}

class _ManagementDashboardState extends State<ManagementDashboard> {
  final DataService _dataService = DataService();
  bool isLoading = true;
  List<Map<String, dynamic>> schoolOverviews = [];

  static const bgColor = Color(0xFFF5F1E8);
  static const itemColor = Color(0xFF2B262C);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    final overviews = await _dataService.getSyedanwalaSchoolsOverview();
    if (mounted) {
      setState(() {
        schoolOverviews = overviews;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalSchools = schoolOverviews.length;
    int totalStudents = schoolOverviews.fold(0, (sum, item) => sum + (item['student_count'] as int? ?? 0));
    double avgPerformance = totalSchools > 0
        ? schoolOverviews.fold(0.0, (sum, item) => sum + (item['avg_percentage'] as double? ?? 0.0)) / totalSchools
        : 0.0;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: itemColor))
            : RefreshIndicator(
                onRefresh: _loadData,
                color: itemColor,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.between,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Syedanwala Management', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: itemColor, letterSpacing: -0.5)),
                              const SizedBox(height: 4),
                              Text('Overview of Syedanwala school campuses', style: GoogleFonts.inter(color: itemColor.withValues(alpha: 0.6))),
                            ],
                          ),
                          IconButton(
                            onPressed: _loadData,
                            icon: const Icon(Icons.refresh_rounded, color: itemColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Summary Stats Cards
                      Row(
                        children: [
                          Expanded(child: _buildStatCard('Campuses', totalSchools.toString(), Icons.school_rounded)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildStatCard('Total Students', totalStudents.toString(), Icons.groups_rounded)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildStatCard('Avg Performance', '${avgPerformance.toStringAsFixed(1)}%', Icons.analytics_rounded)),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.between,
                        children: [
                          Text('Campus Breakdown', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: itemColor)),
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: itemColor),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const Scaffold(body: DashboardScreen())),
                              );
                            },
                            icon: const Icon(Icons.analytics_outlined, size: 16),
                            label: const Text('Advanced View'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (schoolOverviews.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
                          child: Text('No schools found containing "syedanwala"', style: GoogleFonts.inter(color: itemColor.withValues(alpha: 0.6))),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: schoolOverviews.length,
                          itemBuilder: (context, index) {
                            final school = schoolOverviews[index];
                            String name = school['school_name'] ?? 'Syedanwala Campus';
                            int count = school['student_count'] ?? 0;
                            double pct = school['avg_percentage'] ?? 0.0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: itemColor.withValues(alpha: 0.1)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: itemColor.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
                                    child: const Icon(Icons.business_rounded, color: itemColor),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: itemColor)),
                                        const SizedBox(height: 4),
                                        Text('$count Registered Students', style: GoogleFonts.inter(fontSize: 12, color: itemColor.withValues(alpha: 0.6))),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('${pct.toStringAsFixed(1)}%', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: pct >= 50 ? Colors.green.shade700 : Colors.orange.shade800)),
                                      const SizedBox(height: 4),
                                      Text('Average', style: GoogleFonts.inter(fontSize: 10, color: itemColor.withValues(alpha: 0.5))),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: itemColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: itemColor, size: 20),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: itemColor)),
          const SizedBox(height: 4),
          Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: itemColor.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}
