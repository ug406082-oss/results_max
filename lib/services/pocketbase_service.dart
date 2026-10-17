import 'package:pocketbase/pocketbase.dart';

class PBService {
  static final PBService _instance = PBService._internal();
  factory PBService() => _instance;
  PBService._internal();

  final PocketBase client = PocketBase('https://8f257387100532af-223-123-77-98.serveousercontent.com');
}
