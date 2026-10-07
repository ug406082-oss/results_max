import 'pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';

class AuthService {
  final PocketBase _pb = PBService().client;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Stream of Auth State
  final _authController = StreamController<AuthStoreEvent?>.broadcast();
  Stream<AuthStoreEvent?> get authStream => _authController.stream;

  AuthService() {
    _pb.authStore.onChange.listen((event) {
      _authController.add(event);
    });
  }

  bool get isLoggedIn => _pb.authStore.isValid;
  String? get currentUserId => _pb.authStore.model?.id;

  // Sign in with secure offline cache fallback
  Future<void> signIn(String email, String password) async {
    try {
      final authData = await _pb.collection('rm_profiles').authWithPassword(email, password);
      
      // Save credentials and token securely in secure storage for offline fallback
      await _secureStorage.write(key: 'offline_email', value: email);
      await _secureStorage.write(key: 'offline_password', value: password);
      await _secureStorage.write(key: 'offline_token', value: authData.token);
      await _secureStorage.write(key: 'offline_uid', value: authData.record.id);
      await _secureStorage.write(key: 'offline_role', value: authData.record.getStringValue('role'));
      await _secureStorage.write(key: 'offline_name', value: authData.record.getStringValue('name'));
      await _secureStorage.write(key: 'offline_school_id', value: authData.record.getStringValue('school_id'));
      await _secureStorage.write(key: 'offline_school_name', value: authData.record.getStringValue('school_name'));
    } catch (e) {
      // Offline fallback login check via secure storage
      String? savedEmail = await _secureStorage.read(key: 'offline_email');
      String? savedPassword = await _secureStorage.read(key: 'offline_password');

      if (savedEmail != null && savedEmail.trim().toLowerCase() == email.trim().toLowerCase() && savedPassword == password) {
        String token = await _secureStorage.read(key: 'offline_token') ?? 'offline_mock_token';
        String uid = await _secureStorage.read(key: 'offline_uid') ?? 'offline_uid';
        String role = await _secureStorage.read(key: 'offline_role') ?? 'teacher';
        String name = await _secureStorage.read(key: 'offline_name') ?? 'Offline User';
        String schoolId = await _secureStorage.read(key: 'offline_school_id') ?? '';
        String schoolName = await _secureStorage.read(key: 'offline_school_name') ?? '';

        // Save into PocketBase AuthStore so isValid becomes TRUE and onChange fires!
        _pb.authStore.save(
          token,
          RecordModel({
            'id': uid,
            'collectionId': 'rm_profiles',
            'collectionName': 'rm_profiles',
            'email': email,
            'name': name,
            'role': role,
            'school_id': schoolId,
            'school_name': schoolName,
          }),
        );
        return;
      }
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    _pb.authStore.clear();
  }

  // Get User Role from PocketBase record or secure cache
  Future<String?> getUserRole(String uid) async {
    try {
      final model = _pb.authStore.model;
      if (model is RecordModel) {
        final role = model.getStringValue('role');
        if (role.isNotEmpty) {
          return role.toLowerCase().trim();
        }
      }

      final record = await _pb.collection('rm_profiles').getOne(uid);
      final role = record.getStringValue('role');
      return role.toLowerCase().trim();
    } catch (e) {
      // Fallback to secure cache role
      String? role = await _secureStorage.read(key: 'offline_role');
      return role?.toLowerCase().trim() ?? 'teacher';
    }
  }
}
