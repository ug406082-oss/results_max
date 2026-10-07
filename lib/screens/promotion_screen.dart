import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/data_service.dart';

class PromotionScreen extends StatefulWidget {
  const PromotionScreen({super.key});

  @override
  State<PromotionScreen> createState() => _PromotionScreenState();
}

class _PromotionScreenState extends State<PromotionScreen> {
  final DataService _dataService = DataService();
  String? selectedBatch;
  List<String> batches = [];
  List<Map<String, dynamic>> students = [];
  Set<String> selectedForPromotion = {};
  bool isLoading = false;

  static const itemColor = Color(0xFF2B262C);
  static const bgColor = Color(0xFFF5F1E8);

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() => isLoading = true);
    final bList = await _dataService.getBatches();
    setState(() {
      batches = bList;
      if (batches.isNotEmpty) {
        selectedBatch = batches.first;
        _loadStudentsForBatch();
      } else {
        isLoading = false;
      }
    });
  }

  Future<void> _loadStudentsForBatch() async {
    if (selectedBatch == null) return;
    setState(() => isLoading = true);
    final raw = await _dataService.getStudentsByBatch(selectedBatch!);
    setState(() {
      students = raw;
      selectedForPromotion = students.map((e) => e['pb_id'] as String).toSet();
      isLoading = false;
    });
  }

  Future<void> _processPromotion() async {
    if (selectedForPromotion.isEmpty || students.isEmpty) return;
    
    // Determine target grade (assume batch shares or increments grade based on majority or current grade)
    // For simplicity, promote each selected student's grade by 1
    setState(() => isLoading = true);
    
    for (var s in students) {
      if (selectedForPromotion.contains(s['pb_id'])) {
        int currentGrade = int.tryParse(s['grade']?.toString() ?? '6') ?? 6;
        if (currentGrade < 12) {
          String nextGrade = (currentGrade + 1).toString();
          await _dataService.promoteStudents(
            studentPbIds: [s['pb_id']],
            nextGrade: nextGrade,
          );
        }
      }
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully promoted selected students in batch!')),
      );
    }
    
    _loadStudentsForBatch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(title: Text('Batch Promotion', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: itemColor))),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildBatchSelector(),
            const SizedBox(height: 20),
            if (students.isNotEmpty) _buildPromotionHeader(),
            Expanded(
              child: isLoading 
                ? const Center(child: CircularProgressIndicator(color: itemColor))
                : (students.isEmpty ? _buildEmptyState() : _buildStudentList()),
            ),
          ],
        ),
      ),
      bottomNavigationBar: students.isEmpty ? null : _buildBottomBar(),
    );
  }

  Widget _buildBatchSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: itemColor.withValues(alpha: 0.1))),
      child: DropdownButtonFormField<String>(
        value: (selectedBatch != null && batches.contains(selectedBatch)) ? selectedBatch : null,
        dropdownColor: bgColor,
        decoration: const InputDecoration(labelText: 'SELECT COHORT / BATCH', border: InputBorder.none),
        items: batches.map((e) => DropdownMenuItem(value: e, child: Text('Batch $e', style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
        onChanged: (v) {
          setState(() {
            selectedBatch = v;
            _loadStudentsForBatch();
          });
        },
      ),
    );
  }

  Widget _buildPromotionHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Managing Cohort: Batch $selectedBatch', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStudentList() {
    return ListView.builder(
      itemCount: students.length,
      itemBuilder: (context, index) {
        final s = students[index];
        final id = s['pb_id'] as String;
        final isSelected = selectedForPromotion.contains(id);
        final grade = s['grade'] ?? 'N/A';
        final section = s['section'] ?? 'None';

        return CheckboxListTile(
          value: isSelected,
          title: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Current: Grade $grade (Sec: $section) | S/O: ${s['father_name'] ?? 'N/A'}'),
          secondary: CircleAvatar(backgroundColor: itemColor.withValues(alpha: 0.1), child: Text(s['name']![0])),
          onChanged: (v) {
            setState(() {
              if (v == true) selectedForPromotion.add(id);
              else selectedForPromotion.remove(id);
            });
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 64, color: itemColor.withValues(alpha: 0.2)),
          const SizedBox(height: 10),
          const Text('No students found for this batch.'),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.black12))),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: itemColor, foregroundColor: Colors.white, padding: const EdgeInsets.all(15)),
        onPressed: selectedForPromotion.isEmpty ? null : _processPromotion,
        child: Text('PROMOTE ${selectedForPromotion.length} SELECTED STUDENTS TO NEXT GRADE', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
