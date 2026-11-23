import 'supabase_service.dart';

class InstitutionService {
  InstitutionService._();
  static final InstitutionService instance = InstitutionService._();

  Future<List<Map<String, dynamic>>> fetchInstitutions({bool useCacheOnError = true}) async {
    final rows = await SupabaseService.client
        .from('institutions')
        .select('id,name,type,location,latitude,longitude,is_active')
        .eq('is_active', true)
        .order('name');
    return rows.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchAllForAdmin() async {
    final rows = await SupabaseService.client
        .from('institutions')
        .select('id,name,type,location,latitude,longitude,is_active')
        .order('name');
    return rows.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> create(Map<String, dynamic> payload) async {
    await SupabaseService.client.from('institutions').insert(_cleanPayload(payload));
  }

  Future<void> update(int id, Map<String, dynamic> payload) async {
    await SupabaseService.client.from('institutions').update(_cleanPayload(payload)).eq('id', id);
  }

  Future<void> deactivate(int id) async {
    await SupabaseService.client.from('institutions').update({'is_active': false}).eq('id', id);
  }

  Map<String, dynamic> _cleanPayload(Map<String, dynamic> data) => {
    'name': data['name'],
    'type': data['type'],
    'location': data['location'],
    'latitude': double.parse(data['latitude'].toString()),
    'longitude': double.parse(data['longitude'].toString()),
  };
}
