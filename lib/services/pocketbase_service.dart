import 'package:pocketbase/pocketbase.dart';

class PBService {
  static final PBService _instance = PBService._internal();
  factory PBService() => _instance;
  PBService._internal();

  final PocketBase client = PocketBase('https://resultmax-school.serveo.net');
}
