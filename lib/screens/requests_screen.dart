import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/data_service.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  final DataService _dataService = DataService();
  static const itemColor = Color(0xFF2B262C);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Approvals & Requests', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: itemColor,
          elevation: 0,
          bottom: const TabBar(
            labelColor: itemColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: itemColor,
            tabs: [
              Tab(text: 'Edit Requests'),
              Tab(text: 'Teacher ID Requests'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildEditRequestsTab(),
            _buildTeacherRequestsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildEditRequestsTab() {
    return FutureBuilder<List<RecordModel>>(
      future: _dataService.getEditRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: itemColor));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: itemColor)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mark_email_read_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text('No pending edit requests', style: GoogleFonts.poppins(color: Colors.grey)),
              ],
            ),
          );
        }

        final docs = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data;

            return FadeInUp(
              duration: Duration(milliseconds: 200 * (index + 1)),
              child: Card(
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: itemColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Grade ${data['grade']}${data['section']} - ${data['subject']}',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: itemColor),
                            ),
                          ),
                          Text(
                            data['status'].toString().toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('Teacher: ${data['teacherName']}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: itemColor)),
                      Text('Reason: ${data['reason']}', style: GoogleFonts.poppins(fontSize: 13, color: itemColor)),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () async {
                              await _dataService.rejectEditRequest(doc.id);
                              setState(() {});
                            },
                            child: const Text('Reject', style: TextStyle(color: Colors.red)),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () async {
                              await _dataService.approveEditRequest(doc.id);
                              setState(() {});
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Allow Edit'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTeacherRequestsTab() {
    return FutureBuilder<List<RecordModel>>(
      future: _dataService.getTeacherRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: itemColor));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: itemColor)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add_disabled_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text('No pending teacher ID requests', style: GoogleFonts.poppins(color: Colors.grey)),
              ],
            ),
          );
        }

        final docs = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data;

            String name = data['name'] ?? '';
            String email = data['email'] ?? '';
            String password = data['password'] ?? '';
            String role = data['role'] ?? 'teacher';
            String schoolName = data['school_name'] ?? '';
            String schoolId = data['school_id'] ?? '';

            return FadeInUp(
              duration: Duration(milliseconds: 200 * (index + 1)),
              child: Card(
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'New ${role.toUpperCase()} Request',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                            ),
                          ),
                          const Text(
                            'PENDING',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('Name: $name', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: itemColor)),
                      Text('Requested ID / Email: $email', style: GoogleFonts.poppins(fontSize: 13, color: itemColor)),
                      if (schoolName.isNotEmpty)
                        Text('School: $schoolName (ID: $schoolId)', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () async {
                              await _dataService.rejectTeacherRequest(doc.id);
                              setState(() {});
                            },
                            child: const Text('Reject', style: TextStyle(color: Colors.red)),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () async {
                              await _dataService.approveTeacherRequest(doc.id, email, password, name, role, schoolName, schoolId);
                              setState(() {});
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${role.toUpperCase()} account created & approved successfully!')),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Approve & Create ID'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
