import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/data_service.dart';

class AttendanceLogScreen extends StatefulWidget {
  const AttendanceLogScreen({super.key});

  @override
  State<AttendanceLogScreen> createState() => _AttendanceLogScreenState();
}

class _AttendanceLogScreenState extends State<AttendanceLogScreen> {
  final DataService _dataService = DataService();
  final TextEditingController _batchController = TextEditingController();
  bool isLoading = false;

  static const bgColor = Color(0xFFF5F1E8);
  static const itemColor = Color(0xFF2B262C);

  @override
  Widget build(BuildContext context) {
    int day = DateTime.now().day;
    bool isOpen = day >= 1 && day <= 5;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Notification Center & Attendance', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: itemColor)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isOpen ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: isOpen ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(isOpen ? Icons.check_circle_rounded : Icons.lock_rounded, color: isOpen ? Colors.green : Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isOpen ? 'Attendance Window Open' : 'Attendance Window Closed', style: TextStyle(fontWeight: FontWeight.bold, color: isOpen ? Colors.green.shade800 : Colors.red.shade800)),
                        const SizedBox(height: 4),
                        Text(
                          isOpen ? 'Attendance logging is currently open (1st - 5th of the month).' : 'Attendance logging is closed today (Day $day of month). It is only open from the 1st to the 5th.',
                          style: TextStyle(fontSize: 12, color: itemColor.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Batch Attendance Entry', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: itemColor)),
            const SizedBox(height: 8),
            const Text('Format per line: Name, Father Name, Attendance %\nExample: John Doe, Mr. Doe, 92', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _batchController,
                maxLines: 12,
                enabled: isOpen,
                decoration: InputDecoration(
                  hintText: 'John Doe, Mr. Doe, 92\nJane Smith, Mr. Smith, 88',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: itemColor,
                  foregroundColor: bgColor,
                  padding: const EdgeInsets.all(15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: isOpen && !isLoading ? _submitAttendance : null,
                child: isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: bgColor))
                    : const Text('SUBMIT ATTENDANCE LOG', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitAttendance() async {
    if (_batchController.text.trim().isEmpty) return;
    setState(() => isLoading = true);
    try {
      List<String> lines = _batchController.text.trim().split('\n');
      List<Map<String, dynamic>> records = [];
      String monthYear = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';

      for (var line in lines) {
        var parts = line.split(',');
        if (parts.length >= 3) {
          String name = parts[0].trim();
          String fName = parts[1].trim();
          double percentage = double.tryParse(parts[2].trim().replaceAll('%', '')) ?? 0.0;
          records.add({
            'name': name,
            'father_name': fName,
            'percentage': percentage,
            'month_year': monthYear,
          });
        }
      }

      if (records.isNotEmpty) {
        await _dataService.submitAttendance(records);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance Log Submitted Successfully')));
          _batchController.clear();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
}
