import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/data_service.dart';

class ResultEntryScreen extends StatefulWidget {
  const ResultEntryScreen({super.key});

  @override
  State<ResultEntryScreen> createState() => _ResultEntryScreenState();
}

class _ResultEntryScreenState extends State<ResultEntryScreen> {
  final DataService _dataService = DataService();

  String? selectedGrade;
  String? selectedSection;
  String? selectedSubject;
  String? selectedTerm;
  String? selectedTest;
  String? selectedCategory;
  
  final TextEditingController _totalMarksController = TextEditingController(text: "100");
  String selectedPassPercentage = "33";

  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> recentSubmissions = [];
  bool isLoading = false;
  bool isEditMode = true;
  bool hasSubmittedBefore = false;

  static const bgColor = Color(0xFFF5F1E8);
  static const itemColor = Color(0xFF2B262C);

  final List<String> grades = ['6', '7', '8', '9', '10', '11', '12'];
  final List<String> sections = ['A', 'B', 'None'];
  final List<String> terms = ['1st Term', '2nd Term', 'Final Term'];
  final List<String> tests = ['Test 1', 'Test 2', 'Mid-term', 'Final'];

  @override
  void initState() {
    super.initState();
    _loadRecentSubmissions();
  }

  Future<void> _loadRecentSubmissions() async {
    final recent = await _dataService.getRecentSubmissions();
    if (mounted) setState(() => recentSubmissions = recent);
  }

  List<String> get _dynamicSubjects {
    if (selectedGrade == null) return [];
    int g = int.tryParse(selectedGrade!) ?? 0;
    if (g >= 6 && g <= 8) return ['Science', 'Geography', 'History', 'Urdu', 'English', 'Islamiat', 'Math', 'Al Quran', 'Computer'];
    if (g == 9 || g == 10) {
      List<String> common = ['Chemistry', 'Physics', 'Math', 'Urdu', 'English', 'Pak Studies', 'Islamiat'];
      if (selectedCategory == 'bio' || selectedCategory == 'biology') return [...common, 'Biology'];
      if (selectedCategory == 'computer') return [...common, 'Computer Science', 'Computer'];
      return common;
    }
    if (g == 11 || g == 12) {
      String rel = (g == 11) ? 'Pak Studies' : 'Islamiat';
      List<String> common = ['English', 'Urdu', rel, 'Physics'];
      if (selectedCategory == 'pre-medical') return [...common, 'Biology', 'Chemistry'];
      if (selectedCategory == 'pre-engineering') return [...common, 'Math', 'Chemistry'];
      if (selectedCategory == 'ics') return [...common, 'Math', 'Computer Science'];
      return common;
    }
    return [];
  }

  List<String> get _categoryOptions {
    if (selectedGrade == null) return [];
    int g = int.tryParse(selectedGrade!) ?? 0;
    if (g == 9 || g == 10) return ['biology', 'computer'];
    if (g == 11 || g == 12) return ['pre-medical', 'pre-engineering', 'ics'];
    return [];
  }

