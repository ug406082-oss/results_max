import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/data_service.dart';

class StudentHistoryScreen extends StatefulWidget {
  final String studentName;
  final String fatherName;
  final String studentID;
  final String studentPbID;
  const StudentHistoryScreen({super.key, required this.studentName, required this.fatherName, required this.studentID, required this.studentPbID});

  @override
  State<StudentHistoryScreen> createState() => _StudentHistoryScreenState();
}

class _StudentHistoryScreenState extends State<StudentHistoryScreen> with TickerProviderStateMixin {
  final DataService _dataService = DataService();
  bool isLoading = true;
  List<RecordModel> historyRecords = [];
  List<RecordModel> attendanceRecords = [];
  List<ExamGroup> examGroups = [];
  
  // Selection for Comparison tab
  Set<String> selectedExamsForComparison = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final data = await _dataService.getStudentHistory(widget.studentPbID, widget.studentName);
    final attData = await _dataService.getStudentAttendance(widget.studentName, widget.fatherName);
    setState(() {
      historyRecords = data;
      attendanceRecords = attData;
      examGroups = _groupRecordsIntoExams();
      isLoading = false;
    });
  }

  List<ExamGroup> _groupRecordsIntoExams() {
    Map<String, List<RecordModel>> map = {};
    for (var rec in historyRecords) {
      String key = "${rec.getStringValue('grade')}_${rec.getStringValue('term')}_${rec.getStringValue('test')}";
      map.putIfAbsent(key, () => []).add(rec);
    }
    
    List<ExamGroup> groups = map.entries.map((e) => ExamGroup(key: e.key, records: e.value)).toList();
    // Sort groups chronologically (Grade, then created time of first record in group)
    groups.sort((a, b) {
       int gA = int.tryParse(a.records.first.getStringValue('grade')) ?? 0;
       int gB = int.tryParse(b.records.first.getStringValue('grade')) ?? 0;
       if (gA != gB) return gA.compareTo(gB);
       return a.records.first.getStringValue('created').compareTo(b.records.first.getStringValue('created'));
    });
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    const itemColor = Color(0xFF2B262C);
    const bgColor = Color(0xFFF5F1E8);

    if (isLoading) {
      return Scaffold(backgroundColor: bgColor, body: const Center(child: CircularProgressIndicator(color: itemColor)));
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.studentName, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18)),
              Text('ID: ${widget.studentPbID}', style: TextStyle(fontSize: 10, color: itemColor.withOpacity(0.5))),
            ],
          ),
          bottom: TabBar(
            indicatorColor: itemColor,
            labelColor: itemColor,
            unselectedLabelColor: itemColor.withOpacity(0.4),
            tabs: const [
              Tab(text: 'History'),
              Tab(text: 'Analysis'),
              Tab(text: 'Comparison'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildHistoryTab(itemColor),
            _buildAnalysisTab(itemColor),
            _buildComparisonTab(itemColor),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: HISTORY ---

  Widget _buildHistoryTab(Color color) {
    // Spec: One row per entered result/exam event, most recent first
    final sortedByRecent = [...examGroups].reversed.toList();
    
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildMachineSummary("Record Accuracy", "Every result below is linked to the student's permanent machine ID, ensuring 100% data integrity.", color),
        const SizedBox(height: 20),
        ...sortedByRecent.map((group) {
          double avg = group.calculateAverage();
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              onTap: () => _showSpreadsheet(group, null, hideComparison: true),
              title: Text(group.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("ID: ${group.records.first.id.substring(0,8)}..."),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Text("${avg.toStringAsFixed(1)}%", style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          );
        }),
      ],
    );
  }

  // --- TAB 2: ANALYSIS ---

  Widget _buildAnalysisTab(Color color) {
    // Machine Logic to detect anomalies
    List<Anomaly> anomalies = _detectAnomalies();
    
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${anomalies.length} Potential Anomalies Detected", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              Text("Overall Trend: ${_getOverallTrend()}", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (anomalies.isEmpty) 
          const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No significant anomalies found. Student performance is stable.")))
        else
          ...anomalies.map((a) => _buildAnomalyCard(a, color)),
      ],
    );
  }

  List<Anomaly> _detectAnomalies() {
    List<Anomaly> found = [];
    if (examGroups.length < 2) return found;

    // 1. Trend Anomaly (Sharp decline)
    double latest = examGroups.last.calculateAverage();
    double previous = examGroups[examGroups.length - 2].calculateAverage();
    if (latest < previous - 5) {
      found.add(Anomaly(
        title: "Significant Grade Drop",
        description: "Overall performance dropped by ${(previous - latest).toStringAsFixed(1)}% in the last assessment.",
        severity: "critical",
        type: AnomalyType.trend,
        explanation: "A drop of more than 5 points between consecutive exams suggests a potential issue in comprehension or external factors impacting studies.",
      ));
    }

    // 2. Subject Gap Anomaly
    Map<String, List<double>> subjectScores = {};
    for (var r in historyRecords) {
      subjectScores.putIfAbsent(r.getStringValue('subject'), () => []).add((r.getDoubleValue('marks') / r.getDoubleValue('totalMarks')) * 100);
    }
    subjectScores.forEach((sub, scores) {
       double avg = scores.reduce((a,b) => a+b) / scores.length;
       double overallAvg = historyRecords.map((r) => (r.getDoubleValue('marks') / r.getDoubleValue('totalMarks')) * 100).reduce((a,b) => a+b) / historyRecords.length;
       if (avg < overallAvg - 15) {
         found.add(Anomaly(
            title: "Subject Variance Gap",
            description: "$sub is significantly below the student's overall average.",
            severity: "warning",
            type: AnomalyType.subjectGap,
            explanation: "While other subjects are stable, $sub shows a 15%+ negative variance, indicating a specific academic gap in this area.",
         ));
       }
    });

    // 3. Attendance Anomaly (< 75%)
    for (var att in attendanceRecords) {
      double perc = att.getDoubleValue('percentage');
      String monthYear = att.getStringValue('month_year');
      if (perc < 75.0) {
        found.add(Anomaly(
          title: "Low Attendance Warning",
          description: "Monthly attendance for $monthYear was ${perc.toStringAsFixed(1)}% (Below 75% threshold).",
          severity: "critical",
          type: AnomalyType.attendance,
          explanation: "Low attendance (<75%) directly impacts academic progress and comprehension.",
        ));
      }
    }

    return found;
  }

  String _getOverallTrend() {
    if (examGroups.length < 2) return "Insufficient Data";
    double latest = examGroups.last.calculateAverage();
    double first = examGroups.first.calculateAverage();
    if (latest > first + 2) return "Upward Trajectory ↑";
    if (latest < first - 2) return "Downward Trend ↓";
    return "Stable Performance ↔";
  }

  Widget _buildAnomalyCard(Anomaly a, Color color) {
    Color sevColor = a.severity == 'critical' ? Colors.red : (a.severity == 'warning' ? Colors.orange : Colors.blue);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => _showAnomalyDetail(a, color),
        leading: Icon(Icons.warning_amber_rounded, color: sevColor),
        title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(a.description, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 16),
      ),
    );
  }

  void _showAnomalyDetail(Anomaly a, Color color) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF5F1E8),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(30),
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
               Text("Analysis Detail", style: TextStyle(color: color.withOpacity(0.5), fontWeight: FontWeight.bold, fontSize: 12)),
               IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
             ]),
             Text(a.title, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900)),
             const SizedBox(height: 20),
             Text(a.explanation, style: TextStyle(fontSize: 14, color: color.withOpacity(0.7), height: 1.5)),
             const SizedBox(height: 40),
             const Center(child: Text("[Anomaly Specific Chart Visualized Here]", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))),
             const Spacer(),
             _buildMachineSummary("Actionable Insight", "We recommend immediate teacher consultation for ${widget.studentName} regarding ${a.title}.", color),
          ],
        ),
      ),
    );
  }

  // --- TAB 3: COMPARISON ---

  Widget _buildComparisonTab(Color color) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'Progression'),
              Tab(text: 'Term-to-term'),
              Tab(text: 'Class Average'),
              Tab(text: 'Subject Intelligence'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildProgressionSubTab(color),
                _buildTermToTermSubTab(color),
                _buildClassAvgSubTab(color),
                _buildSubjectIntelligencePlot(examGroups, color),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressionSubTab(Color color) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Select any 2 to compare", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ElevatedButton(
                onPressed: selectedExamsForComparison.length == 2 ? _compareSelectedExams : null,
                style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
                child: const Text("Compare Selected"),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: examGroups.length,
              itemBuilder: (context, index) {
                final group = examGroups[index];
                final prev = index > 0 ? examGroups[index-1] : null;
                double avg = group.calculateAverage();
                double diff = prev != null ? avg - prev.calculateAverage() : 0;
                
                return CheckboxListTile(
                  value: selectedExamsForComparison.contains(group.key),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        if (selectedExamsForComparison.length < 2) selectedExamsForComparison.add(group.key);
                      } else {
                        selectedExamsForComparison.remove(group.key);
                      }
                    });
                  },
                  title: Text(group.displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: Text(index > 0 ? "Change: ${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}%" : "Baseline Entry", style: TextStyle(fontSize: 10, color: diff >= 0 ? Colors.green : Colors.red)),
                  secondary: Text("${avg.toStringAsFixed(1)}%", style: const TextStyle(fontWeight: FontWeight.w900)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _compareSelectedExams() {
    final keys = selectedExamsForComparison.toList();
    final g1 = examGroups.firstWhere((g) => g.key == keys[0]);
    final g2 = examGroups.firstWhere((g) => g.key == keys[1]);
    
    double avg1 = g1.calculateAverage();
    double avg2 = g2.calculateAverage();
    double diff = avg2 - avg1;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF5F1E8),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Binary Assessment Comparison", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCompItem(g1.displayName, avg1),
                const Icon(Icons.compare_arrows, color: Colors.blue),
                _buildCompItem(g2.displayName, avg2),
              ],
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Performance Variance: ", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  Text("${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}%", style: TextStyle(color: diff >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.w900, fontSize: 20)),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCompItem(String name, double val) {
     return Column(children: [
       Text(name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
       Text("${val.toStringAsFixed(1)}%", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
     ]);
  }

  Widget _buildTermToTermSubTab(Color color) {
    // Aggregated overall average per term checkpoint
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
           _buildMachineSummary("Term Checkpoint", "This chart tracks the overall average at each seasonal milestone (1st → 2nd → Final).", color),
           const SizedBox(height: 40),
           Expanded(child: _buildTermLineChart(color)),
        ],
      ),
    );
  }

  Widget _buildClassAvgSubTab(Color color) {
    if (examGroups.isEmpty) {
      return const Center(child: Text("No exam history available for class average comparison."));
    }

    return FutureBuilder<Map<String, double>>(
      future: _calculateClassAverages(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: color));
        }
        final classAvgs = snapshot.data ?? {};

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: examGroups.length,
          itemBuilder: (context, index) {
            final group = examGroups[index];
            double studentAvg = group.calculateAverage();
            double classAvg = classAvgs[group.key] ?? 0.0;
            double diff = studentAvg - classAvg;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(group.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Student: ${studentAvg.toStringAsFixed(1)}%  |  Class Avg: ${classAvg > 0 ? '${classAvg.toStringAsFixed(1)}%' : 'N/A'}"),
                trailing: classAvg > 0 ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (diff >= 0 ? Colors.green : Colors.red).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}%",
                    style: TextStyle(fontWeight: FontWeight.bold, color: diff >= 0 ? Colors.green : Colors.red),
                  ),
                ) : const Text('-', style: TextStyle(color: Colors.grey)),
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, double>> _calculateClassAverages() async {
    Map<String, double> avgs = {};
    for (var group in examGroups) {
      try {
        var results = await _dataService.getClassResults(
          grade: group.grade,
          section: 'None',
          term: group.term,
          test: group.test,
        );
        if (results.isEmpty) {
          results = await _dataService.getClassResults(
            grade: group.grade,
            section: 'A',
            term: group.term,
            test: group.test,
          );
        }
        if (results.isEmpty) {
          results = await _dataService.getClassResults(
            grade: group.grade,
            section: 'B',
            term: group.term,
            test: group.test,
          );
        }

        if (results.isNotEmpty) {
          double totalMarksSum = 0;
          double obtainedMarksSum = 0;
          for (var r in results) {
            obtainedMarksSum += r.getDoubleValue('marks');
            double tot = r.getDoubleValue('totalMarks');
            totalMarksSum += (tot > 0 ? tot : 100);
          }
          avgs[group.key] = totalMarksSum > 0 ? (obtainedMarksSum / totalMarksSum) * 100 : 0.0;
        } else {
          avgs[group.key] = 0.0;
        }
      } catch (e) {
        avgs[group.key] = 0.0;
      }
    }
    return avgs;
  }

  // --- REUSED UI HELPERS ---

  Widget _buildTermLineChart(Color color) {
    final terms = ["1st Term", "2nd Term", "Final Term"];
    List<FlSpot> spots = [];
    int xIdx = 0;
    for (int grade = 6; grade <= 12; grade++) {
       for (var t in terms) {
          final match = examGroups.where((g) => g.grade == grade.toString() && g.term == t).firstOrNull;
          if (match != null) {
             spots.add(FlSpot(xIdx.toDouble(), match.calculateAverage()));
          }
          xIdx++;
       }
    }

    if (spots.length < 2) return const Center(child: Text("Not enough data points for term tracking."));

    return LineChart(
      LineChartData(
        minY: 0, maxY: 105,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 4,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: color.withOpacity(0.05)),
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildSubjectIntelligencePlot(List<ExamGroup> groups, Color color) {
    const itemColor = Color(0xFF2B262C);
    Set<String> allSubjects = {};
    for (var r in historyRecords) {
      allSubjects.add(r.getStringValue('subject'));
    }

    final subjectColors = {
      'Math': Colors.blue.shade700,
      'Physics': Colors.orange.shade800,
      'Chemistry': Colors.teal.shade700,
      'English': Colors.amber.shade800,
      'History': Colors.pink.shade700,
      'Biology': Colors.green.shade700,
      'Urdu': Colors.red.shade700,
      'Islamiat': Colors.purple.shade700,
    };
    
    final fallbackColors = [Colors.brown, Colors.cyan, Colors.indigo, Colors.lime];
    int fallbackIdx = 0;

    if (groups.length < 2) {
      final latestGroup = groups.firstOrNull;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: itemColor.withValues(alpha: 0.1))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Subject Performance Breakdown (${latestGroup?.displayName ?? 'Latest'})", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: itemColor)),
            const SizedBox(height: 15),
            Expanded(
              child: ListView(
                children: allSubjects.map((sub) {
                  final match = latestGroup?.records.where((r) => r.getStringValue('subject') == sub).firstOrNull;
                  double marks = match?.getDoubleValue('marks') ?? 0;
                  double total = match?.getDoubleValue('totalMarks') ?? 100;
                  if (total == 0) total = 100;
                  double perc = (marks / total) * 100;
                  Color c = subjectColors[sub] ?? fallbackColors[fallbackIdx++ % fallbackColors.length];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: itemColor.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withValues(alpha: 0.3))),
                    child: Row(
                      children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sub, style: TextStyle(fontWeight: FontWeight.bold, color: itemColor, fontSize: 14)),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(value: perc / 100, backgroundColor: c.withValues(alpha: 0.1), color: c, minHeight: 6),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("${marks.toInt()} / ${total.toInt()}", style: TextStyle(fontWeight: FontWeight.bold, color: itemColor, fontSize: 13)),
                            Text("${perc.toStringAsFixed(1)}%", style: TextStyle(fontWeight: FontWeight.w900, color: c, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: itemColor.withValues(alpha: 0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Each subject plotted as its own line from start to end.", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: itemColor)),
          const SizedBox(height: 15),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: allSubjects.map((sub) {
              Color c = subjectColors[sub] ?? fallbackColors[fallbackIdx++ % fallbackColors.length];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(sub, style: TextStyle(color: itemColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0, maxY: 105,
                lineTouchData: const LineTouchData(enabled: false),
                gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20, getDrawingHorizontalLine: (value) => FlLine(color: itemColor.withValues(alpha: 0.08), strokeWidth: 1)),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, _) {
                    int idx = val.toInt();
                    if (idx >= 0 && idx < groups.length) return Padding(padding: const EdgeInsets.only(top: 10), child: Text("G${groups[idx].grade}", style: TextStyle(color: itemColor.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.bold)));
                    return const Text('');
                  })),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 20, getTitlesWidget: (val, _) => Text(val.toInt().toString(), style: TextStyle(color: itemColor.withValues(alpha: 0.7), fontSize: 10)))),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: allSubjects.map((sub) {
                  List<FlSpot> spots = [];
                  for (int i = 0; i < groups.length; i++) {
                    final match = groups[i].records.where((r) => r.getStringValue('subject') == sub).firstOrNull;
                    if (match != null) {
                       double perc = (match.getDoubleValue('marks') / match.getDoubleValue('totalMarks')) * 100;
                       spots.add(FlSpot(i.toDouble(), perc));
                    }
                  }
                  Color c = subjectColors[sub] ?? itemColor;
                  return LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: c,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 5,
                        color: c,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMachineSummary(String title, String body, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.auto_awesome, size: 14, color: color.withOpacity(0.6)),
            const SizedBox(width: 8),
            Text("$title Summary", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: color.withOpacity(0.6))),
          ]),
          const SizedBox(height: 8),
          Text(body, style: GoogleFonts.inter(fontSize: 12, height: 1.5, color: color.withOpacity(0.8))),
        ],
      ),
    );
  }

  void _showSpreadsheet(ExamGroup group, ExamGroup? prev, {bool hideComparison = false}) {
    bool showComparison = !hideComparison && prev != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF5F1E8),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(padding: const EdgeInsets.all(20), child: Text("Actual Data: ${group.displayName}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: DataTable(
                    columns: [
                      const DataColumn(label: Text('Subject')),
                      const DataColumn(label: Text('Obt/Total')),
                      const DataColumn(label: Text('%')),
                      if (showComparison) const DataColumn(label: Text('vs Prev')),
                    ],
                    rows: group.records.map((r) {
                      double m = r.getDoubleValue('marks');
                      double t = r.getDoubleValue('totalMarks');
                      double p = (m / t) * 100;
                      
                      String sub = r.getStringValue('subject');
                      double? prevP;
                      if (showComparison) {
                         final pRec = prev!.records.where((pr) => pr.getStringValue('subject') == sub).firstOrNull;
                         if (pRec != null) prevP = (pRec.getDoubleValue('marks') / pRec.getDoubleValue('totalMarks')) * 100;
                      }
                      double diff = prevP != null ? p - prevP : 0;

                      return DataRow(cells: [
                        DataCell(Text(sub, style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text("${m.toInt()}/${t.toInt()}")),
                        DataCell(Text("${p.toStringAsFixed(1)}%")),
                        if (showComparison)
                          DataCell(prevP != null ? Row(children: [
                            Icon(diff >= 0 ? Icons.arrow_upward : Icons.arrow_downward, size: 10, color: diff >= 0 ? Colors.green : Colors.red),
                            Text("${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(0)}%", style: TextStyle(fontSize: 10, color: diff >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                          ]) : const Text("-", style: TextStyle(color: Colors.grey))),
                      ]);
                    }).toList()..add(DataRow(cells: [
                       const DataCell(Text("GRAND TOTAL", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.blue))),
                       DataCell(Text("${group.records.fold(0.0, (a, b) => a + b.getDoubleValue('marks')).toInt()}/${group.records.fold(0.0, (a, b) => a + b.getDoubleValue('totalMarks')).toInt()}", style: const TextStyle(fontWeight: FontWeight.bold))),
                       DataCell(Text("${group.calculateAverage().toStringAsFixed(1)}%", style: const TextStyle(fontWeight: FontWeight.bold))),
                       if (showComparison) const DataCell(Text("")),
                    ])),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExamGroup {
  final String key;
  final List<RecordModel> records;
  ExamGroup({required this.key, required this.records});

  String get grade => records.first.getStringValue('grade');
  String get term => records.first.getStringValue('term');
  String get test => records.first.getStringValue('test');
  String get displayName => "Grade $grade - $term ($test)";

  double calculateAverage() {
    double obt = records.fold(0.0, (sum, item) => sum + item.getDoubleValue('marks'));
    double tot = records.fold(0.0, (sum, item) => sum + item.getDoubleValue('totalMarks'));
    return tot > 0 ? (obt / tot) * 100 : 0;
  }
}

enum AnomalyType { trend, attendance, subjectGap }

class Anomaly {
  final String title;
  final String description;
  final String severity; // critical, warning, notable
  final AnomalyType type;
  final String explanation;
  Anomaly({required this.title, required this.description, required this.severity, required this.type, required this.explanation});
}
