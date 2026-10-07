import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/data_service.dart';
import 'student_history_screen.dart';

class ResultArchiveScreen extends StatefulWidget {
  const ResultArchiveScreen({super.key});

  @override
  State<ResultArchiveScreen> createState() => _ResultArchiveScreenState();
}

class _ResultArchiveScreenState extends State<ResultArchiveScreen> {
  final DataService _dataService = DataService();
  bool isLoading = true;
  List<Map<String, dynamic>> archivedBatches = [];
  String searchQuery = '';

  static const bgColor = Color(0xFFF5F1E8);
  static const itemColor = Color(0xFF2B262C);

  @override
  void initState() {
    super.initState();
    _loadArchives();
  }

  Future<void> _loadArchives() async {
    setState(() => isLoading = true);
    try {
      final allResults = await _dataService.getAllResults();
      Map<String, Map<String, dynamic>> unique = {};
      
      for (var item in allResults) {
        final data = item.data;
        String grade = data['grade']?.toString() ?? '';
        String section = data['section']?.toString() ?? 'None';
        String term = data['term']?.toString() ?? '';
        String test = data['test']?.toString() ?? '';
        String batch = data['batch']?.toString() ?? '';
        if (batch.isEmpty) batch = '2025';
        String created = item.getStringValue('created');
        
        // Group by batch, class (Grade + Section) and exam (Term + Test)
        String key = '${batch}_${grade}_${section}_${term}_$test';
        
        if (!unique.containsKey(key)) {
          unique[key] = {
            'batch': batch,
            'grade': grade,
            'section': section,
            'term': term,
            'test': test,
            'created': created,
            'record_count': 1,
          };
        } else {
          unique[key]!['record_count'] = (unique[key]!['record_count'] as int) + 1;
          String existingCreated = unique[key]!['created'];
          if (created.compareTo(existingCreated) > 0) {
            unique[key]!['created'] = created;
          }
        }
      }

      List<Map<String, dynamic>> list = unique.values.toList();
      list.sort((a, b) => b['created'].compareTo(a['created']));

      setState(() {
        archivedBatches = list;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filtered = archivedBatches.where((b) {
      if (searchQuery.isEmpty) return true;
      String q = searchQuery.toLowerCase();
      return b['batch'].toString().toLowerCase().contains(q) ||
             b['grade'].toString().toLowerCase().contains(q) ||
             b['term'].toString().toLowerCase().contains(q) ||
             b['test'].toString().toLowerCase().contains(q) ||
             b['section'].toString().toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Result Archives & Batches', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: itemColor)),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add_check_rounded, color: itemColor),
            onPressed: _showBulkAssignBatchDialog,
            tooltip: 'Bulk Tag Class Results',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: itemColor),
            onPressed: _loadArchives,
            tooltip: 'Refresh Archives',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (v) => setState(() => searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search by Batch, Grade, Term, Test...',
                prefixIcon: const Icon(Icons.search, color: itemColor),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: itemColor))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.archive_outlined, size: 64, color: itemColor.withValues(alpha: 0.3)),
                            const SizedBox(height: 10),
                            const Text('No archived exam sessions found.'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final batchData = filtered[index];
                          String batch = batchData['batch'];
                          String grade = batchData['grade'];
                          String section = batchData['section'];
                          String term = batchData['term'];
                          String test = batchData['test'];
                          String createdStr = batchData['created'];
                          int count = batchData['record_count'];

                          DateTime? dt = DateTime.tryParse(createdStr);
                          String dateFormatted = dt != null 
                              ? '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} (${dt.hour}:${dt.minute.toString().padLeft(2, '0')})'
                              : createdStr;

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: itemColor.withValues(alpha: 0.1)),
                            ),
                            color: Colors.white.withValues(alpha: 0.8),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Batch $batch • Grade $grade (Sec: $section)',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: itemColor),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: itemColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('Batch $batch', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: itemColor)),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Text('Term: $term | Test: $test', style: TextStyle(color: itemColor.withValues(alpha: 0.7), fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Submitted: $dateFormatted', style: TextStyle(color: itemColor.withValues(alpha: 0.5), fontSize: 11)),
                                      Text('$count Result Entries', style: TextStyle(color: itemColor.withValues(alpha: 0.8), fontWeight: FontWeight.w600, fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ArchiveDetailScreen(
                                      grade: grade,
                                      section: section,
                                      term: term,
                                      test: test,
                                      batch: batch,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showBulkAssignBatchDialog() {
    String selectedGrade = '8';
    String selectedSection = 'None';
    TextEditingController batchController = TextEditingController(text: '2025');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: bgColor,
          title: Text('Bulk Tag Class Results', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: itemColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Assign a Batch year to all past result entries for a specific class (Grade & Section).', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedGrade,
                decoration: const InputDecoration(labelText: 'Grade'),
                items: ['6', '7', '8', '9', '10', '11', '12'].map((e) => DropdownMenuItem(value: e, child: Text('Grade $e'))).toList(),
                onChanged: (v) => setDialogState(() => selectedGrade = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedSection,
                decoration: const InputDecoration(labelText: 'Section'),
                items: ['A', 'B', 'None'].map((e) => DropdownMenuItem(value: e, child: Text('Section $e'))).toList(),
                onChanged: (v) => setDialogState(() => selectedSection = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: batchController,
                decoration: const InputDecoration(labelText: 'Batch Year (e.g. 2025, 2026)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() => isLoading = true);
                String? error = await _dataService.assignBatchToClassResults(
                  grade: selectedGrade,
                  section: selectedSection,
                  batch: batchController.text.trim(),
                );
                if (mounted) {
                  if (error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Successfully tagged Grade $selectedGrade (Sec: $selectedSection) results with Batch ${batchController.text.trim()}!')),
                    );
                  }
                }
                _loadArchives();
              },
              child: const Text('Tag All Results'),
            ),
          ],
        ),
      ),
    );
  }
}

class ArchiveDetailScreen extends StatefulWidget {
  final String grade;
  final String section;
  final String term;
  final String test;
  final String batch;

