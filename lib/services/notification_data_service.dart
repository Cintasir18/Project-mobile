import 'supabase_service.dart';
import 'auth_service.dart';

class NotificationDataService {
  NotificationDataService._();
  static final NotificationDataService instance = NotificationDataService._();

  Future<List<Map<String, dynamic>>> list() async {
    final uid = AuthService.instance.currentUser?.id;
    if (uid == null) throw Exception('Sesi login tidak ditemukan.');
    final rows = await SupabaseService.client.from('notifications').select()
        .order('created_at', ascending: false).limit(200);
    final reads = await SupabaseService.client.from('notification_reads')
        .select('notification_id').eq('user_id', uid);
    final readIds = reads.map((r) => r['notification_id'].toString()).toSet();
    return rows.map<Map<String, dynamic>>((row) => {
      'id': row['id'], 'title': row['title'], 'message': row['body'],
      'type': row['type'] ?? 'general', 'created_at': row['created_at'],
      'is_read': readIds.contains(row['id'].toString()),
    }).toList();
  }

  Future<void> markRead(int notificationId) async {
    final uid = AuthService.instance.currentUser?.id;
    if (uid == null) throw Exception('Sesi login tidak ditemukan.');
    await SupabaseService.client.from('notification_reads').upsert({
      'notification_id': notificationId, 'user_id': uid,
    }, onConflict: 'notification_id,user_id');
  }

  Future<Map<String, dynamic>> send({required String title, required String body, String target = 'all'}) async {
    final response = await SupabaseService.client.functions.invoke(
      'send-notification', body: {'title': title, 'body': body, 'target': target},
    );
    if (response.status < 200 || response.status >= 300) {
      throw Exception('Pengiriman notifikasi gagal (${response.status}).');
    }
    if (response.data is Map) return Map<String, dynamic>.from(response.data);
    return {'success': true, 'message': 'Notifikasi berhasil diproses.'};
  }
}
