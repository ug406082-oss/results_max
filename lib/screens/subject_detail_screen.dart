import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:animate_do/animate_do.dart';
import '../services/data_service.dart';

class SubjectDetailScreen extends StatefulWidget {
  final String subject;
  const SubjectDetailScreen({super.key, required this.subject});

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  final DataService _dataService = DataService();
  Set<String> selectedGrades = {};
  bool _isInit = true;

  static const bgColor = Color(0xFFF5F1E8);
  static const itemColor = Color(0xFF2B262C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('${widget.subject} Detail', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: itemColor, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        foregroundColor: itemColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: itemColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<RecordModel>>(
        future: _dataService.getAllResults(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: itemColor));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: itemColor)));
          }

          final allDocs = snapshot.data ?? [];
          
          final availableGrades = allDocs
              .where((doc) => doc.data['subject'] == widget.subject)
              .map((doc) => doc.data['grade'].toString())
              .toSet()
              .toList()
            ..sort((a, b) => int.tryParse(a)?.compareTo(int.tryParse(b) ?? 0) ?? 0);

          if (_isInit && availableGrades.isNotEmpty) {
            selectedGrades = Set.from(availableGrades);
            _isInit = false;
          }

          final subjectResults = allDocs.where((doc) {
            return doc.data['subject'] == widget.subject && selectedGrades.contains(doc.data['grade'].toString());
          }).toList();

          if (availableGrades.isEmpty) {
            return Center(child: Text('No data recorded for ${widget.subject}', style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: itemColor)));
          }

          Map<String, List<double>> classMap = {};
          for (var doc in subjectResults) {
            final data = doc.data;
            String classKey = 'G${data['grade']}${data['section']}';
            double marks = (data['marks'] as num).toDouble();
            classMap.putIfAbsent(classKey, () => []).add(marks);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGradeFilter(availableGrades),
                const SizedBox(height: 32),
                _buildSummaryStats(subjectResults),
                const SizedBox(height: 40),
                Text('Class Comparison', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: itemColor, letterSpacing: -0.5)),
                const SizedBox(height: 16),
                FadeInUp(child: _buildClassChart(classMap)),
                const SizedBox(height: 40),
                Text('Performance Rankings', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: itemColor, letterSpacing: -0.5)),
                const SizedBox(height: 16),
                _buildClassList(classMap),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGradeFilter(List<String> availableGrades) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FILTER BY GRADE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: itemColor.withValues(alpha: 0.6), letterSpacing: 1)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableGrades.map((grade) {
            final isSelected = selectedGrades.contains(grade);
            return FilterChip(
              label: Text('Grade $grade', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? bgColor : itemColor)),
              selected: isSelected,
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    selectedGrades.add(grade);
                  } else {
                    if (selectedGrades.length > 1) {
                      selectedGrades.remove(grade);
                    }
                  }
                });
              },
              backgroundColor: Colors.white.withValues(alpha: 0.5),
              selectedColor: itemColor,
              checkmarkColor: bgColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: isSelected ? itemColor : itemColor.withValues(alpha: 0.1)),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSummaryStats(List<RecordModel> results) {
    if (results.isEmpty) return const SizedBox();
    
    double total = 0;
    double max = 0;
    for (var doc in results) {
      double marks = (doc.data['marks'] as num).toDouble();
      total += marks;
      if (marks > max) max = marks;
    }
    double avg = total / results.length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: itemColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('AVG SCORE', '${avg.toStringAsFixed(1)}%'),
          _buildSummaryItem('HIGH SCORE', '${max.toInt()}'),
          _buildSummaryItem('TOTAL ENTRIES', '${results.length}'),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: bgColor)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: bgColor.withValues(alpha: 0.6), letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildClassChart(Map<String, List<double>> classMap) {
    if (classMap.isEmpty) return const Center(child: Text("Select a grade to view comparison", style: TextStyle(color: itemColor)));

    List<BarChartGroupData> groups = [];
    int i = 0;
    classMap.forEach((classKey, scores) {
      double avg = scores.reduce((a, b) => a + b) / scores.length;
      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: avg,
            color: itemColor,
            width: 32,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            backDrawRodData: BackgroundBarChartRodData(show: true, toY: 100, color: Colors.white.withValues(alpha: 0.3)),
          )
        ],
      ));
      i++;
    });

    return Container(
      height: 280,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(24), border: Border.all(color: itemColor.withValues(alpha: 0.1))),
      padding: const EdgeInsets.all(24),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  List<String> keys = classMap.keys.toList();
                  if (value.toInt() < keys.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(keys[value.toInt()], style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: itemColor.withValues(alpha: 0.5))),
                    );
                  }
                  return const Text("");
                },
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 20, getTitlesWidget: (v, m) => Text('${v.toInt()}', style: GoogleFonts.inter(fontSize: 10, color: itemColor.withValues(alpha: 0.5))), reservedSize: 28)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: itemColor.withValues(alpha: 0.05), strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          barGroups: groups,
        ),
      ),
    );
  }

  Widget _buildClassList(Map<String, List<double>> classMap) {
    if (classMap.isEmpty) return const SizedBox();

    final sortedClasses = classMap.keys.toList()
      ..sort((a, b) {
        double avgA = classMap[a]!.reduce((x, y) => x + y) / classMap[a]!.length;
        double avgB = classMap[b]!.reduce((x, y) => x + y) / classMap[b]!.length;
        return avgB.compareTo(avgA);
      });

    return Column(
      children: sortedClasses.asMap().entries.map((entry) {
        int index = entry.key;
        String classKey = entry.value;
        double avg = classMap[classKey]!.reduce((a, b) => a + b) / classMap[classKey]!.length;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: itemColor.withValues(alpha: 0.1))),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: itemColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Text('${index + 1}', style: GoogleFonts.inter(color: itemColor, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(classKey, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: itemColor))),
              Text('${avg.toStringAsFixed(1)}%', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: itemColor, fontSize: 16)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