  const ArchiveDetailScreen({
    super.key,
    required this.grade,
    required this.section,
    required this.term,
    required this.test,
    required this.batch,
  });

  @override
  State<ArchiveDetailScreen> createState() => _ArchiveDetailScreenState();
}

class _ArchiveDetailScreenState extends State<ArchiveDetailScreen> {
  final DataService _dataService = DataService();

  static const bgColor = Color(0xFFF5F1E8);
  static const itemColor = Color(0xFF2B262C);

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
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Batch ${widget.batch} • Grade ${widget.grade} (${widget.section}) • ${widget.term}', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder(
          future: _dataService.getClassResults(grade: widget.grade, section: widget.section, term: widget.term, test: widget.test),
          builder: (context, AsyncSnapshot<List<RecordModel>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(50.0), child: CircularProgressIndicator(color: itemColor)));
            }
            
            List<RecordModel> classResults = snapshot.data ?? [];

            Map<String, Map<String, dynamic>> resultsMapByName = {};
            Map<String, Map<String, dynamic>> resultsMapByID = {};
            Map<String, Map<String, String>> studentInfoMap = {};
            Set<String> uploadedSubjects = {};
            
            for (var res in classResults) {
              String name = res.getStringValue('studentName').trim();
              String sid = res.getStringValue('student_id').trim();
              String roleNo = res.getStringValue('RoleNo').trim();
              String fName = res.getStringValue('FatherName').trim();
              String sub = res.getStringValue('subject').trim();
              String resBatch = res.getStringValue('batch').trim();
              if (resBatch.isEmpty) resBatch = '2025';

              // Filter strictly by batch
              if (resBatch != widget.batch) continue;

              uploadedSubjects.add(sub);

              String studentKey = sid.isNotEmpty ? sid : name;
              studentInfoMap[studentKey] = {
                'pb_id': sid,
                'name': name,
                'role_no': roleNo.isNotEmpty ? roleNo : 'N/A',
                'father_name': fName,
                'batch': resBatch,
              };
              
              if (name.isNotEmpty) {
                resultsMapByName.putIfAbsent(name, () => {});
                resultsMapByName[name]![sub] = {'marks': res.getDoubleValue('marks'), 'total': res.getDoubleValue('totalMarks')};
              }
              if (sid.isNotEmpty) {
                resultsMapByID.putIfAbsent(sid, () => {});
                resultsMapByID[sid]![sub] = {'marks': res.getDoubleValue('marks'), 'total': res.getDoubleValue('totalMarks')};
              }
            }

            List<Map<String, String>> rawStudents = studentInfoMap.values.toList();
            rawStudents.sort((a, b) {
              int rA = int.tryParse(a['role_no'] ?? '') ?? 9999;
              int rB = int.tryParse(b['role_no'] ?? '') ?? 9999;
              if (rA != rB) return rA.compareTo(rB);
              return (a['name'] ?? '').compareTo(b['name'] ?? '');
            });

            List<String> subjects = uploadedSubjects.toList()..sort();

            if (subjects.isEmpty || rawStudents.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("No records found for this batch archive session."),
                    const SizedBox(height: 8),
                    Text("Batch: ${widget.batch}, Grade: ${widget.grade}, Sec: ${widget.section}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: itemColor.withValues(alpha: 0.1))),
                  child: DataTable(
                    columnSpacing: 15,
                    headingRowColor: WidgetStateProperty.all(itemColor.withValues(alpha: 0.05)),
                    columns: [
                      const DataColumn(label: Text('Sr.')),
                      const DataColumn(label: Text('Student Name')),
                      ...subjects.map((sub) => DataColumn(label: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(sub, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)), const Text('Obt/Full', style: TextStyle(fontSize: 7))]))),
                      const DataColumn(label: Text('Total Obt')),
                      const DataColumn(label: Text('%')),
                      const DataColumn(label: Text('Grade')),
                    ],
                    rows: List.generate(rawStudents.length, (index) {
                      var s = rawStudents[index];
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
                      double perc = tFull > 0 ? (tObt / tFull) * 100 : 0;
                      String grade = hasAny ? _getGrade(perc) : '-';

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
            );
          },
        ),
      ),
    );
  }
}
