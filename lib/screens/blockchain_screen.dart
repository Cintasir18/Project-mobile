
import 'package:flutter/material.dart';

import 'package:elora_school/theme/colors.dart';
import 'package:elora_school/services/payment_service.dart';

class _ChainBlock {
  final int blockIndex;
  final int billId;
  final String userId;
  final String studentId;
  final String nama;
  final String period;
  final String amount;
  final String oldStatus;
  final String newStatus;
  final String changedByName;
  final String timestamp;
  final String previousHash;
  final String blockHash;
  final bool isValid;

  const _ChainBlock({
    required this.blockIndex,
    required this.billId,
    required this.userId,
    required this.studentId,
    required this.nama,
    required this.period,
    required this.amount,
    required this.oldStatus,
    required this.newStatus,
    required this.changedByName,
    required this.timestamp,
    required this.previousHash,
    required this.blockHash,
    required this.isValid,
  });

  factory _ChainBlock.fromJson(Map<String, dynamic> j) {
    return _ChainBlock(
      blockIndex:    (j['block_index'] as num?)?.toInt() ?? 0,
      billId:        (j['bill_id'] as num?)?.toInt() ?? 0,
      userId:        j['user_id']?.toString() ?? '',
      studentId:     j['student_id']?.toString() ?? '',
      nama:          j['nama']?.toString() ?? '',
      period:        j['period']?.toString() ?? '',
      amount:        j['amount']?.toString() ?? '0',
      oldStatus:     j['old_status']?.toString() ?? '',
      newStatus:     j['new_status']?.toString() ?? '',
      changedByName: j['changed_by_name']?.toString() ?? '',
      timestamp:     j['timestamp']?.toString() ?? '',
      previousHash:  j['previous_hash']?.toString() ?? '',
      blockHash:     j['block_hash']?.toString() ?? '',
      isValid:       j['is_valid'] == true,
    );
  }
}

class BlockchainPage extends StatefulWidget {
  const BlockchainPage({super.key});

  @override
  State<BlockchainPage> createState() => _BlockchainPageState();
}

class _BlockchainPageState extends State<BlockchainPage> {

  List<_ChainBlock> _blocks  = [];
  bool              _isLoading = true;
  bool              _chainValid = false;
  String?           _error;

  @override
  void initState() {
    super.initState();
    _fetchChain();
  }

