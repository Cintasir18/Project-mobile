import 'supabase_service.dart';

class AiService {
  AiService._();
  static final AiService instance = AiService._();

  Future<String> sendMessage(List<Map<String, String>> messages) async {
    final response = await SupabaseService.client.functions.invoke(
      'elora-ai', body: {'messages': messages},
    );
    if (response.status < 200 || response.status >= 300) {
      throw Exception('Layanan AI belum dapat dihubungi (${response.status}).');
    }
    final data = response.data;
    if (data is Map && data['reply'] is String) return data['reply'] as String;
    throw Exception(data is Map ? (data['message']?.toString() ?? 'Respons AI tidak valid.') : 'Respons AI tidak valid.');
  }
}
