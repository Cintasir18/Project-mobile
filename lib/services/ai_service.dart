
import 'package:elora_school/services/supabase_service.dart';

class AiService {
  AiService._();

  static final AiService instance = AiService._();

  Future<String> sendMessage(
    List<Map<String, String>> messages,
  ) {
    return _invoke(
      mode: 'chat',
      messages: messages,
    );
  }

  Future<String> generateQuiz(String prompt) {
    return _invoke(
      mode: 'quiz',
      messages: [
        {
          'role': 'user',
          'content': prompt,
        },
      ],
    );
  }

  Future<String> _invoke({
    required String mode,
    required List<Map<String, String>> messages,
  }) async {
    try {
      final response =
          await SupabaseService.client.functions.invoke(
        'elora-ai',
        body: {
          'mode': mode,
          'messages': messages,
        },
      );

      final data = response.data;

      if (response.status < 200 || response.status >= 300) {
        final message = data is Map
            ? data['message']?.toString()
            : null;

        throw Exception(
          message ?? 'Layanan AI gagal (${response.status}).',
        );
      }

      if (data is! Map) {
        throw Exception(
          'Format respons server tidak valid.',
        );
      }

      if (data['success'] == false) {
        throw Exception(
          data['message']?.toString() ??
              'ELORA AI gagal memproses permintaan.',
        );
      }

      final reply = data['reply'];

      if (reply is! String || reply.trim().isEmpty) {
        throw Exception(
          'Gemini tidak memberikan jawaban.',
        );
      }

      return reply.trim();
    } catch (e) {
      if (e is Exception) rethrow;

      throw Exception(
        'Tidak dapat menghubungi ELORA AI: $e',
      );
    }
  }
}
