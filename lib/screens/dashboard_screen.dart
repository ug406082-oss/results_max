import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/data_service.dart';
import 'student_history_screen.dart';
import 'promotion_screen.dart';
import 'result_archive_screen.dart';
import 'teacher_performance_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DataService _dataService = DataService();
  String? userRole;
  
  String selectedGrade = '6';
  String selectedSection = 'None';
  String selectedTerm = 'Final Term';
  String selectedTest = 'Final';
  String? selectedCategory;

  final List<String> grades = ['6', '7', '8', '9', '10', '11', '12'];
  final List<String> sections = ['A', 'B', 'None'];
  final List<String> terms = ['1st Term', '2nd Term', 'Final Term'];
  final List<String> tests = ['Test 1', 'Test 2', 'Mid-term', 'Final'];

  static const bgColor = Color(0xFFF5F1E8);
  static const itemColor = Color(0xFF2B262C);

  List<String> get _categoryOptions {
    int g = int.tryParse(selectedGrade) ?? 0;
    if (g == 9 || g == 10) return ['biology', 'computer'];
    if (g == 11 || g == 12) return ['pre-medical', 'pre-engineering', 'ics'];
    return [];
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
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await _dataService.getCurrentUserRole();
    if (mounted) setState(() => userRole = role?.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Academic Insights', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: itemColor, letterSpacing: -0.5)),
                  Row(
                    children: [
                      if (userRole == 'developer' || userRole == 'principal' || userRole == 'admin')
                        IconButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TeacherPerformanceScreen())),
                          icon: const Icon(Icons.analytics_rounded, color: itemColor),
                          tooltip: 'Teacher Performance',
                        ),
                      if (userRole == 'developer')
                        IconButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PromotionScreen())),
                          icon: const Icon(Icons.trending_up_rounded, color: itemColor),
                          tooltip: 'Class Promotion',
                        ),
                      IconButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ResultArchiveScreen())),
                        icon: const Icon(Icons.archive_rounded, color: itemColor),
                        tooltip: 'Result Archives',
                      ),
                      IconButton(
                        onPressed: () => setState(() {}),
                        icon: const Icon(Icons.refresh_rounded, color: itemColor),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildFilters(),
              const SizedBox(height: 25),
              _buildSpreadsheetView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: _buildSmallDropdown('Grade', selectedGrade, grades, (v) => setState(() { selectedGrade = v!; selectedCategory = null; }))),
            const SizedBox(width: 8),
            Expanded(child: _buildSmallDropdown('Sec', selectedSection, sections, (v) => setState(() => selectedSection = v!))),
            const SizedBox(width: 8),
            Expanded(child: _buildSmallDropdown('Term', selectedTerm, terms, (v) {
              setState(() {
                selectedTerm = v!;
                if (selectedTerm == 'Final Term') selectedTest = 'Final';
              });
            })),
            if (selectedTerm != 'Final Term') ...[
              const SizedBox(width: 8),
              Expanded(child: _buildSmallDropdown('Test', selectedTest, tests, (v) => setState(() => selectedTest = v!))),
            ],
          ]),
          if (_categoryOptions.isNotEmpty) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: (selectedCategory != null && _categoryOptions.contains(selectedCategory!.toLowerCase())) ? selectedCategory!.toUpperCase() : null,
              hint: const Text('SELECT CATEGORY', style: TextStyle(fontSize: 11)),
              decoration: InputDecoration(labelText: 'Category', contentPadding: const EdgeInsets.symmetric(horizontal: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              style: const TextStyle(fontSize: 11, color: itemColor),
              items: _categoryOptions.map((e) => DropdownMenuItem(value: e.toUpperCase(), child: Text(e.toUpperCase()))).toList(),
              onChanged: (v) => setState(() => selectedCategory = v?.toLowerCase()),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildSmallDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : null,
      decoration: InputDecoration(labelText: label, contentPadding: const EdgeInsets.symmetric(horizontal: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
      style: const TextStyle(fontSize: 11, color: itemColor),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildSpreadsheetView() {
    return FutureBuilder(
      future: Future.wait([
        _dataService.getStudents(selectedGrade, selectedSection),
        _dataService.getClassResults(grade: selectedGrade, section: selectedSection, term: selectedTerm, test: selectedTest),
      ]),
      builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(50.0), child: CircularProgressIndicator(color: itemColor)));
        
        List<Map<String, String>> rawStudents = snapshot.data?[0] ?? [];
        List<RecordModel> classResults = snapshot.data?[1] ?? [];

        List<Map<String, String>> students = rawStudents.where((s) {
          if (selectedCategory != null) return (s['category']?.toLowerCase() ?? '') == selectedCategory;
          return true;
        }).toList();

        Map<String, Map<String, dynamic>> resultsMapByName = {};
        Map<String, Map<String, dynamic>> resultsMapByID = {};
        Set<String> uploadedSubjects = {};
        
        for (var res in classResults) {
          String name = res.getStringValue('studentName').trim();
          String sid = res.getStringValue('student_id').trim();
          String sub = res.getStringValue('subject');
          uploadedSubjects.add(sub);
          
          if (name.isNotEmpty) {
            resultsMapByName.putIfAbsent(name, () => {});
            resultsMapByName[name]![sub] = {'marks': res.getDoubleValue('marks'), 'total': res.getDoubleValue('totalMarks')};
          }
          if (sid.isNotEmpty) {
            resultsMapByID.putIfAbsent(sid, () => {});
            resultsMapByID[sid]![sub] = {'marks': res.getDoubleValue('marks'), 'total': res.getDoubleValue('totalMarks')};
          }
        }

        List<String> subjects = uploadedSubjects.toList()..sort();

        bool anyStudentHasResults = false;
        for (var s in students) {
          String sName = (s['name'] ?? '').trim();
          String sID = (s['pb_id'] ?? '').trim();
          if (resultsMapByName.containsKey(sName) || resultsMapByID.containsKey(sID)) {
            anyStudentHasResults = true;
            break;
          }
        }

        if (rawStudents.isEmpty || classResults.isEmpty || subjects.isEmpty || !anyStudentHasResults) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_off_outlined, size: 48, color: itemColor.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  const Text("No data uploaded for this selection.", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text("Filtering for: Grade $selectedGrade, Sec $selectedSection, $selectedTerm, $selectedTest", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        int totalAppeared = 0;
        Map<String, int> gradeDist = {'A1':0,'A+':0,'A':0,'B':0,'C':0,'D':0,'F':0};

        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: itemColor.withOpacity(0.1))),
                child: DataTable(
                  columnSpacing: 15,
                  headingRowColor: WidgetStateProperty.all(itemColor.withOpacity(0.05)),
                  columns: [
                    const DataColumn(label: Text('Sr.')),
                    const DataColumn(label: Text('Student Name')),
                    ...subjects.map((sub) => DataColumn(label: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(sub, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)), const Text('Obt/Full', style: TextStyle(fontSize: 7))]))),
                    const DataColumn(label: Text('Total Obt')),
                    const DataColumn(label: Text('%')),
                    const DataColumn(label: Text('Grade')),
                  ],
                  rows: List.generate(students.length, (index) {
                    var s = students[index];
                    String sName = (s['name'] ?? '').trim();
                    String sID = (s['pb_id'] ?? '').trim();
                    String sRole = (s['role_no'] ?? '').trim();
                    if (sRole.isEmpty || sRole == 'N/A') {
                      sRole = (index + 1).toString();
                    }
                    
                    double tObt = 0; double tFull = 0; bool hasAny = false;
                    for (var sub in subjects) {
                      var res = resultsMapByName[sName]?[sub] ?? resultsMapByID[sID]?[sub];
                      if (res != null) { tObt += res['marks']; tFull += res['total']; hasAny = true; }
                    }
                    if (hasAny) totalAppeared++;
                    double perc = tFull > 0 ? (tObt / tFull) * 100 : 0;
                    String grade = hasAny ? _getGrade(perc) : '-';
                    if (hasAny) gradeDist[grade] = (gradeDist[grade] ?? 0) + 1;

                    return DataRow(cells: [
                      DataCell(Text(sRole)),
                      DataCell(
                        InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => StudentHistoryScreen(
                            studentName: s['name'] ?? '',
                            fatherName: s['father_name'] ?? 'N/A',
                            studentID: sRole,
                            studentPbID: sID,
                          ))),
                          child: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                        )
                      ),
                      ...subjects.map((sub) {
                        var res = resultsMapByName[sName]?[sub] ?? resultsMapByID[sID]?[sub];
                        return DataCell(Center(child: Text(res != null ? '${res['marks'].toInt()}/${res['total'].toInt()}' : '-')));
                      }),
                      DataCell(Text(tObt.toInt().toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text('${perc.toStringAsFixed(1)}%', style: TextStyle(color: perc < 40 ? Colors.red : Colors.blue, fontWeight: FontWeight.bold))),
                      DataCell(Text(grade, style: const TextStyle(fontWeight: FontWeight.bold))),
                    ]);
                  }),
                ),
              ),
            ),
            const SizedBox(height: 30),
            _buildSummary(students.length, totalAppeared, gradeDist),
          ],
        );
      },
    );
  }

  Widget _buildSummary(int total, int app, Map<String, int> dist) {
    return Wrap(spacing: 20, runSpacing: 20, children: [
      _buildSumTable('Class Stats', {'Total': total.toString(), 'Appeared': app.toString(), 'Absent': (total-app).toString()}, Colors.yellow.shade50),
      _buildSumTable('Grade Analysis', {'A1': dist['A1'].toString(), 'A+': dist['A+'].toString(), 'A': dist['A'].toString(), 'B': dist['B'].toString(), 'C': dist['C'].toString(), 'D': dist['D'].toString(), 'F': dist['F'].toString()}, Colors.blue.shade50),
    ]);
  }

  Widget _buildSumTable(String title, Map<String, String> data, Color headColor) {
    return Container(width: 160, decoration: BoxDecoration(border: Border.all(color: itemColor.withOpacity(0.1))), child: Column(children: [
      Container(padding: const EdgeInsets.all(8), width: double.infinity, color: headColor, child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
      ...data.entries.map((e) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(border: Border(top: BorderSide(color: itemColor.withOpacity(0.05)))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(e.key, style: const TextStyle(fontSize: 10)), Text(e.value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10))]))),
    ]));
  }
}
