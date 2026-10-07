import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../services/data_service.dart';

class ManageClassScreen extends StatefulWidget {
  const ManageClassScreen({super.key});

  @override
  State<ManageClassScreen> createState() => _ManageClassScreenState();
}

class _ManageClassScreenState extends State<ManageClassScreen> {
  final DataService _dataService = DataService();
  String? selectedGrade;
  String? selectedSection;
  String? userRole;
  bool _isOperationLoading = false;

  final List<String> grades = ['6', '7', '8', '9', '10', '11', '12'];
  final List<String> sections = ['A', 'B', 'None'];

  static const bgColor = Color(0xFFF5F1E8);
  static const itemColor = Color(0xFF2B262C);

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
      appBar: AppBar(
        title: Text('Database', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: itemColor, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: itemColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (selectedGrade != null && selectedSection != null) ...[
            IconButton(
              icon: const Icon(Icons.bookmark_added_rounded, color: itemColor),
              tooltip: 'Set Class Batch',
              onPressed: _showSetClassBatchDialog,
            ),
            if (userRole == 'developer')
              IconButton(
                icon: const Icon(Icons.category_rounded, color: itemColor),
                tooltip: 'Assign Category Tool',
                onPressed: _showAssignCategoryDialog,
              ),
            IconButton(
              icon: const Icon(Icons.group_add_rounded, color: itemColor),
              tooltip: 'Batch Import',
              onPressed: _showBatchImportDialog,
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildClassSelector(),
            const SizedBox(height: 24),
            if (selectedGrade != null && selectedSection != null)
              Expanded(
                child: FutureBuilder<List<Map<String, String>>>(
                  future: _dataService.getStudents(selectedGrade!, selectedSection!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: itemColor));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Load error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                    }
                    final students = snapshot.data ?? [];
                    if (students.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_add_alt_1_rounded, size: 64, color: itemColor.withValues(alpha: 0.1)),
                            const SizedBox(height: 16),
                            Text('No students registered', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: itemColor.withValues(alpha: 0.6))),
                          ],
                        ),
                      );
                    }
                    return FadeInUp(child: _buildStudentList(students));
                  },
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.class_rounded, size: 64, color: itemColor.withValues(alpha: 0.1)),
                      const SizedBox(height: 16),
                      Text('Select class to manage', style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: itemColor.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: selectedGrade != null && selectedSection != null
          ? FloatingActionButton.extended(
              onPressed: _addNewStudent,
              label: Text('Register Student', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              icon: const Icon(Icons.add_rounded),
              backgroundColor: itemColor,
              foregroundColor: bgColor,
            )
          : null,
    );
  }

  Widget _buildClassSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(20), border: Border.all(color: itemColor.withValues(alpha: 0.1))),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: (selectedGrade != null && grades.contains(selectedGrade)) ? selectedGrade : null,
              dropdownColor: bgColor,
              decoration: InputDecoration(labelText: 'GRADE', labelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: itemColor.withValues(alpha: 0.6), letterSpacing: 1), border: InputBorder.none),
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: itemColor),
              items: grades.map((g) => DropdownMenuItem(value: g, child: Text('Grade $g'))).toList(),
              onChanged: (v) => setState(() => selectedGrade = v),
            ),
          ),
          Container(width: 1, height: 40, color: itemColor.withValues(alpha: 0.1), margin: const EdgeInsets.symmetric(horizontal: 16)),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: (selectedSection != null && sections.contains(selectedSection)) ? selectedSection : null,
              dropdownColor: bgColor,
              decoration: InputDecoration(labelText: 'SECTION', labelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: itemColor.withValues(alpha: 0.6), letterSpacing: 1), border: InputBorder.none),
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: itemColor),
              items: sections.map((s) => DropdownMenuItem(value: s, child: Text('Section $s'))).toList(),
              onChanged: (v) => setState(() => selectedSection = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList(List<Map<String, String>> students) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text('Class Roster', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: itemColor, letterSpacing: -0.5)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: students.length,
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) {
              final student = students[index];
              final String name = student['name'] ?? 'Unnamed';
              final String fName = student['father_name'] ?? 'N/A';
              final String roleNo = student['role_no'] ?? 'N/A';
              final String pbId = student['pb_id'] ?? '';
              final String category = student['category'] ?? '';
              final String batch = student['batch'] ?? '2025';
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: itemColor.withValues(alpha: 0.1))),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: itemColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    alignment: Alignment.center,
                    child: Text(name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?', style: GoogleFonts.inter(color: itemColor, fontWeight: FontWeight.w800)),
                  ),
                  title: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: itemColor)),
                  subtitle: Text('Batch: $batch | S/O: $fName | Roll: $roleNo ${category.isNotEmpty ? "| $category" : ""}', style: GoogleFonts.inter(fontSize: 11, color: itemColor.withValues(alpha: 0.6), fontWeight: FontWeight.w500)),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_note_rounded, color: itemColor),
                    onPressed: pbId.isNotEmpty ? () => _editStudent(pbId, name) : null,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _editStudent(String pbId, String currentName) {
    TextEditingController controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgColor,
        title: Text('Edit Record', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: itemColor)),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Student Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await _dataService.updateStudent(pbId, controller.text);
              setState(() {}); Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showBatchImportDialog() {
    TextEditingController batchController = TextEditingController();
    TextEditingController batchYearController = TextEditingController(text: '2025');
    int g = int.tryParse(selectedGrade ?? '') ?? 0;
    String helperText = 'Format: RoleNo, Name, FatherName';
    if (g >= 9) {
      if (g <= 10) {
        helperText = 'Format: RoleNo, Name, FatherName, bio/computer';
      } else {
        helperText = 'Format: RoleNo, Name, FatherName, pre-medical/pre-engineering/ics';
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: bgColor,
          title: Text('Batch Register', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: itemColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: batchYearController,
                decoration: const InputDecoration(labelText: 'Batch Year (e.g. 2025, 2026)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: batchController, maxLines: 8,
                decoration: InputDecoration(
                  hintText: g >= 9 
                    ? (g <= 10 ? '101, John Doe, Mr. Doe, bio' : '101, John Doe, Mr. Doe, pre-medical')
                    : '101, John Doe, Mr. Doe',
                  helperText: helperText,
                  helperStyle: const TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: _isOperationLoading ? null : () async {
                if (batchController.text.trim().isEmpty) return;
                setDialogState(() => _isOperationLoading = true);
                try {
                  List<String> lines = batchController.text.trim().split('\n');
                  List<Map<String, String>> studentsToRegister = [];
                  for (var line in lines) {
                    var parts = line.split(',');
                    if (parts.length >= 2) {
                      String rNo = parts[0].trim();
                      String name = parts[1].trim();
                      String fName = parts.length > 2 ? parts[2].trim() : '';
                      String cat = parts.length > 3 ? parts[3].trim().toLowerCase() : '';
                      
                      studentsToRegister.add({
                        'name': name,
                        'father_name': fName,
                        'role_no': rNo,
                        'category': cat,
                      });
                    }
                  }
                  if (studentsToRegister.isNotEmpty) {
                    await _dataService.batchAddStudents(
                      students: studentsToRegister, 
                      grade: selectedGrade!, 
                      section: selectedSection!,
                      batch: batchYearController.text.trim(),
                    );
                    setState(() {}); Navigator.pop(context);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                } finally { setDialogState(() => _isOperationLoading = false); }
              },
              child: _isOperationLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Import'),
            ),
          ],
        ),
      ),
    );
  }

  void _addNewStudent() {
    TextEditingController nameController = TextEditingController();
    TextEditingController fatherNameController = TextEditingController();
    TextEditingController roleNoController = TextEditingController();
    TextEditingController batchYearController = TextEditingController(text: '2025');
    String? category;
    int g = int.tryParse(selectedGrade ?? '') ?? 0;

    List<String> options = [];
    if (g == 9 || g == 10) options = ['bio', 'computer'];
    if (g == 11 || g == 12) options = ['pre-medical', 'pre-engineering', 'ics'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: bgColor,
          title: Text('New Student', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: itemColor)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: roleNoController, decoration: const InputDecoration(labelText: 'Roll No')),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full Name')),
            TextField(controller: fatherNameController, decoration: const InputDecoration(labelText: 'Father\'s Name')),
            TextField(controller: batchYearController, decoration: const InputDecoration(labelText: 'Batch Year (e.g. 2025, 2026)')),
            if (options.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: DropdownButtonFormField<String>(
                  value: (category != null && options.contains(category)) ? category : null,
                  decoration: const InputDecoration(labelText: 'Select Category'),
                  items: options.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
                  onChanged: (v) => setDialogState(() => category = v),
                ),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await _dataService.addStudent(
                  name: nameController.text.trim(), 
                  fatherName: fatherNameController.text.trim(),
                  roleNo: roleNoController.text.trim(),
                  grade: selectedGrade!, 
                  section: selectedSection!,
                  category: category,
                  batch: batchYearController.text.trim(),
                );
                setState(() {}); Navigator.pop(context);
              },
              child: const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSetClassBatchDialog() {
    TextEditingController controller = TextEditingController(text: '2025');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgColor,
        title: Text('Assign Batch to Grade $selectedGrade ($selectedSection)', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: itemColor)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Batch Year (e.g. 2025, 2026)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              setState(() => _isOperationLoading = true);
              Navigator.pop(context);
              String? error = await _dataService.assignBatchToClass(
                grade: selectedGrade!,
                section: selectedSection!,
                batch: controller.text.trim(),
              );
              setState(() => _isOperationLoading = false);
              if (mounted) {
                if (error != null) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('PocketBase Schema Required'),
                      content: Text(error),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
                      ],
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Batch ${controller.text.trim()} assigned to Grade $selectedGrade (Sec: $selectedSection)')),
                  );
                }
              }
              setState(() {});
            },
            child: const Text('Apply to All'),
          ),
        ],
      ),
    );
  }

  void _showAssignCategoryDialog() {
    int g = int.tryParse(selectedGrade ?? '') ?? 0;
    List<String> options = [];
    if (g == 9 || g == 10) {
      options = ['biology', 'computer'];
    } else if (g == 11 || g == 12) {
      options = ['pre-medical', 'pre-engineering', 'ics'];
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category labeling tool is for Grades 9, 10, 11 (1st Year) and 12 (2nd Year)')),
      );
      return;
    }

    String selectedCategory = options.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: bgColor,
          title: Text('Assign Category (Grade $selectedGrade Sec $selectedSection)', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: itemColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This will stamp the selected category onto all students in this class AND update their result records so it carries over to results.', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(labelText: 'Select Category', border: OutlineInputBorder()),
                items: options.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
                onChanged: (v) => setDialogState(() => selectedCategory = v ?? options.first),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isOperationLoading = true);
                String msg = await _dataService.assignCategoryToClassAndResults(
                  grade: selectedGrade!,
                  section: selectedSection!,
                  category: selectedCategory,
                );
                setState(() => _isOperationLoading = false);
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Category Tool Result'),
                      content: Text(msg),
                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                    ),
                  );
                }
              },
              child: const Text('Apply to Students & Results'),
            ),
          ],
        ),
      ),
    );
  }
}
