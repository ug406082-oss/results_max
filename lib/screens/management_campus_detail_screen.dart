import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/data_service.dart';
import 'management_class_results_screen.dart';

class ManagementCampusDetailScreen extends StatefulWidget {
  final String schoolName;
  const ManagementCampusDetailScreen({super.key, required this.schoolName});

  @override
  State<ManagementCampusDetailScreen> createState() => _ManagementCampusDetailScreenState();
}

class _ManagementCampusDetailScreenState extends State<ManagementCampusDetailScreen> with SingleTickerProviderStateMixin {
  final DataService _dataService = DataService();
  late TabController _tabController;
  bool isLoading = true;

  List<Map<String, dynamic>> students = [];
  List<RecordModel> results = [];

  static const bgColor = Color(0xFFF5F1E8);
  static const itemColor = Color(0xFF2B262C);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCampusData();
  }

  Future<void> _loadCampusData() async {
    setState(() => isLoading = true);
    final fetchedStudents = await _dataService.getStudentsForSchool(widget.schoolName);
    final fetchedResults = await _dataService.getResultsForSchool(widget.schoolName);

    if (mounted) {
      setState(() {
        students = fetchedStudents;
        results = fetchedResults;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.schoolName, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: itemColor)),
            Text('Simple Management View', style: GoogleFonts.inter(fontSize: 11, color: itemColor.withValues(alpha: 0.6))),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: itemColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: itemColor),
            onPressed: _loadCampusData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: itemColor,
          unselectedLabelColor: itemColor.withValues(alpha: 0.5),
          indicatorColor: itemColor,
          tabs: const [
            Tab(text: 'Students Performance'),
            Tab(text: 'Teacher Performance'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: itemColor))
          : TabBarView(
              controller: _tabController,
              children: [
                // Section 1: Students Performance (Classes listed -> click class -> recent results & individual student)
                _buildStudentsPerformanceSection(),
                // Section 2: Teacher Performance (Performance of the class they entered result of)
                _buildTeacherPerformanceSection(),
              ],
            ),
    );
  }

  Widget _buildStudentsPerformanceSection() {
    // Group students by Grade & Section
    Map<String, List<Map<String, dynamic>>> classMap = {};
    for (var s in students) {
      String grade = s['grade'] ?? '6';
      String sec = s['section'] ?? 'None';
      if (sec.isEmpty) sec = 'None';
      String key = '$grade|$sec';
      classMap.putIfAbsent(key, []).add(s);
    }

    if (classMap.isEmpty) {
      return Center(
        child: Text('No classes or students registered for this campus.', style: GoogleFonts.inter(color: itemColor.withValues(alpha: 0.6))),
      );
    }

    // Sort classes by grade
    var sortedKeys = classMap.keys.toList()..sort((a, b) {
      int gA = int.tryParse(a.split('|')[0]) ?? 0;
      int gB = int.tryParse(b.split('|')[0]) ?? 0;
      return gA.compareTo(gB);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(24.0),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        String key = sortedKeys[index];
        var parts = key.split('|');
        String grade = parts[0];
        String section = parts[1];
        String displaySec = section == 'None' ? 'Entire Class' : 'Section $section';
        List<Map<String, dynamic>> classStudents = classMap[key] ?? [];

        // Calculate class average percentage from results
        var classResults = results.where((r) {
          String rG = r.getStringValue('grade');
          String rS = r.getStringValue('section');
          if (rS.isEmpty) rS = 'None';
          return rG == grade && rS == section;
        }).toList();

        double obt = classResults.fold(0.0, (sum, r) => sum + r.getDoubleValue('marks'));
        double max = classResults.fold(0.0, (sum, r) => sum + r.getDoubleValue('totalMarks'));
        double classPct = max > 0 ? (obt / max) * 100 : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: itemColor.withValues(alpha: 0.1)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            leading: CircleAvatar(
              backgroundColor: itemColor.withValues(alpha: 0.05),
              child: Text(grade, style: const TextStyle(color: itemColor, fontWeight: FontWeight.bold)),
            ),
            title: Text('Grade $grade ($displaySec)', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: itemColor)),
            subtitle: Text('${classStudents.length} Students | ${classResults.length} Exam Records\nAverage: ${classPct > 0 ? "${classPct.toStringAsFixed(1)}%" : "No exams yet"}', style: GoogleFonts.inter(fontSize: 12, color: itemColor.withValues(alpha: 0.7))),
            isThreeLine: true,
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: itemColor),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ManagementClassResultsScreen(
                    schoolName: widget.schoolName,
                    grade: grade,
                    section: section,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTeacherPerformanceSection() {
    // Group results by teacher name
    Map<String, List<RecordModel>> teacherMap = {};
    for (var r in results) {
      String tName = r.getStringValue('teacher_name');
      if (tName.isEmpty) tName = 'Staff Teacher';
      teacherMap.putIfAbsent(tName, []).add(r);
    }

    if (teacherMap.isEmpty) {
      return Center(
        child: Text('No teacher result submissions logged yet.', style: GoogleFonts.inter(color: itemColor.withValues(alpha: 0.6))),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24.0),
      itemCount: teacherMap.length,
      itemBuilder: (context, index) {
        String teacherName = teacherMap.keys.toList()[index];
        List<RecordModel> tResults = teacherMap[teacherName] ?? [];

        // Find classes and subjects this teacher entered results for
        Map<String, int> classSubCount = {};
        double tObt = 0;
        double tMax = 0;

        for (var r in tResults) {
          String g = r.getStringValue('grade');
          String sec = r.getStringValue('section');
          if (sec.isEmpty) sec = 'None';
          String sub = r.getStringValue('subject');
          String key = 'Grade $g ($sec) - $sub';
          classSubCount[key] = (classSubCount[key] ?? 0) + 1;

          tObt += r.getDoubleValue('marks');
          tMax += r.getDoubleValue('totalMarks');
        }

        double tPct = tMax > 0 ? (tObt / tMax) * 100 : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: itemColor.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: itemColor.withValues(alpha: 0.1),
                    child: Text(teacherName.isNotEmpty ? teacherName.substring(0, 1).toUpperCase() : 'T', style: const TextStyle(color: itemColor, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(teacherName, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: itemColor)),
                        const SizedBox(height: 2),
                        Text('${tResults.length} Total Submissions Logged', style: GoogleFonts.inter(fontSize: 12, color: itemColor.withValues(alpha: 0.6))),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${tPct.toStringAsFixed(1)}%', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: tPct >= 50 ? Colors.green.shade700 : Colors.red.shade700)),
                      const Text('Class Avg', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text('Classes & Subjects Entered:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: itemColor.withValues(alpha: 0.7))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: classSubCount.entries.map((e) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: itemColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: itemColor.withValues(alpha: 0.1)),
                    ),
                    child: Text('${e.key} (${e.value} entries)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: itemColor)),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
