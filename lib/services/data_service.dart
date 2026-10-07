import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';

class OfflineSyncManager {
  static final OfflineSyncManager _instance = OfflineSyncManager._internal();
  factory OfflineSyncManager() => _instance;
  OfflineSyncManager._internal();

  static const String _queueKey = 'pending_offline_mutations';
  static const String _cachePrefix = 'cache_';

  Future<void> cacheData(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachePrefix + key, jsonEncode(data));
    } catch (_) {}
  }

  Future<dynamic> getCachedData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? val = prefs.getString(_cachePrefix + key);
      if (val != null) return jsonDecode(val);
    } catch (_) {}
    return null;
  }

  Future<void> queueMutation(String action, Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> queue = prefs.getStringList(_queueKey) ?? [];
      queue.add(jsonEncode({'action': action, 'payload': payload, 'timestamp': DateTime.now().toIso8601String()}));
      await prefs.setStringList(_queueKey, queue);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getPendingQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> queue = prefs.getStringList(_queueKey) ?? [];
      return queue.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clearQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_queueKey);
    } catch (_) {}
  }
}

class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal() {
    syncPendingMutations();
  }

  final PocketBase _pb = PBService().client;

  Future<void> syncPendingMutations() async {
    try {
      final queue = await OfflineSyncManager().getPendingQueue();
      if (queue.isEmpty) return;

      for (var item in queue) {
        String action = item['action'];
        var payload = item['payload'];
        if (action == 'submit_results') {
          await submitResults(
            grade: payload['grade'],
            section: payload['section'],
            subject: payload['subject'],
            term: payload['term'],
            test: payload['test'],
            results: List<Map<String, dynamic>>.from(payload['results']),
            totalMarks: payload['totalMarks'],
            passPercentage: payload['passPercentage'],
          );
        } else if (action == 'request_edit') {
          await requestEdit(
            grade: payload['grade'],
            section: payload['section'],
            subject: payload['subject'],
            term: payload['term'],
            test: payload['test'],
            reason: payload['reason'],
            teacherName: payload['teacherName'],
          );
        } else if (action == 'request_teacher_id') {
          await requestTeacherId(
            name: payload['name'],
            email: payload['email'],
            password: payload['password'],
            role: payload['role'] ?? 'teacher',
            schoolName: payload['school_name'] ?? '',
            schoolId: payload['school_id'] ?? '',
          );
        }
      }
      await OfflineSyncManager().clearQueue();
    } catch (_) {}
  }

  Future<String?> getCurrentUserRole() async {
    try {
      final uid = _pb.authStore.model?.id;
      if (uid == null) {
        final secureStorage = const FlutterSecureStorage();
        return await secureStorage.read(key: 'offline_role');
      }
      final record = await _pb.collection('rm_profiles').getOne(uid);
      return record.getStringValue('role');
    } catch (e) {
      try {
        final secureStorage = const FlutterSecureStorage();
        return await secureStorage.read(key: 'offline_role');
      } catch (_) {
        return null;
      }
    }
  }

  Future<Map<String, String>> getCurrentUserSchoolInfo() async {
    try {
      final uid = _pb.authStore.model?.id;
      if (uid == null) {
        final secureStorage = const FlutterSecureStorage();
        String schoolId = await secureStorage.read(key: 'offline_school_id') ?? '';
        String schoolName = await secureStorage.read(key: 'offline_school_name') ?? '';
        return {'school_id': schoolId, 'school_name': schoolName};
      }
      final record = await _pb.collection('rm_profiles').getOne(uid);
      return {
        'school_id': record.getStringValue('school_id'),
        'school_name': record.getStringValue('school_name'),
      };
    } catch (e) {
      try {
        final secureStorage = const FlutterSecureStorage();
        String schoolId = await secureStorage.read(key: 'offline_school_id') ?? '';
        String schoolName = await secureStorage.read(key: 'offline_school_name') ?? '';
        return {'school_id': schoolId, 'school_name': schoolName};
      } catch (_) {
        return {'school_id': '', 'school_name': ''};
      }
    }
  }

  // --- Student Management ---
  Future<List<Map<String, String>>> getStudents(String grade, String section) async {
    String cacheKey = 'students_${grade}_$section';
    try {
      final schoolInfo = await getCurrentUserSchoolInfo();
      String schoolId = schoolInfo['school_id'] ?? '';
      String schoolFilter = schoolId.isNotEmpty ? ' && school_id = "$schoolId"' : '';

      // If section is 'None', we search for records where section is 'None' OR empty
      String secFilter = section == 'None' ? '(section = "None" || section = "")' : 'section = "$section"';
      final records = await _pb.collection('rm_students').getFullList(
        filter: 'grade = "$grade" && $secFilter$schoolFilter',
        expand: 'Category,category', // Try both cases for expansion
      );
      
      List<Map<String, String>> resultList = records.map((doc) {
        // Try to get category name from expanded relation (check both cases)
        String catName = doc.getStringValue('Category');
        if (catName.isEmpty) catName = doc.getStringValue('category');

        final expanded = doc.expand['Category']?.firstOrNull ?? doc.expand['category']?.firstOrNull;
        if (expanded != null) {
          // Try common name fields
          catName = expanded.getStringValue('name').isNotEmpty 
              ? expanded.getStringValue('name') 
              : expanded.getStringValue('title').isNotEmpty 
                  ? expanded.getStringValue('title')
                  : expanded.getStringValue('Category'); // Maybe the field in category collection is also named Category
        }

        String batchVal = '2025';
        try {
          batchVal = doc.getStringValue('batch');
          if (batchVal.isEmpty) batchVal = doc.getStringValue('batch_year');
        } catch (_) {}
        if (batchVal.isEmpty) batchVal = '2025';

        return {
          'pb_id': doc.id,
          'name': doc.getStringValue('name'),
          'father_name': doc.getStringValue('FatherName'),
          'role_no': doc.getStringValue('RoleNo'),
          'category': catName.isEmpty ? doc.getStringValue('category') : catName,
          'student_id': doc.getStringValue('student_id'),
          'batch': batchVal,
        };
      }).toList();

      await OfflineSyncManager().cacheData(cacheKey, resultList);
      return resultList;
    } catch (e) {
      // Fallback to local cache if offline
      final cached = await OfflineSyncManager().getCachedData(cacheKey);
      if (cached != null) {
        return (cached as List).map((e) => Map<String, String>.from(e)).toList();
      }
      return [];
    }
  }

  Future<void> addStudent({
    required String name, 
    required String fatherName,
    required String roleNo,
    required String grade, 
    required String section, 
    String? category,
    String? batch,
  }) async {
    final schoolInfo = await getCurrentUserSchoolInfo();
    final schoolId = schoolInfo['school_id'] ?? '';
    final schoolName = schoolInfo['school_name'] ?? '';

    try {
      await _pb.collection('rm_students').create(body: {
        'name': name,
        'FatherName': fatherName,
        'RoleNo': roleNo,
        'grade': grade,
        'section': section,
        'Category': category ?? '',
        'batch': batch ?? '2025',
        'school_id': schoolId,
        'school_name': schoolName,
      });
    } catch (e) {
      // Fallback if 'batch' field doesn't exist in PocketBase schema yet
      await _pb.collection('rm_students').create(body: {
        'name': name,
        'FatherName': fatherName,
        'RoleNo': roleNo,
        'grade': grade,
        'section': section,
        'Category': category ?? '',
        'school_id': schoolId,
        'school_name': schoolName,
      });
    }
  }

  Future<void> batchAddStudents({
    required List<Map<String, String>> students, 
    required String grade, 
    required String section,
    String? batch,
  }) async {
    final schoolInfo = await getCurrentUserSchoolInfo();
    final schoolId = schoolInfo['school_id'] ?? '';
    final schoolName = schoolInfo['school_name'] ?? '';

    for (var s in students) {
      try {
        await _pb.collection('rm_students').create(body: {
          'name': s['name'] ?? '',
          'FatherName': s['father_name'] ?? '',
          'RoleNo': s['role_no'] ?? '',
          'Category': s['category'] ?? '',
          'grade': grade,
          'section': section,
          'batch': batch ?? s['batch'] ?? '2025',
          'school_id': schoolId,
          'school_name': schoolName,
        });
      } catch (e) {
        try {
          await _pb.collection('rm_students').create(body: {
            'name': s['name'] ?? '',
            'FatherName': s['father_name'] ?? '',
            'RoleNo': s['role_no'] ?? '',
            'Category': s['category'] ?? '',
            'grade': grade,
            'section': section,
            'school_id': schoolId,
            'school_name': schoolName,
          });
        } catch (innerE) {
          print("Batch error: $innerE");
        }
      }
    }
  }

  Future<void> updateStudent(String pbId, String newName) async {
    await _pb.collection('rm_students').update(pbId, body: {'name': newName});
  }

  Future<String?> assignBatchToClass({
    required String grade,
    required String section,
    required String batch,
  }) async {
    try {
      final students = await getStudents(grade, section);
      if (students.isEmpty) return 'No students found in Grade $grade (Sec: $section)';
      
      int successCount = 0;
      String? lastError;

      for (var s in students) {
        String pbId = s['pb_id'] ?? '';
        if (pbId.isNotEmpty) {
          try {
            await _pb.collection('rm_students').update(pbId, body: {
              'batch': batch,
            });
            successCount++;
          } catch (e) {
            try {
              await _pb.collection('rm_students').update(pbId, body: {
                'batch_year': batch,
              });
              successCount++;
            } catch (innerE) {
              lastError = innerE.toString();
            }
          }
        }
      }
      if (successCount == 0 && lastError != null) {
        return 'Backend schema error: Make sure the "batch" text field is created in your PocketBase rm_students collection. ($lastError)';
      }
      return null;
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<String> assignCategoryToClassAndResults({
    required String grade,
    required String section,
    required String category,
  }) async {
    try {
      final schoolInfo = await getCurrentUserSchoolInfo();
      String schoolId = schoolInfo['school_id'] ?? '';
      String schoolFilter = schoolId.isNotEmpty ? ' && school_id = "$schoolId"' : '';

      String secFilter = section == 'None' ? '(section = "None" || section = "")' : 'section = "$section"';
      
      // 1. Update Students in rm_students
      final students = await _pb.collection('rm_students').getFullList(
        filter: 'grade = "$grade" && $secFilter$schoolFilter',
      );
      int studentCount = 0;
      for (var s in students) {
        try {
          await _pb.collection('rm_students').update(s.id, body: {
            'Category': category,
            'category': category,
          });
          studentCount++;
        } catch (_) {}
      }

      // 2. Update Results in rm_student_result
      final results = await _pb.collection('rm_student_result').getFullList(
        filter: 'grade = "$grade" && $secFilter$schoolFilter',
      );
      int resultCount = 0;
      for (var r in results) {
        try {
          await _pb.collection('rm_student_result').update(r.id, body: {
            'Category': category,
            'category': category,
          });
          resultCount++;
        } catch (_) {}
      }

      return 'Updated category "$category" for $studentCount students and $resultCount result records!';
    } catch (e) {
      return 'Error updating category: $e';
    }
  }

  // --- Results Management ---
  Future<void> submitResults({
    required String grade,
    required String section,
    required String subject,
    required String term,
    required String test,
    required List<Map<String, dynamic>> results,
    required double totalMarks,
    required String passPercentage,
  }) async {
    try {
      final schoolInfo = await getCurrentUserSchoolInfo();
      final schoolId = schoolInfo['school_id'] ?? '';
      final schoolName = schoolInfo['school_name'] ?? '';
      final teacherId = _pb.authStore.model?.id ?? '';
      final teacherName = _pb.authStore.model?.getStringValue('name') ?? _pb.authStore.model?.getStringValue('email') ?? 'Teacher';

      for (var result in results) {
        try {
          // Use student_id column to store/match the machine-assigned PocketBase ID
          String studentPbId = result['id'] ?? '';
          
          List<RecordModel> existingRecords = [];
          
          // Priority 1: Match by the unique machine ID in student_id column
          if (studentPbId.isNotEmpty) {
            try {
              String filter = 'student_id = "$studentPbId" && grade = "$grade" && section = "$section" && subject = "$subject" && term = "$term" && test = "$test"';
              final list = await _pb.collection('rm_student_result').getList(page: 1, perPage: 1, filter: filter);
              existingRecords = list.items;
            } catch (e) {
               print("Filter error (likely student_id field missing): $e");
            }
          }

          // Priority 2: Fallback to name-based matching for legacy records
          if (existingRecords.isEmpty) {
            String fallbackFilter = 'studentName = "${result['name']}" && grade = "$grade" && section = "$section" && subject = "$subject" && term = "$term" && test = "$test"';
            final list = await _pb.collection('rm_student_result').getList(page: 1, perPage: 1, filter: fallbackFilter);
            existingRecords = list.items;
          }

          final body = {
            'studentName': result['name'],
            'grade': grade,
            'section': section,
            'subject': subject,
            'term': term,
            'test': test,
            'marks': double.tryParse(result['marks'].toString()) ?? 0.0,
            'totalMarks': totalMarks,
            'passPercentage': passPercentage,
            'student_id': studentPbId, // Machine ID stored in student_id column
            'RoleNo': result['role_no'] ?? '',
            'FatherName': result['father_name'] ?? '',
            'batch': result['batch'] ?? '2025',
            'school_id': schoolId,
            'school_name': schoolName,
            'teacher_id': teacherId,
            'teacher_name': teacherName,
          };

          try {
            if (existingRecords.isNotEmpty) {
              await _pb.collection('rm_student_result').update(existingRecords.first.id, body: {
                ...body,
                'isEdited': true,
              });
            } else {
              await _pb.collection('rm_student_result').create(body: {
                ...body,
                'isEdited': false,
              });
            }
          } catch (schemaErr) {
            // Fallback if 'batch' field doesn't exist in rm_student_result schema yet
            body.remove('batch');
            if (existingRecords.isNotEmpty) {
              await _pb.collection('rm_student_result').update(existingRecords.first.id, body: {
                ...body,
                'isEdited': true,
              });
            } else {
              await _pb.collection('rm_student_result').create(body: {
                ...body,
                'isEdited': false,
              });
            }
          }
        } catch (e) { 
          print("Save Error for ${result['name']}: $e"); 
          // Fallback to minimal fields if schema mismatch occurs
          try {
             await _pb.collection('rm_student_result').create(body: {
              'studentName': result['name'],
              'grade': grade,
              'section': section,
              'subject': subject,
              'term': term,
              'test': test,
              'marks': double.tryParse(result['marks'].toString()) ?? 0.0,
              'totalMarks': totalMarks,
            });
          } catch (_) {}
        }
      }

      try {
        final request = await _pb.collection('rm_edit_requests').getFirstListItem('grade="$grade" && section="$section" && subject="$subject" && term="$term" && test="$test" && status="approved"');
        await _pb.collection('rm_edit_requests').update(request.id, body: {'status': 'completed'});
      } catch (e) {}
    } catch (e) {
      // Offline queue fallback
      await OfflineSyncManager().queueMutation('submit_results', {
        'grade': grade,
        'section': section,
        'subject': subject,
        'term': term,
        'test': test,
        'results': results,
        'totalMarks': totalMarks,
        'passPercentage': passPercentage,
      });
      rethrow;
    }
  }

  // --- Edit Requests ---
  Future<void> requestEdit({required String grade, required String section, required String subject, required String term, required String test, required String reason, required String teacherName}) async {
    try {
      await _pb.collection('rm_edit_requests').create(body: {
        'grade': grade, 'section': section, 'subject': subject, 'term': term, 'test': test, 'reason': reason, 'teacherName': teacherName, 'status': 'pending',
      });
    } catch (e) {
      await OfflineSyncManager().queueMutation('request_edit', {
        'grade': grade,
        'section': section,
        'subject': subject,
        'term': term,
        'test': test,
        'reason': reason,
        'teacherName': teacherName,
      });
      rethrow;
    }
  }

  Future<List<RecordModel>> getEditRequests() async => await _pb.collection('rm_edit_requests').getFullList(filter: 'status = "pending"', sort: '-created');
  Future<void> approveEditRequest(String id) async => await _pb.collection('rm_edit_requests').update(id, body: {'status': 'approved'});
  Future<void> rejectEditRequest(String id) async => await _pb.collection('rm_edit_requests').update(id, body: {'status': 'rejected'});

  Future<bool> isEditAllowed(String grade, String section, String subject, String term, String test) async {
    try {
      final record = await _pb.collection('rm_edit_requests').getFirstListItem('grade="$grade" && section="$section" && subject="$subject" && term="$term" && test="$test" && status="approved"');
      return record != null;
    } catch (e) { return false; }
  }

  // --- Staff (Teacher / Principal) ID Requests & Approvals ---
  Future<void> requestTeacherId({
    required String name, 
    required String email, 
    required String password, 
    required String role,
    required String schoolName,
    required String schoolId,
  }) async {
    await _pb.collection('rm_teachers_requests').create(body: {
      'name': name, 
      'email': email, 
      'password': password, 
      'role': role, 
      'school_name': schoolName,
      'school_id': schoolId,
      'status': 'pending',
    });
  }

  Future<List<RecordModel>> getTeacherRequests() async {
    try {
      return await _pb.collection('rm_teachers_requests').getFullList(filter: 'status = "pending"', sort: '-created');
    } catch (e) {
      return [];
    }
  }

  Future<void> approveTeacherRequest(String id, String email, String password, String name, String role, String schoolName, String schoolId) async {
    if (role.isEmpty || role == 'N/A') role = 'teacher';
    String uname = email;
    
    await _pb.collection('rm_profiles').create(body: {
      'username': uname,
      'email': email,
      'name': name,
      'role': role.toLowerCase(),
      'school_name': schoolName,
      'school_id': schoolId,
      'password': password,
      'passwordConfirm': password,
      'emailVisibility': true,
    });
    
    await _pb.collection('rm_teachers_requests').update(id, body: {'status': 'approved'});
  }

  Future<void> rejectTeacherRequest(String id) async {
    try {
      await _pb.collection('rm_teachers_requests').update(id, body: {'status': 'rejected'});
    } catch (_) {}
  }

  // --- Principal ID Requests & Approvals (for Master Admin) ---
  Future<void> requestPrincipalId({
    required String name,
    required String email,
    required String password,
    required String schoolName,
    required String schoolId,
    required String role,
  }) async {
    await _pb.collection('rm_principal_requests').create(body: {
      'name': name,
      'namr': name,
      'email': email,
      'password': password,
      'school_name': schoolName,
      'school_id': schoolId,
      'role': role,
      'status': 'pending',
    });
  }

  Future<List<RecordModel>> getPrincipalRequests() async {
    try {
      return await _pb.collection('rm_principal_requests').getFullList(filter: 'status = "pending"', sort: '-created');
    } catch (e) {
      return [];
    }
  }

  Future<void> approvePrincipalRequest(String id, String email, String password, String name, String schoolName, String schoolId, String role) async {
    if (role.isEmpty || role == 'N/A') role = 'principal';
    String uname = email;

    await _pb.collection('rm_profiles').create(body: {
      'username': uname,
      'email': email,
      'name': name,
      'role': role.toLowerCase(),
      'school_name': schoolName,
      'school_id': schoolId,
      'password': password,
      'passwordConfirm': password,
      'emailVisibility': true,
    });

    await _pb.collection('rm_principal_requests').update(id, body: {'status': 'approved'});
  }

  Future<void> rejectPrincipalRequest(String id) async {
    try {
      await _pb.collection('rm_principal_requests').update(id, body: {'status': 'rejected'});
    } catch (_) {}
  }

  // --- Batch Helpers ---
  Future<List<String>> getBatches() async {
    try {
      final records = await _pb.collection('rm_students').getFullList();
      Set<String> batches = {};
      for (var doc in records) {
        String b = doc.getStringValue('batch');
        if (b.isEmpty) b = doc.getStringValue('batch_year');
        if (b.isNotEmpty) batches.add(b);
      }
      List<String> list = batches.toList()..sort((a, b) => b.compareTo(a));
      return list.isEmpty ? ['2025'] : list;
    } catch (e) {
      return ['2025'];
    }
  }

  Future<List<Map<String, String>>> getStudentsByBatch(String batch) async {
    try {
      final records = await _pb.collection('rm_students').getFullList(
        filter: 'batch = "$batch" || batch_year = "$batch"',
        expand: 'Category,category',
      );
      
      return records.map((doc) {
        String catName = doc.getStringValue('Category');
        if (catName.isEmpty) catName = doc.getStringValue('category');

        final expanded = doc.expand['Category']?.firstOrNull ?? doc.expand['category']?.firstOrNull;
        if (expanded != null) {
          catName = expanded.getStringValue('name').isNotEmpty 
              ? expanded.getStringValue('name') 
              : expanded.getStringValue('title').isNotEmpty 
                  ? expanded.getStringValue('title')
                  : expanded.getStringValue('Category');
        }

        String batchVal = doc.getStringValue('batch');
        if (batchVal.isEmpty) batchVal = doc.getStringValue('batch_year');

        return {
          'pb_id': doc.id,
          'name': doc.getStringValue('name'),
          'father_name': doc.getStringValue('FatherName'),
          'role_no': doc.getStringValue('RoleNo'),
          'category': catName.isEmpty ? doc.getStringValue('category') : catName,
          'student_id': doc.getStringValue('student_id'),
          'grade': doc.getStringValue('grade'),
          'section': doc.getStringValue('section'),
          'batch': batchVal.isNotEmpty ? batchVal : '2025',
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> promoteBatch({
    required String batch,
    required String nextGrade,
  }) async {
    final students = await getStudentsByBatch(batch);
    for (var s in students) {
      String pbId = s['pb_id'] ?? '';
      if (pbId.isNotEmpty) {
        try {
          await _pb.collection('rm_students').update(pbId, body: {
            'grade': nextGrade,
          });
        } catch (e) {
          print("Batch promotion error for $pbId: $e");
        }
      }
    }
  }

  // --- Helpers ---
  Future<List<RecordModel>> getAllResults() async => await _pb.collection('rm_student_result').getFullList(sort: '-created');
  
  Future<List<RecordModel>> getClassResults({
    required String grade,
    required String section,
    required String term,
    required String test,
  }) async {
    try {
      // Normalize term for query
      String termFilter;
      if (term == 'Final Term' || term == 'Final') {
        termFilter = '(term = "Final Term" || term = "Final")';
      } else if (term == 'Term 2' || term == '2nd Term') {
        termFilter = '(term = "Term 2" || term = "2nd Term")';
      } else if (term == 'Term 1' || term == '1st Term') {
        termFilter = '(term = "Term 1" || term = "1st Term")';
      } else {
        termFilter = 'term = "$term"';
      }

      String testFilter = (test == 'Final' || test == 'Final Term')
          ? '(test = "Final" || test = "Final Term")'
          : 'test = "$test"';
      
      String secFilter = (section == 'None' || section == '') 
          ? '(section = "None" || section = "")' 
          : 'section = "$section"';

      return await _pb.collection('rm_student_result').getFullList(
        filter: 'grade = "$grade" && $secFilter && $termFilter && $testFilter',
      );
    } catch (e) {
      return [];
    }
  }

  // --- Student History & Promotion ---
  Future<List<RecordModel>> getStudentHistory(String studentPbID, String studentName) async {
    try {
      if (studentPbID.isEmpty && studentName.isEmpty) return [];

      // Priority 1: Fetch by the machine-assigned student ID (student_id column in results)
      if (studentPbID.isNotEmpty) {
        return await _pb.collection('rm_student_result').getFullList(
          filter: 'student_id = "$studentPbID"',
          sort: 'grade,created', // Sort by grade then chronological order
        );
      }
      
      // Priority 2: Fallback to name-based history for legacy records
      return await _pb.collection('rm_student_result').getFullList(
        filter: 'studentName = "$studentName"',
        sort: 'grade,created',
      );
    } catch (e) {
      return [];
    }
  }

  Future<void> promoteStudents({
    required List<String> studentPbIds,
    required String nextGrade,
  }) async {
    for (var id in studentPbIds) {
      try {
        await _pb.collection('rm_students').update(id, body: {
          'grade': nextGrade,
        });
      } catch (e) {
        print("Promotion error for $id: $e");
      }
    }
  }

  Future<List<Map<String, dynamic>>> getRecentSubmissions() async {
    try {
      final query = await _pb.collection('rm_student_result').getList(page: 1, perPage: 20, sort: '-created');
      Map<String, Map<String, dynamic>> unique = {};
      for (var item in query.items) {
        final data = item.data;
        String batch = data['batch']?.toString() ?? '';
        if (batch.isEmpty) batch = '2025';
        String key = '${batch}_${data['grade']}${data['section']}_${data['term']}_${data['test']}_${data['subject']}';
        unique.putIfAbsent(key, () => {
          ...data,
          'batch': batch,
        });
      }
      return unique.values.toList();
    } catch (e) { return []; }
  }

  // --- Migration Fixes ---
  Future<String?> assignBatchToClassResults({
    required String grade,
    required String section,
    required String batch,
  }) async {
    try {
      String secFilter = (section == 'None' || section == '') 
          ? '(section = "None" || section = "")' 
          : 'section = "$section"';
      
      final records = await _pb.collection('rm_student_result').getFullList(
        filter: 'grade = "$grade" && $secFilter',
      );

      if (records.isEmpty) {
        return 'No result records found for Grade $grade (Sec: $section)';
      }

      for (var rec in records) {
        try {
          await _pb.collection('rm_student_result').update(rec.id, body: {
            'batch': batch,
          });
        } catch (e) {
          print("Error updating result record ${rec.id}: $e");
        }
      }

      return null;
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<int> fixGrade7And8Terms() async {
    int count = 0;
    try {
      final records = await _pb.collection('rm_student_result').getFullList(
        filter: '(grade = "7" && (section = "A" || section = "B") && term = "2nd Term") || (grade = "8" && term = "2nd Term")',
      );
      
      for (var record in records) {
        await _pb.collection('rm_student_result').update(record.id, body: {
          'term': 'Final Term',
        });
        count++;
      }
    } catch (e) {
      print("Fix Error: $e");
    }
    return count;
  }

  Future<void> submitAttendance(List<Map<String, dynamic>> records) async {
    for (var r in records) {
      try {
        String name = r['name'];
        String fName = r['father_name'];
        String monthYear = r['month_year'];

        var existing = await _pb.collection('rm_attendance').getList(
          filter: 'name = "$name" && father_name = "$fName" && month_year = "$monthYear"',
        );

        final body = {
          'name': name,
          'father_name': fName,
          'percentage': r['percentage'],
          'month_year': monthYear,
        };

        if (existing.items.isNotEmpty) {
          await _pb.collection('rm_attendance').update(existing.items.first.id, body: body);
        } else {
          await _pb.collection('rm_attendance').create(body: body);
        }
      } catch (e) {
        print("Attendance submit error: $e");
        try {
          await _pb.collection('rm_attendance').create(body: {
            'name': r['name'],
            'percentage': r['percentage'],
          });
        } catch (_) {}
      }
    }
  }

  Future<List<RecordModel>> getStudentAttendance(String studentName, String fatherName) async {
    try {
      if (studentName.isEmpty) return [];
      String filter = fatherName.isNotEmpty 
          ? 'name = "$studentName" && father_name = "$fatherName"' 
          : 'name = "$studentName"';
      return await _pb.collection('rm_attendance').getFullList(filter: filter, sort: '-month_year');
    } catch (e) {
      return [];
    }
  }

  // --- Data Migration for School 0667 ---
  Future<String> migrateExistingDataToSchool0667({
    required String schoolId,
    required String schoolName,
  }) async {
    int updatedCount = 0;
    try {
      print("Starting migration to school $schoolId...");
      
      // 1. Migrate rm_students
      final students = await _pb.collection('rm_students').getFullList();
      print("Found ${students.length} students to check.");
      for (var s in students) {
        String existingId = s.getStringValue('school_id');
        if (existingId.isEmpty) {
          try {
            await _pb.collection('rm_students').update(s.id, body: {
              'school_id': schoolId,
              'school_name': schoolName,
            });
            updatedCount++;
          } catch (e) {
            print("Error updating student ${s.id}: $e");
          }
        }
      }

      // 2. Migrate rm_student_result
      final results = await _pb.collection('rm_student_result').getFullList();
      print("Found ${results.length} results to check.");
      for (var r in results) {
        String existingId = r.getStringValue('school_id');
        if (existingId.isEmpty) {
          try {
            await _pb.collection('rm_student_result').update(r.id, body: {
              'school_id': schoolId,
              'school_name': schoolName,
            });
            updatedCount++;
          } catch (e) {
            print("Error updating result ${r.id}: $e");
          }
        }
      }

      // 3. Migrate rm_profiles
      final profiles = await _pb.collection('rm_profiles').getFullList();
      print("Found ${profiles.length} profiles to check.");
      for (var p in profiles) {
        String existingId = p.getStringValue('school_id');
        if (existingId.isEmpty) {
          try {
            await _pb.collection('rm_profiles').update(p.id, body: {
              'school_id': schoolId,
              'school_name': schoolName,
            });
            updatedCount++;
          } catch (e) {
            print("Error updating profile ${p.id}: $e");
          }
        }
      }

      // 4. Migrate rm_attendance
      final attendances = await _pb.collection('rm_attendance').getFullList();
      print("Found ${attendances.length} attendance records to check.");
      for (var a in attendances) {
        String existingId = a.getStringValue('school_id');
        if (existingId.isEmpty) {
          try {
            await _pb.collection('rm_attendance').update(a.id, body: {
              'school_id': schoolId,
              'school_name': schoolName,
            });
            updatedCount++;
          } catch (e) {
            print("Error updating attendance ${a.id}: $e");
          }
        }
      }

      print("Migration completed successfully! Total updated: $updatedCount");
      return 'Successfully migrated $updatedCount records to school $schoolId ($schoolName)';
    } catch (e) {
      print("Migration fatal error: $e");
      return 'Migration error: $e';
    }
  }

  // --- App Version & Update Checker ---
  Future<Map<String, dynamic>?> checkForUpdates() async {
    try {
      final records = await _pb.collection('rm_app_version').getFullList(sort: '-version_code');
      if (records.isNotEmpty) {
        final latest = records.first;
        int serverCode = latest.getIntValue('version_code');
        String serverName = latest.getStringValue('version_name');
        String downloadUrl = latest.getStringValue('download_url');

        // Local version code (matches 1.0.0+1 -> version_code = 1)
        int localCode = 1;

        if (serverCode > localCode) {
          return {
            'version_name': serverName,
            'version_code': serverCode,
            'download_url': downloadUrl,
          };
        }
      }
    } catch (e) {
      print("Update check error: $e");
    }
    return null;
  }
}
