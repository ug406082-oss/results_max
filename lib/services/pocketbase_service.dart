import 'package:pocketbase/pocketbase.dart';

class PBService {
  static final PBService _instance = PBService._internal();
  factory PBService() => _instance;
  PBService._internal();

  final PocketBase client = PocketBase('https://7cb4f6ee6a43cf44-223-123-77-98.serveousercontent.com');
}
