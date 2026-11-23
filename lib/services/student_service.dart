import 'supabase_service.dart';

class StudentService {
  StudentService._();
  static final StudentService instance = StudentService._();

  Future<List<Map<String, dynamic>>> listStudents() async {
    final rows = await SupabaseService.client.from('profiles')
        .select('id,full_name,student_id,email,role,is_active,institution_id')
        .eq('role', 'student').order('full_name');
    final institutions = await SupabaseService.client.from('institutions').select('id,name');
    final institutionMap = {for (final item in institutions) item['id'].toString(): item['name']?.toString() ?? ''};
    return rows.map<Map<String, dynamic>>((row) {
      final item = Map<String, dynamic>.from(row);
      item['nama'] = item['full_name'] ?? '';
      item['institution'] = institutionMap[item['institution_id']?.toString()] ?? '';
      item['is_active'] = item['is_active'] == true;
      return item;
    }).toList();
  }

  Future<void> setActive(String userId, bool active) async {
    await SupabaseService.client.rpc('admin_set_student_active', params: {'p_user_id': userId, 'p_is_active': active});
  }
}