  Future<void> _updateRoster() async {
    if (selectedGrade == null || selectedSection == null) return;
    setState(() => isLoading = true);
    try {
      final rawStudents = await _dataService.getStudents(selectedGrade!, selectedSection!);
      List<RecordModel> filteredResults = [];
      if (selectedSubject != null && selectedTerm != null && selectedTest != null) {
        final allResults = await _dataService.getAllResults();
        filteredResults = allResults.where((doc) {
          final data = doc.data;
          
          bool gradeMatch = data['grade'].toString() == selectedGrade;
          
          // Normalize section
          String dbSec = (data['section']?.toString() ?? '').isEmpty ? 'None' : data['section'].toString();
          bool sectionMatch = dbSec == selectedSection;
          
          bool subjectMatch = data['subject'] == selectedSubject;
          
          // Normalize Term
          String dbTerm = data['term']?.toString() ?? '';
          if (dbTerm == 'Final' || dbTerm == 'Final Term') dbTerm = 'Final Term';
          if (dbTerm == '1st Term' || dbTerm == 'Term 1') dbTerm = '1st Term';
          if (dbTerm == '2nd Term' || dbTerm == 'Term 2') dbTerm = '2nd Term';

          String queryTerm = selectedTerm!;
          if (queryTerm == 'Final' || queryTerm == 'Final Term') queryTerm = 'Final Term';
          if (queryTerm == '1st Term' || queryTerm == 'Term 1') queryTerm = '1st Term';
          if (queryTerm == '2nd Term' || queryTerm == 'Term 2') queryTerm = '2nd Term';

          bool termMatch = dbTerm == queryTerm;

          // Normalize Test
          String dbTest = data['test']?.toString() ?? '';
          if (dbTest == 'Final Term') dbTest = 'Final';
          String queryTest = selectedTest!;
          if (queryTest == 'Final Term') queryTest = 'Final';
          bool testMatch = dbTest == queryTest;

          return gradeMatch && sectionMatch && subjectMatch && termMatch && testMatch;
        }).toList();
      }
      bool submitted = filteredResults.isNotEmpty;
      bool allowed = submitted ? await _dataService.isEditAllowed(selectedGrade!, selectedSection!, selectedSubject!, selectedTerm!, selectedTest!) : true;

      List<Map<String, String>> resolvedStudents = [];
      if (submitted) {
        Map<String, Map<String, String>> studentMap = {};
        for (var res in filteredResults) {
          String sid = res.getStringValue('student_id').trim();
          String name = res.getStringValue('studentName').trim();
          String roleNo = res.getStringValue('RoleNo').trim();
          String fName = res.getStringValue('FatherName').trim();
          String batch = res.getStringValue('batch').trim();
          if (batch.isEmpty) batch = '2025';

          String key = sid.isNotEmpty ? sid : name;
          studentMap[key] = {
            'pb_id': sid,
            'student_id': sid,
            'role_no': roleNo.isNotEmpty ? roleNo : 'N/A',
            'name': name,
            'father_name': fName,
            'batch': batch,
          };
        }
        resolvedStudents = studentMap.values.toList();
        resolvedStudents.sort((a, b) {
          int rA = int.tryParse(a['role_no'] ?? '') ?? 9999;
          int rB = int.tryParse(b['role_no'] ?? '') ?? 9999;
          if (rA != rB) return rA.compareTo(rB);
          return (a['name'] ?? '').compareTo(b['name'] ?? '');
        });
      } else {
        resolvedStudents = rawStudents.map((s) => {
          'pb_id': s['pb_id'] ?? '',
          'student_id': s['student_id'] ?? '',
          'role_no': s['role_no'] ?? 'N/A',
          'name': s['name'] ?? '',
          'father_name': s['father_name'] ?? '',
          'batch': s['batch'] ?? '2025',
        }).toList();
      }

      setState(() {
        students = resolvedStudents.map((s) {
          final resDoc = filteredResults.where((d) {
            final data = d.data;
            bool idMatch = (data['student_id']?.toString() ?? '') == (s['student_id'] ?? s['pb_id']);
            bool nameMatch = data['studentName'].toString().trim() == s['name'].toString().trim();
            return idMatch || nameMatch;
          }).firstOrNull;
          return {
            'id': s['pb_id'] ?? s['student_id'], 
            'student_id': s['student_id'] ?? s['pb_id'],
            'role_no': s['role_no'],
            'name': s['name'], 
            'father_name': s['father_name'],
            'marks': resDoc != null ? resDoc.data['marks'].toString() : '', 
            'result_record_id': resDoc?.id,
            'batch': s['batch'] ?? '2025',
          };
        }).toList();
        hasSubmittedBefore = submitted; isEditMode = !submitted || allowed; isLoading = false;
      });
    } catch (e) { setState(() => isLoading = false); }
  }

