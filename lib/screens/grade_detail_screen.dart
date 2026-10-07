import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/data_service.dart';

class GradeDetailScreen extends StatelessWidget {
  final String grade;
  const GradeDetailScreen({super.key, required this.grade});

  @override
  Widget build(BuildContext context) {
    final DataService dataService = DataService();
    const bgColor = Color(0xFFF5F1E8);
    const itemColor = Color(0xFF2B262C);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Grade $grade Students', 
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: itemColor)),
        backgroundColor: Colors.transparent,
        foregroundColor: itemColor,
        elevation: 0,
      ),
      body: FutureBuilder<List<RecordModel>>(
        future: dataService.getAllResults(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: itemColor));
          }

          final allDocs = snapshot.data ?? [];
          final gradeResults = allDocs.where((doc) {
            return doc.data['grade'] == grade;
          }).toList();

          if (gradeResults.isEmpty) {
            return Center(child: Text('No results uploaded for Grade $grade', 
              style: GoogleFonts.poppins(color: itemColor)));
          }

          Map<String, Map<String, dynamic>> studentData = {};
          for (var doc in gradeResults) {
            final data = doc.data;
            String sid = data['studentId'] ?? '';
            String sname = data['studentName'] ?? 'Unknown';
            
            if (!studentData.containsKey(sid)) {
              studentData[sid] = {
                'name': sname,
                'subjects': <Map<String, dynamic>>[],
              };
            }
            
            (studentData[sid]!['subjects'] as List).add({
              'subject': data['subject'],
              'marks': data['marks'],
              'term': data['term'],
              'test': data['test'],
            });
          }

          final studentIds = studentData.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: studentIds.length,
            itemBuilder: (context, index) {
              String sid = studentIds[index];
              var data = studentData[sid]!;
              List subjects = data['subjects'];

              return Card(
                margin: const EdgeInsets.only(bottom: 15),
                color: Colors.white.withValues(alpha: 0.8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: itemColor.withValues(alpha: 0.1)),
                ),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: itemColor.withValues(alpha: 0.1),
                    child: Text(data['name'][0], style: const TextStyle(color: itemColor)),
                  ),
                  title: Text(data['name'], 
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: itemColor)),
                  subtitle: Text('ID: $sid | ${subjects.length} subjects', 
                    style: GoogleFonts.poppins(fontSize: 12, color: itemColor.withValues(alpha: 0.6))),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        children: subjects.map<Widget>((sub) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(sub['subject'], 
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: itemColor)),
                                    Text('${sub['term']} - ${sub['test']}', 
                                      style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: itemColor.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('${sub['marks']}%', 
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: itemColor)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
