import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/data_service.dart';

class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  final DataService _dataService = DataService();
  static const itemColor = Color(0xFF2B262C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Principal ID Requests (Admin)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: itemColor)),
        backgroundColor: Colors.white,
        foregroundColor: itemColor,
        elevation: 0,
      ),
      body: FutureBuilder<List<RecordModel>>(
        future: _dataService.getPrincipalRequests(),
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
                  Icon(Icons.verified_user_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text('No pending principal ID requests', style: GoogleFonts.poppins(color: Colors.grey)),
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

              String name = data['namr'] ?? data['name'] ?? '';
              String email = data['email'] ?? '';
              String password = data['password'] ?? '';
              String schoolName = data['school_name'] ?? '';
              String schoolId = data['school_id'] ?? '';
              String role = data['role']?.toString() ?? 'principal';
              if (role.isEmpty || role == 'N/A') role = 'principal';

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
                                color: Colors.purple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'New Principal Request',
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple.shade800),
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
                        Text('Principal Name: $name', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: itemColor)),
                        Text('Email / ID: $email', style: GoogleFonts.poppins(fontSize: 13, color: itemColor)),
                        Text('School: $schoolName (ID: $schoolId)', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () async {
                                await _dataService.rejectPrincipalRequest(doc.id);
                                setState(() {});
                              },
                              child: const Text('Reject', style: TextStyle(color: Colors.red)),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () async {
                                try {
                                  await _dataService.approvePrincipalRequest(doc.id, email, password, name, schoolName, schoolId, role);
                                  setState(() {});
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Principal account created & approved successfully!')),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Approval Failed'),
                                        content: Text('Error: $e\n\nMake sure fields (role, school_name, school_id) exist in your rm_profiles collection in PocketBase!'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
                                        ],
                                      ),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Approve & Create Principal ID'),
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
      ),
    );
  }
}
