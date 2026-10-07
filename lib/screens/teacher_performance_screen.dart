import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/pocketbase_service.dart';
import '../services/data_service.dart';

class TeacherPerformanceScreen extends StatefulWidget {
  const TeacherPerformanceScreen({super.key});

  @override
  State<TeacherPerformanceScreen> createState() => _TeacherPerformanceScreenState();
}

class _TeacherPerformanceScreenState extends State<TeacherPerformanceScreen> {
  final DataService _dataService = DataService();
  bool isLoading = true;
  List<Map<String, dynamic>> teacherStats = [];
  String schoolNameHeader = '';
  String schoolIdHeader = '';

  static const bgColor = Color(0xFFF5F1E8);
  static const itemColor = Color(0xFF2B262C);

  @override
  void initState() {
    super.initState();
    _loadTeacherPerformance();
  }

  Future<void> _loadTeacherPerformance() async {
    setState(() => isLoading = true);
    try {
      final schoolInfo = await _dataService.getCurrentUserSchoolInfo();
      String schoolId = schoolInfo['school_id'] ?? '';
      String schoolName = schoolInfo['school_name'] ?? '';
      
      setState(() {
        schoolIdHeader = schoolId;
        schoolNameHeader = schoolName;
      });
      
      // Only include newly entered data that has teacher_name stamped
      String filter = schoolId.isNotEmpty ? 'school_id = "$schoolId" && teacher_name != ""' : 'teacher_name != ""';
      final results = await PBService().client.collection('rm_student_result').getFullList(filter: filter);

      // Group by Teacher Name + Class (Grade & Section) + Subject
      Map<String, List<RecordModel>> grouped = {};
      for (var r in results) {
        String teacher = r.getStringValue('teacher_name');
        if (teacher.isEmpty) continue; // Exclude legacy unstamped data
        String grade = r.getStringValue('grade');
        String section = r.getStringValue('section');
        String subject = r.getStringValue('subject');

        String key = '$teacher|$grade|$section|$subject';
        grouped.putIfAbsent(key, () => []).add(r);
      }

      List<Map<String, dynamic>> stats = [];
      grouped.forEach((key, recs) {
        var parts = key.split('|');
        String teacher = parts[0];
        String grade = parts[1];
        String section = parts[2];
        String subject = parts[3];

        double totalMarksSum = 0;
        double obtainedMarksSum = 0;
        int passCount = 0;
        int totalSubmissions = recs.length;

        for (var rec in recs) {
          double marks = rec.getDoubleValue('marks');
          double total = rec.getDoubleValue('totalMarks');
          if (total <= 0) total = 100;
          double passPer = double.tryParse(rec.getStringValue('passPercentage')) ?? 33.0;

          obtainedMarksSum += marks;
          totalMarksSum += total;

          double percentage = (marks / total) * 100;
          if (percentage >= passPer) passCount++;
        }

        double avgPercentage = totalMarksSum > 0 ? (obtainedMarksSum / totalMarksSum) * 100 : 0.0;
        double passPercentageRate = totalSubmissions > 0 ? (passCount / totalSubmissions) * 100 : 0.0;

        stats.add({
          'teacher': teacher,
          'class': 'Grade $grade ${section == 'None' ? '' : 'Sec $section'}',
          'subject': subject,
          'submissions': totalSubmissions,
          'avgPercentage': avgPercentage,
          'passRate': passPercentageRate,
        });
      });

      stats.sort((a, b) => (b['avgPercentage'] as double).compareTo(a['avgPercentage'] as double));

      if (mounted) {
        setState(() {
          teacherStats = stats;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
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
            Text('Teacher Performance Analytics', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: itemColor)),
            if (schoolNameHeader.isNotEmpty)
              Text('School: $schoolNameHeader (ID: $schoolIdHeader)', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: itemColor,
        elevation: 0,
        toolbarHeight: 65,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: itemColor))
          : teacherStats.isEmpty
              ? Center(child: Text('No new teacher performance data found.', style: GoogleFonts.inter(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: teacherStats.length,
                  itemBuilder: (context, index) {
                    final stat = teacherStats[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(stat['teacher'], style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: itemColor)),
                                Chip(
                                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                                  label: Text(stat['subject'], style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(stat['class'], style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w600)),
                            const SizedBox(height: 15),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildMetric('Average Score', '${(stat['avgPercentage'] as double).toStringAsFixed(1)}%'),
                                _buildMetric('Pass Rate', '${(stat['passRate'] as double).toStringAsFixed(1)}%'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: itemColor)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