  Future<void> _submitResults() async {
    if (students.isEmpty) return;
    setState(() => isLoading = true);
    try {
      await _dataService.submitResults(
        grade: selectedGrade!, section: selectedSection!, subject: selectedSubject!, term: selectedTerm!, test: selectedTest!,
        results: students, totalMarks: double.tryParse(_totalMarksController.text) ?? 100, passPercentage: selectedPassPercentage,
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Changes Synced Successfully')));
      _loadRecentSubmissions();
      await _updateRoster();
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update Failed: $e'))); setState(() => isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Results Entry', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: itemColor, letterSpacing: -0.5)),
        actions: [
          IconButton(
            icon: const Icon(Icons.ballot_rounded, color: itemColor),
            onPressed: _showBatchResultDialog,
            tooltip: 'Batch Result Enter',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (recentSubmissions.isNotEmpty) ...[
                _buildRecentSubmissionsList(),
                const SizedBox(height: 20),
              ],
              _buildSelectionForm(),
              const SizedBox(height: 30),
              if (isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(50.0), child: CircularProgressIndicator(color: itemColor)))
              else if (selectedGrade != null && selectedSection != null)
                FadeInUp(child: _buildResultTemplate()),
            ],
          ),
        ),
      ),
      floatingActionButton: (selectedGrade != null && selectedSubject != null && selectedTerm != null && selectedTest != null && isEditMode && students.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: isLoading ? null : _submitResults,
              label: Text(hasSubmittedBefore ? 'Update Changes' : 'Submit Marks', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              icon: const Icon(Icons.sync_rounded),
              backgroundColor: itemColor,
              foregroundColor: bgColor,
            )
          : null,
    );
  }

  Widget _buildRecentSubmissionsList() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: recentSubmissions.length,
        itemBuilder: (context, index) {
          final sub = recentSubmissions[index];
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedGrade = sub['grade'];
                selectedSection = (sub['section'] == null || sub['section'].isEmpty) ? 'None' : sub['section'];
                
                String rawTerm = sub['term']?.toString() ?? '';
                if (rawTerm == 'Final') selectedTerm = 'Final Term';
                else if (rawTerm == '1st Term') selectedTerm = 'Term 1';
                else if (rawTerm == '2nd Term') selectedTerm = 'Term 2';
                else selectedTerm = rawTerm;

                selectedTest = sub['test'] == 'Final Term' ? 'Final' : sub['test'];
                selectedSubject = sub['subject'];
              });
              _updateRoster();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: itemColor.withOpacity(0.2))),
              child: Center(child: Text('Batch ${sub['batch'] ?? '2025'} • G${sub['grade']} - ${sub['subject']}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: itemColor))),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectionForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: _buildDropdown('Grade', grades, selectedGrade, (v) { setState(() { selectedGrade = v; selectedSubject = null; selectedCategory = null; }); _updateRoster(); })),
            const SizedBox(width: 15),
            Expanded(child: _buildDropdown('Section', sections, selectedSection, (v) { setState(() => selectedSection = v); _updateRoster(); })),
          ]),
          if (_categoryOptions.isNotEmpty) ...[
            const SizedBox(height: 15),
            _buildDropdown('Category', _categoryOptions.map((e) => e.toUpperCase()).toList(), selectedCategory?.toUpperCase(), (v) { setState(() { selectedCategory = v?.toLowerCase(); selectedSubject = null; }); _updateRoster(); }),
          ],
          const SizedBox(height: 15),
          _buildDropdown('Subject', _dynamicSubjects, selectedSubject, (v) { setState(() => selectedSubject = v); _updateRoster(); }),
          const SizedBox(height: 15),
          Row(children: [
            Expanded(child: _buildDropdown('Term', terms, selectedTerm, (v) { 
              setState(() { 
                selectedTerm = v; 
                if (v == 'Final Term') selectedTest = 'Final';
              }); 
              _updateRoster(); 
            })),
            if (selectedTerm != 'Final Term') ...[
              const SizedBox(width: 15),
              Expanded(child: _buildDropdown('Test #', tests, selectedTest, (v) { setState(() => selectedTest = v); _updateRoster(); })),
            ],
          ]),
          const SizedBox(height: 15),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _totalMarksController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Max Score / Total Marks', border: OutlineInputBorder()),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: selectedPassPercentage,
                dropdownColor: bgColor,
                decoration: const InputDecoration(labelText: 'Pass % Threshold', border: OutlineInputBorder()),
                items: ['33', '40', '50', '60'].map((e) => DropdownMenuItem(value: e, child: Text('$e%'))).toList(),
                onChanged: (v) => setState(() => selectedPassPercentage = v ?? '33'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? value, Function(String?)? onChanged) {
    return DropdownButtonFormField<String>(
      value: (value != null && items.contains(value)) ? value : null,
      dropdownColor: bgColor,
      decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildResultTemplate() {
    double total = double.tryParse(_totalMarksController.text) ?? 100;
    double passPer = double.tryParse(selectedPassPercentage) ?? 33;
    double passingMarks = (passPer / 100) * total;
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Class Roster', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: itemColor)),
          if (hasSubmittedBefore && !isEditMode) 
            Row(
              children: [
                const Text('Locked', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _showRequestEditDialog,
                  icon: const Icon(Icons.lock_open_rounded, size: 14, color: Colors.blue),
                  label: const Text('Request Edit', style: TextStyle(fontSize: 12, color: Colors.blue)),
                ),
              ],
            ),
        ]),
        const SizedBox(height: 15),
        if (students.isEmpty) const Text('No students found.')
        else Container(
          width: double.infinity,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(20), border: Border.all(color: itemColor.withOpacity(0.1))),
          child: DataTable(
            columns: [const DataColumn(label: Text('Name')), DataColumn(label: Text('Marks')), const DataColumn(label: Text('Status'))],
            rows: students.map((s) {
              double? cur = double.tryParse(s['marks'] ?? '');
              bool isPass = (cur ?? 0) >= passingMarks;
              return DataRow(cells: [
                DataCell(Text(s['name'])),
                DataCell(SizedBox(width: 60, child: TextFormField(
                  initialValue: s['marks'], 
                  keyboardType: TextInputType.number, 
                  enabled: isEditMode, 
                  onChanged: (v) {
                    double? val = double.tryParse(v);
                    double maxTotal = double.tryParse(_totalMarksController.text) ?? 100;
                    if (val != null && val > maxTotal) {
                      v = maxTotal.toString();
                    }
                    setState(() { s['marks'] = v; });
                  }, 
                  decoration: const InputDecoration(hintText: '-', border: InputBorder.none)
                ))),
                DataCell(Text(s['marks'].isEmpty ? '-' : (isPass ? 'PASS' : 'FAIL'), style: TextStyle(color: isPass ? Colors.green : Colors.red, fontWeight: FontWeight.bold))),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _showBatchResultDialog() {
    TextEditingController batchController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          title: Text('Batch Results', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: itemColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: batchController, maxLines: 10,
                decoration: InputDecoration(
                  hintText: 'Grade, Section, RollNo, Name, Term, Test, Subject:Obtained/Total...',
                  hintStyle: TextStyle(fontSize: 12, color: itemColor.withOpacity(0.4)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                  filled: true, fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text('Format: 6, A, 1, John Doe, Final Term, Final, Science:85/100, Urdu:45/50', style: GoogleFonts.inter(fontSize: 10, color: itemColor.withOpacity(0.6))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: itemColor, foregroundColor: bgColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: isLoading ? null : () async {
                String input = batchController.text.trim();
                if (input.isEmpty) return;
                setDialogState(() => isLoading = true);
                setState(() => isLoading = true);
                int successLines = 0;
                try {
                  List<String> lines = input.split('\n');
                  for (var line in lines) {
                    if (line.trim().isEmpty) continue;
                    var parts = line.contains('\t') ? line.split('\t') : line.split(',');
                    if (parts.length < 7) continue;
                    String g = parts[0].trim().replaceAll('Grade ', '');
                    String s = parts[1].trim().replaceAll('Section ', '');
                    String rNo = parts[2].trim(); // This is the Roll Number (RoleNo)
                    String name = parts[3].trim();
                    String term = parts[4].trim();
                    String test = parts[5].trim();

                    // Find student internal ID from Roll Number or Name
                    final classStudents = await _dataService.getStudents(g, s);
                    final student = classStudents.where((st) => 
                      st['role_no'] == rNo || st['name']?.trim() == name).firstOrNull;

                    for (int i = 6; i < parts.length; i++) {
                      var subPart = parts[i].split(':');
                      if (subPart.length == 2) {
                        String subjectName = subPart[0].trim();
                        String marksPart = subPart[1].trim();
                        
                        double obtained = 0;
                        double total = 100;

                        if (marksPart.contains('/')) {
                          var scoreParts = marksPart.split('/');
                          obtained = double.tryParse(scoreParts[0].trim()) ?? 0;
                          total = double.tryParse(scoreParts[1].trim()) ?? 100;
                        } else {
                          obtained = double.tryParse(marksPart) ?? 0;
                        }

                        await _dataService.submitResults(
                          grade: g, section: s, subject: subjectName, term: term, test: test,
                          results: [{
                            'id': student?['pb_id'] ?? '',
                            'name': name, 
                            'marks': obtained, 
                            'student_id': student?['student_id'] ?? '',
                            'father_name': student?['father_name'] ?? '',
                            'role_no': student?['role_no'] ?? '',
                          }],
                          totalMarks: total, passPercentage: "33",
                        );
                      }
                    }
                    successLines++;
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import complete: $successLines rows processed.')));
                  }
                  _loadRecentSubmissions();
                  _updateRoster();
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                } finally {
                  if (mounted) setState(() => isLoading = false);
                }
              },
              child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: bgColor, strokeWidth: 2)) : const Text('Import'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRequestEditDialog() {
    TextEditingController reasonController = TextEditingController();
    TextEditingController teacherController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgColor,
        title: Text('Request Edit Access', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: itemColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Request permission to edit marks for Grade $selectedGrade ($selectedSection) - $selectedSubject ($selectedTerm / $selectedTest).', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            TextField(controller: teacherController, decoration: const InputDecoration(labelText: 'Teacher Name')),
            const SizedBox(height: 8),
            TextField(controller: reasonController, maxLines: 3, decoration: const InputDecoration(labelText: 'Reason for Edit')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty || teacherController.text.trim().isEmpty) return;
              Navigator.pop(context);
              try {
                await _dataService.requestEdit(
                  grade: selectedGrade!,
                  section: selectedSection!,
                  subject: selectedSubject!,
                  term: selectedTerm!,
                  test: selectedTest!,
                  reason: reasonController.text.trim(),
                  teacherName: teacherController.text.trim(),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Edit request submitted successfully!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to submit request: $e')),
                  );
                }
              }
            },
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }
}