  Future<void> _fetchChain() async {
    if (mounted) setState(() { _isLoading = true; _error = null; });
    try {
      final body = await PaymentService.instance.fetchChain();
      final rawList = (body['data'] as List<dynamic>? ?? []);
      final blocks = rawList.map((e) => _ChainBlock.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      if (!mounted) return;
      setState(() { _blocks = blocks; _chainValid = body['chain_valid'] == true; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; });
    }
  }

  void _showValidationResult() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _chainValid ? Icons.verified_rounded : Icons.warning_rounded,
              color: _chainValid ? eloraPrimary : Colors.orangeAccent,
            ),
            const SizedBox(width: 8),
            Text(
              _chainValid ? 'Rantai Valid' : 'Rantai Tidak Valid',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          _chainValid
              ? 'Seluruh ${_blocks.length} blok dalam rantai telah diverifikasi. '
                'Hash dan previousHash setiap blok konsisten.'
              : 'Ditemukan ketidaksesuaian pada satu atau lebih blok. '
                'Integritas rantai tidak dapat dijamin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  String _formatRupiah(String raw) {
    final amount = double.tryParse(raw) ?? 0;
    final digits = amount.round().toString();
    return 'Rp ${digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => '.',
    )}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: eloraBackground,
      appBar: AppBar(
        title: const Text(
          'Blockchain SPP',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: eloraPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: eloraPrimary))
            : _error != null
            ? _buildErrorState()
            : RefreshIndicator(
                onRefresh: _fetchChain,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 16),
                    _buildInfoCard(),
                    const SizedBox(height: 14),
                    _buildActionButtons(),
                    const SizedBox(height: 16),
                    if (_blocks.isEmpty)
                      _buildEmptyState()
                    else ...[
                      const Text(
                        'Riwayat Blok',
                        style: TextStyle(
                          color: eloraDark,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._blocks.reversed.map(
                        (b) => _BlockCard(block: b, formatRupiah: _formatRupiah),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'Hash SHA-256 digunakan untuk mendeteksi perubahan data, '
                      'bukan sebagai bukti pembayaran resmi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 54, color: Colors.grey),
            const SizedBox(height: 14),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchChain,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: eloraPrimary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(Icons.link_rounded, size: 52, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'Belum ada riwayat perubahan SPP.',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: eloraPrimary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.link_rounded, color: Colors.white, size: 34),
          const SizedBox(height: 12),
          const Text(
            'Blockchain SPP',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_blocks.length} blok tercatat • SHA-256 • Riwayat Administrasi',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                _chainValid
                    ? Icons.verified_rounded
                    : Icons.warning_rounded,
                color: _chainValid
                    ? Colors.lightGreenAccent
                    : Colors.orangeAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _chainValid
                      ? 'Rantai valid — semua blok terverifikasi'
                      : _blocks.isEmpty
                      ? 'Belum ada blok dalam rantai'
                      : 'Ditemukan ketidaksesuaian pada rantai',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EAE8)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cara kerja blockchain ini',
            style: TextStyle(
              color: eloraDark,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Setiap blok mencatat perubahan status SPP oleh admin. '
            'Blok dihubungkan via hash SHA-256 yang mencakup data blok '
            'dan hash blok sebelumnya, sehingga perubahan data terdeteksi.',
            style: TextStyle(color: Colors.black54, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _fetchChain,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Muat Ulang'),
            style: ElevatedButton.styleFrom(
              backgroundColor: eloraPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _blocks.isNotEmpty ? _showValidationResult : null,
            icon: const Icon(Icons.verified_outlined, size: 18),
            label: const Text('Validasi Rantai'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: eloraPrimary,
              disabledBackgroundColor: Colors.grey.shade100,
              side: const BorderSide(color: eloraPrimary),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BlockCard extends StatelessWidget {
  final _ChainBlock block;
  final String Function(String) formatRupiah;

  const _BlockCard({required this.block, required this.formatRupiah});

  String _short(String hash) =>
      hash.length > 8 ? hash.substring(0, 8) : hash;

  String _labelStatus(String s) {
    switch (s.toLowerCase()) {
      case 'paid':
        return 'Lunas';
      case 'unpaid':
        return 'Belum Lunas';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EAE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F3F1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '#${block.blockIndex}',
                  style: const TextStyle(
                    color: eloraPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  block.period,
                  style: const TextStyle(
                    color: eloraDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(
                block.isValid
                    ? Icons.verified_rounded
                    : Icons.warning_amber_rounded,
                color: block.isValid ? eloraPrimary : Colors.orange,
                size: 20,
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              _StatusChip(
                label: _labelStatus(block.oldStatus),
                color: block.oldStatus == 'paid' ? Colors.green : Colors.orange,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.black45),
              ),
              _StatusChip(
                label: _labelStatus(block.newStatus),
                color: block.newStatus == 'paid' ? Colors.green : Colors.orange,
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            block.nama,
            style: const TextStyle(
              color: eloraDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            block.studentId,
            style: const TextStyle(color: Colors.black45, fontSize: 12),
          ),

          const SizedBox(height: 5),

          Text(
            formatRupiah(block.amount),
            style: const TextStyle(
              color: eloraPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Diubah oleh: ${block.changedByName}',
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),

          Text(
            block.timestamp,
            style: const TextStyle(color: Colors.black45, fontSize: 11),
          ),

          const SizedBox(height: 10),

          _HashLine(label: 'Hash', value: '${_short(block.blockHash)}...'),
          const SizedBox(height: 5),
          _HashLine(
            label: 'Previous Hash',
            value: block.previousHash == '0' * 64
                ? '(genesis)'
                : '${_short(block.previousHash)}...',
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HashLine extends StatelessWidget {
  final String label;
  final String value;

  const _HashLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black45,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        SelectableText(
          value,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 10,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
