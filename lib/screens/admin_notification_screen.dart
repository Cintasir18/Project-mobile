
import 'package:flutter/material.dart';
import 'package:elora_school/widgets/elora_components.dart';

import 'package:elora_school/theme/colors.dart';
import 'package:elora_school/services/notification_data_service.dart';

class AdminNotificationPage extends StatefulWidget {
  const AdminNotificationPage({super.key});

  @override
  State<AdminNotificationPage> createState() => _AdminNotificationPageState();
}

class _AdminNotificationPageState extends State<AdminNotificationPage> {

  final _titleController = TextEditingController();
  final _bodyController  = TextEditingController();

  bool _isSending = false;
  String _target  = 'all';

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _sendNotification() async {
    final title = _titleController.text.trim();
    final body  = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      _showSnack('Judul dan pesan tidak boleh kosong.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kirim Notifikasi'),
        content: Text(
          'Kirim notifikasi ke ${_target == 'all' ? 'semua siswa' : 'siswa terpilih'}?\n\n'
          'Judul: $title\nPesan: $body',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSending = true);

    try {
      final result = await NotificationDataService.instance.send(title: title, body: body, target: _target);
      if (!mounted) return;
      _showSnack(result['message']?.toString() ?? 'Notifikasi berhasil diproses.');
      _titleController.clear();
      _bodyController.clear();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kirim Notifikasi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            EloraCard(
              width: double.infinity,
              color: eloraPrimary.withValues(alpha: 0.08),
              border: Border.all(color: eloraPrimary.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_outlined,
                      color: eloraPrimary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Notifikasi akan dikirim ke HP semua siswa '
                      'yang sudah login minimal sekali.',
                      style: TextStyle(fontSize: 12, color: eloraDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _sectionLabel('TARGET PENERIMA'),
            const SizedBox(height: 10),
            Row(
              children: [
                _targetChip('Semua Siswa', 'all'),
              ],
            ),
            const SizedBox(height: 24),

            _sectionLabel('JUDUL NOTIFIKASI'),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              enabled: !_isSending,
              maxLength: 100,
              style: const TextStyle(fontSize: 13, color: eloraDark),
              decoration: _inputDeco('Contoh: Pengumuman SPP Bulan November'),
            ),
            const SizedBox(height: 16),

            _sectionLabel('ISI PESAN'),
            const SizedBox(height: 8),
            TextField(
              controller: _bodyController,
              enabled: !_isSending,
              maxLength: 300,
              maxLines: 4,
              style: const TextStyle(fontSize: 13, color: eloraDark),
              decoration: _inputDeco(
                  'Contoh: Tagihan SPP bulan November sudah tersedia. Segera lakukan pembayaran.'),
            ),
            const SizedBox(height: 32),

            EloraPrimaryButton(
              label: 'Kirim Notifikasi',
              icon: Icons.send_rounded,
              isLoading: _isSending,
              onPressed: _sendNotification,
            ),
          ],
        ),
      ),
    );
  }

  Widget _targetChip(String label, String value) {
    final selected = _target == value;
    return GestureDetector(
      onTap: () => setState(() => _target = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? eloraPrimary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? eloraPrimary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade700,
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: Colors.grey.shade500,
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade500),
      filled: true,
      fillColor: const Color(0xFFD9D9D9),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: eloraPrimary, width: 1.2),
      ),
    );
  }
}
