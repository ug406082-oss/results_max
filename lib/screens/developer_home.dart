import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';

class DeveloperHomeScreen extends StatefulWidget {
  const DeveloperHomeScreen({super.key});

  @override
  State<DeveloperHomeScreen> createState() => _DeveloperHomeScreenState();
}

class _DeveloperHomeScreenState extends State<DeveloperHomeScreen> {
  final DataService _dataService = DataService();
  final AuthService _authService = AuthService();

  final List<String> grades = ['6', '7', '8', '9', '10', '11', '12'];
  final List<String> sections = ['A', 'B', 'None'];
  bool _isOperationLoading = false;

  static const bgColor = Color(0xFFF5F1E8);
  static const itemColor = Color(0xFF2B262C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Developer Panel', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: itemColor)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: itemColor),
            onPressed: () => _authService.signOut(),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Class Management & Promotion', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: itemColor)),
            const SizedBox(height: 8),
            Text('Manage student categories, standards, and promotions across all grades.', style: GoogleFonts.inter(color: itemColor.withValues(alpha: 0.6))),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: grades.length,
                itemBuilder: (context, gIndex) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text('Grade ${grades[gIndex]}', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: itemColor)),
                      ),
                      ...sections.map((sec) => _buildClassCard(grades[gIndex], sec)),
                      const Divider(height: 32),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassCard(String grade, String section) {
    String displaySection = section == 'None' ? 'Entire Class' : 'Section $section';
    String subtitleText = section == 'None' 
        ? 'Manage records for the whole of Grade $grade'
        : 'Manage records for Grade $grade $section';
    int g = int.tryParse(grade) ?? 0;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _dataService.getStudents(grade, section),
      builder: (context, snapshot) {
        int count = snapshot.data?.length ?? 0;
        if (count == 0) return const SizedBox.shrink(); // Hide if no students in this specific configuration

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: itemColor.withValues(alpha: 0.1)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: itemColor.withValues(alpha: 0.05),
              child: Text(grade, style: const TextStyle(color: itemColor, fontWeight: FontWeight.bold)),
            ),
            title: Text(displaySection, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('$count Students registered - $subtitleText'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (g >= 9)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: itemColor),
                    onPressed: () => _showCategorySelectionDialog(grade, section),
                    icon: const Icon(Icons.category_rounded, size: 16),
                    label: const Text('Category'),
                  ),
                if (g >= 9) const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: itemColor,
                    foregroundColor: bgColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showPromotionDialog(grade, section),
                  child: const Text('Promote'),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  void _showCategorySelectionDialog(String grade, String section) async {
    List<Map<String, dynamic>> students = await _dataService.getStudents(grade, section);
    if (students.isEmpty) return;

    Set<String> selectedStudents = students.map((e) => e['pb_id'] as String).toSet();
    int g = int.tryParse(grade) ?? 0;
    List<String> options = [];
    if (g == 9 || g == 10) {
      options = ['biology', 'computer'];
    } else if (g == 11 || g == 12) {
      options = ['pre medical', 'pre engineering', 'ics'];
    } else {
      options = ['biology', 'computer', 'pre medical', 'pre engineering', 'ics'];
    }
    String selectedCategory = options.first;
    String displayClass = section == 'None' ? 'Grade $grade' : 'Grade $grade $section';

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assign Category - $displayClass', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: itemColor)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(labelText: 'Select Category / Program', border: OutlineInputBorder()),
                items: options.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
                onChanged: (v) => setDialogState(() => selectedCategory = v ?? options.first),
              ),
              const SizedBox(height: 20),
              Text('Select students to update:', style: TextStyle(fontWeight: FontWeight.w600, color: itemColor.withValues(alpha: 0.6))),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final s = students[index];
                    final id = s['pb_id'] as String;
                    final isSelected = selectedStudents.contains(id);
                    final cat = s['category'] ?? 'None';
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(s['name'] ?? ''),
                      subtitle: Text('S/O: ${s['father_name'] ?? 'N/A'} | Current: $cat'),
                      onChanged: (v) {
                        setDialogState(() {
                          if (v == true) {
                            selectedStudents.add(id);
                          } else {
                            selectedStudents.remove(id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: itemColor, foregroundColor: bgColor),
                  onPressed: selectedStudents.isEmpty ? null : () async {
                    Navigator.pop(context);
                    setState(() => _isOperationLoading = true);
                    String msg = await _dataService.assignCategoryToStudents(
                      studentPbIds: selectedStudents.toList(),
                      category: selectedCategory,
                    );
                    setState(() => _isOperationLoading = false);
                    if (mounted) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Category Assignment Result'),
                          content: Text(msg),
                          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                        ),
                      );
                    }
                  },
                  child: Text('APPLY CATEGORY TO (${selectedStudents.length}) STUDENTS'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }



  void _showPromotionDialog(String grade, String section) async {
    List<Map<String, dynamic>> students = await _dataService.getStudents(grade, section);
    if (students.isEmpty) return;

    Set<String> selectedForPromotion = students.map((e) => e['pb_id'] as String).toSet();
    int current = int.tryParse(grade) ?? 0;
    String next = (current + 1).toString();
    String displayClass = section == 'None' ? 'Grade $grade' : 'Grade $grade $section';

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Promote $displayClass', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900)),
              Text('Moving to Grade $next', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Text('Select students to promote:', style: TextStyle(fontWeight: FontWeight.w600, color: itemColor.withValues(alpha: 0.6))),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final s = students[index];
                    final id = s['pb_id'] as String;
                    final isSelected = selectedForPromotion.contains(id);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(s['name'] ?? ''),
                      subtitle: Text('S/O: ${s['father_name'] ?? 'N/A'}'),
                      onChanged: (v) {
                        setDialogState(() {
                          if (v == true) {
                            selectedForPromotion.add(id);
                          } else {
                            selectedForPromotion.remove(id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: itemColor, foregroundColor: bgColor),
                  onPressed: selectedForPromotion.isEmpty ? null : () async {
                    await _dataService.promoteStudents(
                      studentPbIds: selectedForPromotion.toList(),
                      nextGrade: next,
                    );
                    if (context.mounted) Navigator.pop(context);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Promoted to Grade $next')));
                    }
                  },
                  child: Text('CONFIRM PROMOTION (${selectedForPromotion.length})'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
