import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/data_service.dart';
import 'student_detail_drill_down_screen.dart';

class ManagementClassResultsScreen extends StatefulWidget {
  final String schoolName;
  final String grade;
  final String section;

  const ManagementClassResultsScreen({
    super.key,
    required this.schoolName,
    required this.grade,
    required this.section,
  });

  @override
  State<ManagementClassResultsScreen> createState() => _ManagementClassResultsScreenState();
}

class _ManagementClassResultsScreenState extends State<ManagementClassResultsScreen> {
  final DataService _dataService = DataService();
  bool isLoading = true;
  List<Map<String, String>> students = [];
  List<RecordModel> results = [];

  static const bgColor = Color(0xFFF5F1E8);
  static const itemColor = Color(0xFF2B262C);

  @override
  void initState() {
    super.initState();
    _loadClassData();
  }

  Future<void> _loadClassData() async {
    setState(() => isLoading = true);
    final allStudents = await _dataService.getStudentsForSchool(widget.schoolName);
    final filteredStudents = allStudents.where((s) {
      String g = s['grade'] ?? '';
      String sec = s['section'] ?? 'None';
      if (sec.isEmpty) sec = 'None';
      return g == widget.grade && sec == widget.section;
    }).toList();

    final allResults = await _dataService.getResultsForSchool(widget.schoolName);
    final filteredResults = allResults.where((r) {
      String g = r.getStringValue('grade');
      String sec = r.getStringValue('section');
      if (sec.isEmpty) sec = 'None';
      return g == widget.grade && sec == widget.section;
    }).toList();

    if (mounted) {
      setState(() {
        students = filteredStudents;
        results = filteredResults;
        isLoading = false;
      });
    }
  }

  String _getGrade(double percentage) {
    if (percentage >= 90) return 'A1';
    if (percentage >= 80) return 'A+';
    if (percentage >= 70) return 'A';
    if (percentage >= 60) return 'B';
    if (percentage >= 50) return 'C';
    if (percentage >= 40) return 'D';
    return 'F';
  }

  @override
  Widget build(BuildContext context) {
    String displaySec = widget.section == 'None' ? 'Entire Class' : 'Section ${widget.section}';

    Map<String, Map<String, dynamic>> resultsMapByName = {};
    Map<String, Map<String, dynamic>> resultsMapByID = {};
    Set<String> uploadedSubjects = {};

    for (var r in results) {
      String name = r.getStringValue('studentName').trim();
      String sid = r.getStringValue('student_id').trim();
      String sub = r.getStringValue('subject');
      uploadedSubjects.add(sub);

      if (name.isNotEmpty) {
        resultsMapByName.putIfAbsent(name, () => {});
        resultsMapByName[name]![sub] = {'marks': r.getDoubleValue('marks'), 'total': r.getDoubleValue('totalMarks')};
      }
      if (sid.isNotEmpty) {
        resultsMapByID.putIfAbsent(sid, () => {});
        resultsMapByID[sid]![sub] = {'marks': r.getDoubleValue('marks'), 'total': r.getDoubleValue('totalMarks')};
      }
    }

    List<String> subjects = uploadedSubjects.toList()..sort();

    // Summary calculations
    double totalClassObt = 0;
    double totalClassMax = 0;
    int totalAppeared = 0;

    for (var s in students) {
      String sName = (s['name'] ?? '').trim();
      String sID = (s['pb_id'] ?? '').trim();
      double sObt = 0;
      double sMax = 0;
      bool appeared = false;

      for (var sub in subjects) {
        var res = resultsMapByName[sName]?[sub] ?? resultsMapByID[sID]?[sub];
        if (res != null) {
          sObt += res['marks'];
          sMax += res['total'];
          appeared = true;
        }
      }
      if (appeared) {
        totalAppeared++;
        totalClassObt += sObt;
        totalClassMax += sMax;
      }
    }

    double classAvgPct = totalClassMax > 0 ? (totalClassObt / totalClassMax) * 100 : 0.0;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Grade ${widget.grade} ($displaySec)', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: itemColor)),
            Text(widget.schoolName, style: GoogleFonts.inter(fontSize: 11, color: itemColor.withValues(alpha: 0.6))),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: itemColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: itemColor))
          : students.isEmpty
              ? Center(child: Text('No students registered in Grade ${widget.grade} $displaySec', style: GoogleFonts.inter(color: itemColor.withValues(alpha: 0.6))))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: itemColor.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildSummaryItem('Registered', '${students.length}', Icons.groups_rounded),
                            _buildSummaryItem('Appeared', '$totalAppeared', Icons.assignment_turned_in_rounded),
                            _buildSummaryItem('Class Average', '${classAvgPct.toStringAsFixed(1)}%', Icons.analytics_rounded),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('Class Spreadsheet Matrix', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: itemColor)),
                      const SizedBox(height: 12),
                      if (subjects.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
                          child: const Text('No subject results uploaded for this class yet.'),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: itemColor.withValues(alpha: 0.1)),
                            ),
                            child: DataTable(
                              columnSpacing: 15,
                              headingRowColor: WidgetStateProperty.all(itemColor.withValues(alpha: 0.05)),
                              columns: [
                                const DataColumn(label: Text('Roll')),
                                const DataColumn(label: Text('Student Name')),
                                ...subjects.map((sub) => DataColumn(
                                      label: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(sub, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                          const Text('Obt/Full', style: TextStyle(fontSize: 7, color: Colors.grey)),
                                        ],
                                      ),
                                    )),
                                const DataColumn(label: Text('Total Obt')),
                                const DataColumn(label: Text('%')),
                                const DataColumn(label: Text('Grade')),
                              ],
                              rows: List.generate(students.length, (index) {
                                var s = students[index];
                                String sName = (s['name'] ?? '').trim();
                                String sID = (s['pb_id'] ?? '').trim();
                                String sRole = (s['role_no'] ?? '').trim();
                                if (sRole.isEmpty || sRole == 'N/A') sRole = '${index + 1}';

                                double tObt = 0;
                                double tFull = 0;
                                bool hasAny = false;

                                for (var sub in subjects) {
                                  var res = resultsMapByName[sName]?[sub] ?? resultsMapByID[sID]?[sub];
                                  if (res != null) {
                                    tObt += res['marks'];
                                    tFull += res['total'];
                                    hasAny = true;
                                  }
                                }

                                double perc = tFull > 0 ? (tObt / tFull) * 100 : 0;
                                String grade = hasAny ? _getGrade(perc) : '-';

                                return DataRow(cells: [
                                  DataCell(Text(sRole)),
                                  DataCell(
                                    InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => StudentDetailDrillDownScreen(student: s)),
                                        );
                                      },
                                      child: Text(sName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, decoration: TextDecoration.underline)),
                                    ),
                                  ),
                                  ...subjects.map((sub) {
                                    var res = resultsMapByName[sName]?[sub] ?? resultsMapByID[sID]?[sub];
                                    return DataCell(Center(
                                      child: Text(res != null ? '${res['marks'].toInt()}/${res['total'].toInt()}' : '-', style: const TextStyle(fontSize: 12)),
                                    ));
                                  }),
                                  DataCell(Text(tObt.toInt().toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(Text('${perc.toStringAsFixed(1)}%', style: TextStyle(color: perc < 50 ? Colors.red.shade700 : Colors.green.shade700, fontWeight: FontWeight.bold))),
                                  DataCell(Text(grade, style: const TextStyle(fontWeight: FontWeight.bold))),
                                ]);
                              }),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: itemColor, size: 22),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: itemColor)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: itemColor.withValues(alpha: 0.6))),
      ],
    );
  }
}
