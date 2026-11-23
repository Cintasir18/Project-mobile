import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'supabase_service.dart';
import 'auth_service.dart';

class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  Future<List<Map<String, dynamic>>> myPayments() async {
    final uid = AuthService.instance.currentUser?.id;
    if (uid == null) throw Exception('Sesi login tidak ditemukan.');
    final rows = await SupabaseService.client.from('bills').select()
        .eq('user_id', uid).order('billing_year', ascending: false)
        .order('billing_month', ascending: false).order('id', ascending: false);
    return rows.map<Map<String, dynamic>>((row) {
      final item = Map<String, dynamic>.from(row);
      final month = (item['billing_month'] as num).toInt();
      final year = (item['billing_year'] as num).toInt();
      item['period'] = '$year-${month.toString().padLeft(2, '0')}';
      final amount = _num(item['amount']);
      final paid = _num(item['paid_amount']);
      item['remaining_amount'] = (amount - paid).clamp(0, amount);
      item['status'] = item['remaining_amount'] <= 0 ? 'paid' : paid > 0 ? 'partial' : 'unpaid';
      return item;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> adminPayments() async {
    final rows = await SupabaseService.client.from('bills').select()
        .order('billing_year', ascending: false).order('billing_month', ascending: false);
    final profiles = await SupabaseService.client.from('profiles')
        .select('id,full_name,student_id,institution_id').eq('role', 'student');
    final institutions = await SupabaseService.client.from('institutions').select('id,name');
    final institutionMap = {for (final i in institutions) i['id'].toString(): i['name']?.toString() ?? ''};
    final profileMap = {for (final p in profiles) p['id'].toString(): p};
    return rows.map<Map<String, dynamic>>((row) {
      final item = Map<String, dynamic>.from(row);
      final p = profileMap[item['user_id'].toString()];
      final month = (item['billing_month'] as num).toInt();
      final year = (item['billing_year'] as num).toInt();
      final amount = _num(item['amount']);
      final paid = _num(item['paid_amount']);
      item.addAll({
        'payment_id': item['id'], 'bill_id': item['id'],
        'nama': p?['full_name'] ?? '-', 'student_id': p?['student_id'] ?? '-',
        'institution': institutionMap[p?['institution_id']?.toString()] ?? '-',
        'period': '$year-${month.toString().padLeft(2, '0')}',
        'remaining_amount': (amount - paid).clamp(0, amount),
        'status': amount <= paid ? 'paid' : paid > 0 ? 'partial' : 'unpaid',
      });
      return item;
    }).toList();
  }

  Future<void> updateStatus(int billId, String status) async {
    await SupabaseService.client.rpc('admin_update_bill_status', params: {
      'p_bill_id': billId, 'p_new_status': status,
    });
  }

  Future<Map<String, dynamic>> fetchSppConfig() async {
    final row = await SupabaseService.client.from('spp_config').select('amount,due_day').eq('id', 1).maybeSingle();
    return {'amount': _num(row?['amount'] ?? 500000), 'due_day': (row?['due_day'] as num?)?.toInt() ?? 10};
  }

  Future<void> saveSppConfig({required double amount, required int dueDay}) async {
    await SupabaseService.client.from('spp_config').upsert({'id': 1, 'amount': amount, 'due_day': dueDay});
  }

  Future<Map<String, dynamic>> generateMonthly({required int month, required int year, required double amount}) async {
    final result = await SupabaseService.client.rpc('admin_generate_monthly_bills', params: {
      'p_month': month, 'p_year': year, 'p_amount': amount,
    });
    if (result is Map) return Map<String, dynamic>.from(result);
    throw Exception('Respons generate tagihan tidak valid.');
  }

  Future<Map<String, dynamic>> fetchChain({bool adminView = false}) async {
    final uid = AuthService.instance.currentUser?.id;
    if (uid == null) throw Exception('Sesi login tidak ditemukan.');
    final role = (await AuthService.instance.currentProfile())['role']?.toString();
    final isAdmin = role == 'admin' && adminView;
    final rows = isAdmin
        ? await SupabaseService.client.from('payment_chain').select().order('block_index')
        : await SupabaseService.client.from('payment_chain').select().eq('user_id', uid).order('block_index');
    final blocks = rows.map<Map<String, dynamic>>((r) => Map<String, dynamic>.from(r)).toList();
    bool? chainValid = blocks.isEmpty ? null : true;
    String? prevHash;
    for (final b in blocks) {
      final timestamp = _canonicalTimestamp(b['block_timestamp'] ?? b['timestamp']);
      final canonical = '${b['block_index']}${b['bill_id']}${b['student_id']}${b['period']}${b['old_status']}${b['new_status']}${b['changed_by_id']}$timestamp${b['previous_hash']}';
      final actual = sha256.convert(utf8.encode(canonical)).toString();
      final hashValid = actual == b['block_hash']?.toString();
      final prevValid = !isAdmin || prevHash == null || prevHash == b['previous_hash']?.toString();
      final valid = hashValid && prevValid;
      b['timestamp'] = timestamp;
      b['is_valid'] = valid;
      if (!valid) chainValid = false;
      prevHash = b['block_hash']?.toString();
    }
    return {'success': true, 'data': blocks, 'chain_valid': chainValid};
  }

  double _num(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  String _canonicalTimestamp(dynamic value) {
    final raw = value?.toString() ?? '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.isUtc ? parsed.toLocal() : parsed;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}
