import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/data_service.dart';

class StudentDetailDrillDownScreen extends StatefulWidget {
  final Map<String, dynamic> student;
  const StudentDetailDrillDownScreen({super.key, required this.student});

  @override
  State<StudentDetailDrillDownScreen> createState() => _StudentDetailDrillDownScreenState();
}

class _StudentDetailDrillDownScreenState extends State<StudentDetailDrillDownScreen> {
  final DataService _dataService = DataService();
  bool isLoading = true;
  List<RecordModel> studentResults = [];

  static const bgColor = Color(0xFFF5F1E8);
  static const itemColor = Color(0xFF2B262C);

  @override
  void initState() {
    super.initState();
    _loadStudentResults();
  }

  Future<void> _loadStudentResults() async {
    setState(() => isLoading = true);
    String pbId = widget.student['pb_id'] ?? '';
    String name = widget.student['name'] ?? '';

    try {
      final allResults = await _dataService.getAllResults();
      final filtered = allResults.where((r) {
        String rSid = r.getStringValue('student_id');
        String rName = r.getStringValue('studentName');
        return (pbId.isNotEmpty && rSid == pbId) || (rName.toLowerCase() == name.toLowerCase());
      }).toList();

      if (mounted) {
        setState(() {
          studentResults = filtered;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    String name = s['name'] ?? 'Unnamed';
    String fName = s['father_name'] ?? 'N/A';
    String roleNo = s['role_no'] ?? 'N/A';
    String grade = s['grade'] ?? 'N/A';
    String section = s['section'] ?? 'None';
    String category = s['category'] ?? 'General';
    String batch = s['batch'] ?? '2025';

    // Calculate aggregate score
    double totalObtained = 0;
    double totalMax = 0;
    for (var r in studentResults) {
      totalObtained += r.getDoubleValue('marks');
      totalMax += r.getDoubleValue('totalMarks');
    }
    double overallPct = totalMax > 0 ? (totalObtained / totalMax) * 100 : 0.0;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Student Profile', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: itemColor)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: itemColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: itemColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Student Info Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: itemColor.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: itemColor.withValues(alpha: 0.1),
                          child: Text(name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: itemColor)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: itemColor)),
                              const SizedBox(height: 4),
                              Text('Father: $fName | Roll No: $roleNo', style: GoogleFonts.inter(fontSize: 13, color: itemColor.withValues(alpha: 0.7))),
                              const SizedBox(height: 4),
                              Text('Grade: $grade (${section == 'None' ? 'Entire Class' : 'Section $section'}) | Batch: $batch', style: GoogleFonts.inter(fontSize: 12, color: itemColor.withValues(alpha: 0.6))),
                              if (category.isNotEmpty && category != 'None') ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blue.shade200)),
                                  child: Text('Program: ${category.toUpperCase()}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Performance Summary
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: itemColor.withValues(alpha: 0.1))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Overall Score', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                              const SizedBox(height: 8),
                              Text('${totalObtained.toStringAsFixed(0)} / ${totalMax.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: itemColor)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: itemColor.withValues(alpha: 0.1))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Overall Percentage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                              const SizedBox(height: 8),
                              Text('${overallPct.toStringAsFixed(1)}%', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: overallPct >= 50 ? Colors.green.shade700 : Colors.red.shade700)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text('Result Records (${studentResults.length})', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: itemColor)),
                  const SizedBox(height: 12),
                  if (studentResults.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
                      child: Text('No result records submitted for this student yet.', style: GoogleFonts.inter(color: itemColor.withValues(alpha: 0.6))),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: studentResults.length,
                      itemBuilder: (context, index) {
                        final r = studentResults[index];
                        String sub = r.getStringValue('subject');
                        String term = r.getStringValue('term');
                        String test = r.getStringValue('test');
                        double marks = r.getDoubleValue('marks');
                        double total = r.getDoubleValue('totalMarks');
                        double pct = total > 0 ? (marks / total) * 100 : 0.0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: itemColor.withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(sub, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: itemColor)),
                                  const SizedBox(height: 4),
                                  Text('$term • $test', style: GoogleFonts.inter(fontSize: 11, color: itemColor.withValues(alpha: 0.6))),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${marks.toStringAsFixed(1)} / $total', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: itemColor)),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: pct >= 50 ? Colors.green.shade50 : Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: pct >= 50 ? Colors.green.shade700 : Colors.red.shade700)),
                                  ),
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
    );
  }
}
