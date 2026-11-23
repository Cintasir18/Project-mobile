
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:elora_school/theme/colors.dart';
import 'package:elora_school/services/payment_service.dart';

class AdminPaymentPage extends StatefulWidget {
  const AdminPaymentPage({super.key});

  @override
  State<AdminPaymentPage> createState() => _AdminPaymentPageState();
}

class _AdminPaymentPageState extends State<AdminPaymentPage>
    with SingleTickerProviderStateMixin {

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchPayments();
    _fetchSppConfig();
    _fetchChain();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _payments = [];
  bool _isLoadingPayments = true;
  bool _isUpdating = false;
  String _searchQuery = '';
  String _statusFilter = 'Semua';


  Future<void> _fetchPayments() async {
    if (mounted) setState(() => _isLoadingPayments = true);
    try {
      final data = await PaymentService.instance.adminPayments();
      if (!mounted) return;
      setState(() => _payments = data);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal memuat tagihan: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPayments = false);
    }
  }

  List<Map<String, dynamic>> get _filteredPayments {
    return _payments.where((p) {
      final q = _searchQuery.toLowerCase();
      final matchQ =
          '${p['nama']} ${p['student_id']} ${p['institution']} ${p['period']}'
              .toLowerCase()
              .contains(q);
      final s = p['status']?.toString() ?? 'unpaid';
      final matchS =
          _statusFilter == 'Semua' ||
          (_statusFilter == 'Belum Lunas' && s != 'paid') ||
          (_statusFilter == 'Lunas' && s == 'paid');
      return matchQ && matchS;
    }).toList();
  }

  List<Map<String, dynamic>> get _studentGroups {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final p in _filteredPayments) {
      final key = '${p['user_id'] ?? p['student_id'] ?? p['nama']}';
      grouped.putIfAbsent(key, () => []).add(p);
    }
    return grouped.entries.map((e) {
      final first = e.value.first;
      return <String, dynamic>{
        'nama': first['nama'] ?? '-',
        'student_id': first['student_id'] ?? '-',
        'institution': first['institution'] ?? '-',
        'bills': e.value,
      };
    }).toList();
  }

  int get _unpaidCount => _payments.where((p) => p['status'] != 'paid').length;

  double get _unpaidTotal =>
      _payments.where((p) => p['status'] != 'paid').fold<double>(0, (sum, p) {
        final a = double.tryParse('${p['amount']}') ?? 0;
        final paid = double.tryParse('${p['paid_amount'] ?? 0}') ?? 0;
        return sum + (a - paid).clamp(0, a);
      });

  Future<void> _updatePaymentStatus(Map<String, dynamic> payment) async {
    if (_isUpdating) return;
    final isPaid = payment['status'] == 'paid';
    final newStatus = isPaid ? 'unpaid' : 'paid';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah Status Pembayaran'),
        content: Text(
          'Ubah tagihan ${payment['nama'] ?? 'siswa'} '
          'periode ${payment['period'] ?? '-'} menjadi '
          '${newStatus == 'paid' ? 'Lunas' : 'Belum Lunas'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Ubah'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isUpdating = true);
    try {
      await PaymentService.instance.updateStatus(
        int.parse(payment['payment_id'].toString()), newStatus,
      );
      await _fetchPayments();
      await _fetchChain();
      if (!mounted) return;
      _showSnack(newStatus == 'paid' ? 'Tagihan berhasil ditandai lunas.' : 'Status tagihan dikembalikan menjadi belum lunas.');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal: $e');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  double _sppAmount = 500000;
  int _sppDueDay = 10;
  bool _isLoadingConfig = true;
  bool _isSavingConfig = false;

  int _genMonth = DateTime.now().month;
  int _genYear = DateTime.now().year;
  bool _isGenerating = false;

  final _amountController = TextEditingController();
  final _dueDayController = TextEditingController();

  Future<void> _fetchSppConfig() async {
    setState(() => _isLoadingConfig = true);
    try {
      final result = await PaymentService.instance.fetchSppConfig();
      if (!mounted) return;
      setState(() {
        _sppAmount = (result['amount'] as num).toDouble();
        _sppDueDay = (result['due_day'] as num).toInt();
        _amountController.text = _sppAmount.round().toString();
        _dueDayController.text = _sppDueDay.toString();
      });
    } catch (e) {
      debugPrint('SPP CONFIG ERROR: $e');
      _amountController.text = _sppAmount.round().toString();
      _dueDayController.text = _sppDueDay.toString();
    } finally {
      if (mounted) setState(() => _isLoadingConfig = false);
    }
  }

  Future<void> _saveSppConfig() async {
    final amount = double.tryParse(_amountController.text.replaceAll('.', ''));
    final dueDay = int.tryParse(_dueDayController.text);
    if (amount == null || amount <= 0) {
      _showSnack('Masukkan nominal SPP yang valid.');
      return;
    }
    if (dueDay == null || dueDay < 1 || dueDay > 28) {
      _showSnack('Hari jatuh tempo harus antara 1–28.');
      return;
    }
    setState(() => _isSavingConfig = true);
    try {
      await PaymentService.instance.saveSppConfig(amount: amount, dueDay: dueDay);
      if (!mounted) return;
      setState(() { _sppAmount = amount; _sppDueDay = dueDay; });
      _showSnack('Konfigurasi SPP disimpan.');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _isSavingConfig = false);
    }
  }

  Future<void> _generateMonthly() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Tagihan SPP'),
        content: Text(
          'Generate tagihan SPP ${_monthName(_genMonth)} $_genYear\n'
          'Nominal: ${_formatRupiah(_sppAmount)}\n'
          'untuk semua siswa aktif?\n\n'
          'Siswa yang sudah punya tagihan bulan ini akan di-skip.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isGenerating = true);
    try {
      final result = await PaymentService.instance.generateMonthly(
        month: _genMonth, year: _genYear, amount: _sppAmount,
      );
      if (!mounted) return;
      _showSnack('${result['message'] ?? 'Tagihan berhasil digenerate.'} (${result['inserted'] ?? 0} baru, ${result['skipped'] ?? 0} di-skip)');
      await _fetchPayments();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  List<Map<String, dynamic>> _chainBlocks = [];
  bool _isLoadingChain = true;
  bool _chainValid = false;
  String? _chainError;

  Future<void> _fetchChain() async {
    if (mounted) setState(() { _isLoadingChain = true; _chainError = null; });
    try {
      final body = await PaymentService.instance.fetchChain(adminView: true);
      final rawList = (body['data'] as List<dynamic>? ?? []);
      if (!mounted) return;
      setState(() {
        _chainBlocks = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _chainValid = body['chain_valid'] == true;
        _isLoadingChain = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _chainError = e.toString().replaceFirst('Exception: ', ''); _isLoadingChain = false; });
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatRupiah(dynamic value) {
    final amount = double.tryParse('$value') ?? 0;
    final digits = amount.round().toString();
    return 'Rp ${digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')}';
  }

  String _monthName(int m) {
    const names = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return names[m];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Administrasi Pembayaran',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () {
              _fetchPayments();
              _fetchSppConfig();
              _fetchChain();
            },
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat ulang',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: eloraPrimary,
          indicatorColor: eloraPrimary,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Tagihan'),
            Tab(icon: Icon(Icons.add_card_outlined), text: 'Generate SPP'),
            Tab(icon: Icon(Icons.link_rounded), text: 'Chain Log'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildTagihanTab(), _buildGenerateTab(), _buildChainTab()],
      ),
    );
  }

  Widget _buildTagihanTab() {
    return RefreshIndicator(
      onRefresh: _fetchPayments,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: eloraPrimary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Tunggakan',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatRupiah(_unpaidTotal),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_unpaidCount belum lunas dari ${_payments.length} tagihan',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            decoration: InputDecoration(
              hintText: 'Cari nama, ID, institusi, atau periode',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            initialValue: _statusFilter,
            decoration: InputDecoration(
              labelText: 'Filter Status',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'Semua', child: Text('Semua Status')),
              DropdownMenuItem(
                value: 'Belum Lunas',
                child: Text('Belum Lunas'),
              ),
              DropdownMenuItem(value: 'Lunas', child: Text('Lunas')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _statusFilter = v);
            },
          ),
          const SizedBox(height: 16),

          if (_isLoadingPayments)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filteredPayments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 60,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _payments.isEmpty
                        ? 'Belum ada tagihan.\nGenerate SPP terlebih dahulu.'
                        : 'Tidak ada hasil yang cocok.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (_payments.isEmpty) ...[
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _tabController.animateTo(1),
                      icon: const Icon(Icons.add_card_outlined),
                      label: const Text('Generate SPP'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: eloraPrimary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            )
          else ...[
            Text(
              '${_studentGroups.length} siswa',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            ..._studentGroups.map(_buildStudentCard),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final bills = (student['bills'] as List).cast<Map<String, dynamic>>();
    final unpaid = bills.where((b) => b['status'] != 'paid').toList();
    final outstanding = unpaid.fold<double>(0, (sum, b) {
      final a = double.tryParse('${b['amount']}') ?? 0;
      final p = double.tryParse('${b['paid_amount'] ?? 0}') ?? 0;
      return sum + (a - p).clamp(0, a);
    });

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: CircleAvatar(
            backgroundColor: eloraPrimary.withValues(alpha: 0.1),
            child: const Icon(
              Icons.person_outline_rounded,
              color: eloraPrimary,
            ),
          ),
          title: Text(
            student['nama']?.toString() ?? '-',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student['student_id']?.toString() ?? '-'),
                Text(student['institution']?.toString() ?? '-'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _chip('${bills.length} tagihan', eloraPrimary),
                    _chip(
                      '${unpaid.length} belum lunas',
                      unpaid.isNotEmpty ? Colors.orange : Colors.green,
                    ),
                  ],
                ),
                if (unpaid.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Tunggakan: ${_formatRupiah(outstanding)}',
                    style: const TextStyle(
                      color: eloraPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
          children: [const Divider(height: 12), ...bills.map(_buildBillCard)],
        ),
      ),
    );
  }

  Widget _buildBillCard(Map<String, dynamic> bill) {
    final isPaid = bill['status'] == 'paid';
    final statusColor = isPaid ? Colors.green : Colors.orange;
    final period =
        bill['period']?.toString() ??
        '${bill['billing_year'] ?? ''}-${bill['billing_month'] ?? ''}';

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      period.isEmpty ? 'Periode tidak tersedia' : period,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Jatuh tempo: ${bill['due_date'] ?? '-'}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isPaid
                      ? 'Lunas'
                      : bill['status'] == 'partial'
                      ? 'Sebagian'
                      : 'Belum Lunas',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _detailItem('Tagihan', _formatRupiah(bill['amount'])),
              ),
              Expanded(
                child: _detailItem(
                  'Dibayar',
                  _formatRupiah(bill['paid_amount'] ?? 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isUpdating ? null : () => _updatePaymentStatus(bill),
              icon: Icon(
                isPaid
                    ? Icons.undo_rounded
                    : Icons.check_circle_outline_rounded,
              ),
              label: Text(isPaid ? 'Batalkan Lunas' : 'Tandai Lunas'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
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

  Widget _detailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildGenerateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          _sectionTitle('Konfigurasi SPP'),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _isLoadingConfig
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('NOMINAL SPP (Rp)'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          enabled: !_isSavingConfig,
                          decoration: _inputDeco('Contoh: 500000'),
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('HARI JATUH TEMPO (1–28)'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _dueDayController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          enabled: !_isSavingConfig,
                          decoration: _inputDeco('Contoh: 10'),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSavingConfig ? null : _saveSppConfig,
                            icon: _isSavingConfig
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: const Text('Simpan Konfigurasi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: eloraPrimary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 24),

          _sectionTitle('Generate Tagihan Bulan Baru'),
          const SizedBox(height: 4),
          Text(
            'Generate akan membuat tagihan SPP untuk semua siswa aktif '
            'pada bulan yang dipilih. Siswa yang sudah punya tagihan di bulan '
            'tersebut akan otomatis di-skip.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  _buildLabel('BULAN'),
                  const SizedBox(height: 8),
                  Container(
                    height: 45,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9D9D9),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _genMonth,
                        isExpanded: true,
                        style: const TextStyle(fontSize: 13, color: eloraDark),
                        items: List.generate(12, (i) => i + 1).map((m) {
                          return DropdownMenuItem(
                            value: m,
                            child: Text(_monthName(m)),
                          );
                        }).toList(),
                        onChanged: _isGenerating
                            ? null
                            : (v) {
                                if (v != null) setState(() => _genMonth = v);
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('TAHUN'),
                  const SizedBox(height: 8),
                  Container(
                    height: 45,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9D9D9),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _genYear,
                        isExpanded: true,
                        style: const TextStyle(fontSize: 13, color: eloraDark),
                        items:
                            List.generate(5, (i) => DateTime.now().year - 1 + i)
                                .map(
                                  (y) => DropdownMenuItem(
                                    value: y,
                                    child: Text('$y'),
                                  ),
                                )
                                .toList(),
                        onChanged: _isGenerating
                            ? null
                            : (v) {
                                if (v != null) setState(() => _genYear = v);
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: eloraPrimary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: eloraPrimary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Nominal: ${_formatRupiah(_sppAmount)}  •  '
                            'Jatuh tempo: tgl $_sppDueDay',
                            style: const TextStyle(
                              fontSize: 12,
                              color: eloraPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _generateMonthly,
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.bolt_rounded),
                      label: Text(
                        _isGenerating
                            ? 'Sedang generate...'
                            : 'Generate ${_monthName(_genMonth)} $_genYear',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: eloraPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildChainTab() {
    return RefreshIndicator(
      onRefresh: _fetchChain,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: eloraPrimary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.link_rounded, color: Colors.white, size: 32),
                const SizedBox(height: 10),
                const Text(
                  'Blockchain SPP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_chainBlocks.length} blok tercatat • SHA-256',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      _chainValid
                          ? Icons.verified_rounded
                          : _chainBlocks.isEmpty
                          ? Icons.link_rounded
                          : Icons.warning_rounded,
                      color: _chainValid
                          ? Colors.lightGreenAccent
                          : Colors.orangeAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _chainValid
                            ? 'Rantai valid — semua blok terverifikasi'
                            : _chainBlocks.isEmpty
                            ? 'Belum ada blok dalam rantai'
                            : 'Ditemukan ketidaksesuaian pada rantai',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (_isLoadingChain)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_chainError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _chainError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
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
            )
          else if (_chainBlocks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(
                    Icons.link_rounded,
                    size: 56,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Belum ada riwayat perubahan status SPP.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            ..._chainBlocks.reversed.map(_buildChainBlockCard),
          ],

          const SizedBox(height: 12),

          if (!_isLoadingChain) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 13,
                  color: Colors.black45,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Hash SHA-256 digunakan untuk mendeteksi perubahan data, '
                    'bukan sebagai bukti pembayaran resmi.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black45,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChainBlockCard(Map<String, dynamic> b) {
    final oldStatus = b['old_status']?.toString() ?? '';
    final newStatus = b['new_status']?.toString() ?? '';
    final blockHash = b['block_hash']?.toString() ?? '';
    final shortHash = blockHash.length > 8
        ? blockHash.substring(0, 8)
        : blockHash;
    final isValid = b['is_valid'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isValid
              ? const Color(0xFFE5EAE8)
              : Colors.orange.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F3F1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${b['block_index'] ?? '-'}',
                  style: const TextStyle(
                    color: eloraPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  b['period']?.toString() ?? '-',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: eloraDark,
                  ),
                ),
              ),
              Icon(
                isValid ? Icons.verified_rounded : Icons.warning_amber_rounded,
                color: isValid ? eloraPrimary : Colors.orange,
                size: 18,
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              _buildStatusChip(
                _labelStatus(oldStatus),
                oldStatus == 'paid' ? Colors.green : Colors.orange,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 12,
                  color: Colors.black45,
                ),
              ),
              _buildStatusChip(
                _labelStatus(newStatus),
                newStatus == 'paid' ? Colors.green : Colors.orange,
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            '${b['nama'] ?? '-'} (${b['student_id'] ?? '-'})',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: eloraDark,
            ),
          ),

          const SizedBox(height: 4),

          Row(
            children: [
              Expanded(
                child: _detailItem(
                  'Admin',
                  b['changed_by_name']?.toString() ?? '-',
                ),
              ),
              Expanded(
                child: _detailItem('Waktu', b['timestamp']?.toString() ?? '-'),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            'Hash: $shortHash...',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black45,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: eloraDark,
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w500,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
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
