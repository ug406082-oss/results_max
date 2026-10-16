import 'pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // Sign in with secure + SharedPreferences dual fallback
  Future<void> signIn(String email, String password) async {
    try {
      final authData = await _pb.collection('rm_profiles').authWithPassword(email, password).timeout(const Duration(seconds: 4));
      
      // 1. Try writing to secure storage
      try {
        await _secureStorage.write(key: 'offline_email', value: email);
        await _secureStorage.write(key: 'offline_password', value: password);
        await _secureStorage.write(key: 'offline_token', value: authData.token);
        await _secureStorage.write(key: 'offline_uid', value: authData.record.id);
        await _secureStorage.write(key: 'offline_role', value: authData.record.getStringValue('role'));
        await _secureStorage.write(key: 'offline_name', value: authData.record.getStringValue('name'));
        await _secureStorage.write(key: 'offline_school_id', value: authData.record.getStringValue('school_id'));
        await _secureStorage.write(key: 'offline_school_name', value: authData.record.getStringValue('school_name'));
      } catch (_) {}

      // 2. Also write to SharedPreferences as guaranteed fallback (especially on Linux desktop)
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('offline_email', email);
        await prefs.setString('offline_password', password);
        await prefs.setString('offline_token', authData.token);
        await prefs.setString('offline_uid', authData.record.id);
        await prefs.setString('offline_role', authData.record.getStringValue('role'));
        await prefs.setString('offline_name', authData.record.getStringValue('name'));
        await prefs.setString('offline_school_id', authData.record.getStringValue('school_id'));
        await prefs.setString('offline_school_name', authData.record.getStringValue('school_name'));
      } catch (_) {}

    } catch (e) {
      String? savedEmail;
      String? savedPassword;
      String? token;
      String? uid;
      String? role;
      String? name;
      String? schoolId;
      String? schoolName;

      // Try reading from secure storage first
      try {
        savedEmail = await _secureStorage.read(key: 'offline_email');
        savedPassword = await _secureStorage.read(key: 'offline_password');
        token = await _secureStorage.read(key: 'offline_token');
        uid = await _secureStorage.read(key: 'offline_uid');
        role = await _secureStorage.read(key: 'offline_role');
        name = await _secureStorage.read(key: 'offline_name');
        schoolId = await _secureStorage.read(key: 'offline_school_id');
        schoolName = await _secureStorage.read(key: 'offline_school_name');
      } catch (_) {}

      // If secure storage returned nothing, read from SharedPreferences
      if (savedEmail == null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          savedEmail = prefs.getString('offline_email');
          savedPassword = prefs.getString('offline_password');
          token = prefs.getString('offline_token');
          uid = prefs.getString('offline_uid');
          role = prefs.getString('offline_role');
          name = prefs.getString('offline_name');
          schoolId = prefs.getString('offline_school_id');
          schoolName = prefs.getString('offline_school_name');
        } catch (_) {}
      }

      if (savedEmail != null && savedEmail.trim().toLowerCase() == email.trim().toLowerCase() && savedPassword == password) {
        _pb.authStore.save(
          token ?? 'offline_mock_token',
          RecordModel({
            'id': uid ?? 'offline_uid',
            'collectionId': 'rm_profiles',
            'collectionName': 'rm_profiles',
            'email': email,
            'name': name ?? 'Offline User',
            'role': role ?? 'teacher',
            'school_id': schoolId ?? '',
            'school_name': schoolName ?? '',
          }),
        );
        print("Offline login successful from local storage fallback.");
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
      try {
        String? role = await _secureStorage.read(key: 'offline_role');
        if (role != null && role.isNotEmpty) return role.toLowerCase().trim();
      } catch (_) {}

      try {
        final prefs = await SharedPreferences.getInstance();
        String? role = prefs.getString('offline_role');
        if (role != null && role.isNotEmpty) return role.toLowerCase().trim();
      } catch (_) {}

      return 'teacher';
    }
  }
}
