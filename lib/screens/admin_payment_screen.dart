import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:elora_school/widgets/elora_components.dart';

import 'package:elora_school/theme/colors.dart';
import 'package:elora_school/services/payment_service.dart';

// Warna aksen untuk elemen yang paling penting (badge dan indikator progres).
const Color _accent = Color(0xFFF2B84B);
const Color _fieldFill = Color(0xFFF1F4F3);
const Color _fieldBorder = Color(0xFFE0E6E4);

// Hijau gelap diturunkan dari eloraPrimary agar tetap selaras dengan tema.
Color get _deepGreen => Color.lerp(eloraPrimary, Colors.black, 0.62)!;

class AdminPaymentPage extends StatefulWidget {
  const AdminPaymentPage({super.key});

  @override
  State<AdminPaymentPage> createState() => _AdminPaymentPageState();
}

class _AdminPaymentPageState extends State<AdminPaymentPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ---------------------------------------------------------
  // STATE TAGIHAN
  // ---------------------------------------------------------
  List<Map<String, dynamic>> _payments = [];
  bool _isLoadingPayments = true;
  bool _isUpdating = false;
  String _searchQuery = '';
  String _statusFilter = 'Semua';

  // ---------------------------------------------------------
  // STATE KONFIGURASI SPP DAN GENERATE
  // ---------------------------------------------------------
  double _sppAmount = 500000;
  int _sppDueDay = 10;
  bool _isLoadingConfig = true;
  bool _isSavingConfig = false;

  int _genMonth = DateTime.now().month;
  int _genYear = DateTime.now().year;
  bool _isGenerating = false;

  final _amountController = TextEditingController();
  final _dueDayController = TextEditingController();

  // ---------------------------------------------------------
  // STATE CHAIN
  // ---------------------------------------------------------
  List<Map<String, dynamic>> _chainBlocks = [];
  bool _isLoadingChain = true;
  bool _chainValid = false;
  String? _chainError;

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
    _amountController.dispose();
    _dueDayController.dispose();
    super.dispose();
  }

  // =========================================================
  // DATA: TAGIHAN
  // =========================================================

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
        int.parse(payment['payment_id'].toString()),
        newStatus,
      );
      await _fetchPayments();
      await _fetchChain();
      if (!mounted) return;
      _showSnack(
        newStatus == 'paid'
            ? 'Tagihan berhasil ditandai lunas.'
            : 'Status tagihan dikembalikan menjadi belum lunas.',
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal: $e');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // =========================================================
  // DATA: KONFIGURASI DAN GENERATE SPP
  // =========================================================

  Future<void> _fetchSppConfig() async {
    if (mounted) setState(() => _isLoadingConfig = true);
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
      _showSnack('Hari jatuh tempo harus antara 1 sampai 28.');
      return;
    }
    setState(() => _isSavingConfig = true);
    try {
      await PaymentService.instance.saveSppConfig(
        amount: amount,
        dueDay: dueDay,
      );
      if (!mounted) return;
      setState(() {
        _sppAmount = amount;
        _sppDueDay = dueDay;
      });
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
        month: _genMonth,
        year: _genYear,
        amount: _sppAmount,
      );
      if (!mounted) return;
      _showSnack(
        '${result['message'] ?? 'Tagihan berhasil digenerate.'} '
        '(${result['inserted'] ?? 0} baru, ${result['skipped'] ?? 0} di-skip)',
      );
      await _fetchPayments();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // =========================================================
  // DATA: CHAIN
  // =========================================================

  Future<void> _fetchChain() async {
    if (mounted) {
      setState(() {
        _isLoadingChain = true;
        _chainError = null;
      });
    }
    try {
      final body = await PaymentService.instance.fetchChain(adminView: true);
      final rawList = (body['data'] as List<dynamic>? ?? []);
      if (!mounted) return;
      setState(() {
        _chainBlocks = rawList
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _chainValid = body['chain_valid'] == true;
        _isLoadingChain = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chainError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingChain = false;
      });
    }
  }

  // =========================================================
  // HELPERS
  // =========================================================

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
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

  EdgeInsets get _listPadding => EdgeInsets.fromLTRB(
    20,
    22,
    20,
    32 + MediaQuery.of(context).padding.bottom,
  );

  // =========================================================
  // BUILD UTAMA
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _deepGreen,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: Colors.white,
          title: const Text(
            'Administrasi Pembayaran',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: IconButton(
                tooltip: 'Muat ulang',
                onPressed: () {
                  _fetchPayments();
                  _fetchSppConfig();
                  _fetchChain();
                },
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.10),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Tab bergaya segmented seperti pada referensi.
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                dividerColor: Colors.transparent,
                labelColor: _deepGreen,
                unselectedLabelColor: Colors.white.withValues(alpha: 0.70),
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                splashBorderRadius: BorderRadius.circular(14),
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                tabs: const [
                  _SegmentTab(icon: Icons.receipt_long_outlined, label: 'Tagihan'),
                  _SegmentTab(icon: Icons.add_card_outlined, label: 'Generate'),
                  _SegmentTab(icon: Icons.link_rounded, label: 'Chain Log'),
                ],
              ),
            ),

            // Lembar terang berisi konten setiap tab.
            Expanded(
              child: Container(
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  color: eloraBackground,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTagihanTab(),
                    _buildGenerateTab(),
                    _buildChainTab(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // TAB 1: TAGIHAN
  // =========================================================

  Widget _buildTagihanTab() {
    final groups = _studentGroups;
    final total = _payments.length;
    final paidCount = total - _unpaidCount;
    final progress = total == 0 ? 0.0 : paidCount / total;
    final pillText = total == 0
        ? 'Belum ada tagihan'
        : _unpaidCount == 0
        ? 'Semua lunas'
        : '$_unpaidCount belum lunas';

    return RefreshIndicator(
      color: eloraPrimary,
      onRefresh: _fetchPayments,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: _listPadding,
        children: [
          // Ringkasan utama: elemen terbesar di tab ini.
          _HeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'TOTAL TUNGGAKAN',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    _AccentPill(text: pillText),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _formatRupiah(_unpaidTotal),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(_accent),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$paidCount dari $total tagihan lunas',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          EloraSearchField(
            hintText: 'Cari nama, ID, institusi, atau periode',
            onChanged: (value) => setState(() => _searchQuery = value.trim()),
          ),
          const SizedBox(height: 12),

          // Filter status sebagai chip agar bisa dipilih dengan satu ketukan.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Semua', 'Belum Lunas', 'Lunas'].map((f) {
              final selected = _statusFilter == f;
              return ChoiceChip(
                label: Text(f),
                selected: selected,
                showCheckmark: false,
                onSelected: (_) => setState(() => _statusFilter = f),
                selectedColor: eloraPrimary,
                backgroundColor: Colors.white,
                side: BorderSide(color: selected ? eloraPrimary : _fieldBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : eloraDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),

          if (_isLoadingPayments)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(color: eloraPrimary),
              ),
            )
          else if (_filteredPayments.isEmpty)
            _EmptyState(
              icon: Icons.receipt_long_outlined,
              message: _payments.isEmpty
                  ? 'Belum ada tagihan.\nGenerate SPP terlebih dahulu.'
                  : 'Tidak ada hasil yang cocok.',
              actionLabel: _payments.isEmpty ? 'Generate SPP' : null,
              actionIcon: Icons.add_card_outlined,
              onAction: () => _tabController.animateTo(1),
            )
          else ...[
            Row(
              children: [
                Expanded(child: _sectionTitle('Daftar Siswa')),
                EloraStatusBadge(
                  label: '${groups.length} siswa',
                  color: eloraPrimary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...groups.map(_buildStudentCard),
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

    final nama = student['nama']?.toString() ?? '-';
    final initial = nama.trim().isEmpty ? '?' : nama.trim()[0].toUpperCase();

    return _Panel(
      margin: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: eloraPrimary.withValues(alpha: 0.10),
            child: Text(
              initial,
              style: const TextStyle(
                color: eloraPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          title: Text(
            nama,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: eloraDark,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student['student_id']?.toString() ?? '-',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                Text(
                  student['institution']?.toString() ?? '-',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _badge('${bills.length} tagihan', eloraPrimary),
                    _badge(
                      '${unpaid.length} belum lunas',
                      unpaid.isNotEmpty ? Colors.orange : Colors.green,
                    ),
                  ],
                ),
                if (unpaid.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Tunggakan: ${_formatRupiah(outstanding)}',
                    style: const TextStyle(
                      color: eloraPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
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
    final isPartial = bill['status'] == 'partial';
    final statusColor = isPaid ? Colors.green : Colors.orange;
    final statusLabel = isPaid
        ? 'Lunas'
        : isPartial
        ? 'Sebagian'
        : 'Belum Lunas';
    final period =
        bill['period']?.toString() ??
        '${bill['billing_year'] ?? ''}-${bill['billing_month'] ?? ''}';

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _fieldBorder),
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
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: eloraDark,
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
              _badge(statusLabel, statusColor),
            ],
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          // Aksi utama (menandai lunas) dibuat solid, aksi pembatalan dibuat outline.
          SizedBox(
            width: double.infinity,
            child: isPaid
                ? OutlinedButton.icon(
                    onPressed: _isUpdating
                        ? null
                        : () => _updatePaymentStatus(bill),
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    label: const Text('Batalkan Lunas'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: eloraPrimary,
                      minimumSize: const Size.fromHeight(44),
                      side: const BorderSide(color: eloraPrimary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: _isUpdating
                        ? null
                        : () => _updatePaymentStatus(bill),
                    icon: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 18,
                    ),
                    label: const Text('Tandai Lunas'),
                    style: FilledButton.styleFrom(
                      backgroundColor: eloraPrimary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // TAB 2: GENERATE SPP
  // =========================================================

  Widget _buildGenerateTab() {
    return ListView(
      padding: _listPadding,
      children: [
        _sectionTitle('Konfigurasi SPP'),
        const SizedBox(height: 4),
        _hint('Nominal dan hari jatuh tempo yang dipakai untuk tagihan baru.'),
        const SizedBox(height: 14),
        _Panel(
          padding: const EdgeInsets.all(16),
          child: _isLoadingConfig
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: CircularProgressIndicator(color: eloraPrimary),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('NOMINAL SPP'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      enabled: !_isSavingConfig,
                      decoration: _inputDeco('Contoh: 500000', prefix: 'Rp '),
                    ),
                    const SizedBox(height: 16),
                    _buildLabel('HARI JATUH TEMPO (1 SAMPAI 28)'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _dueDayController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      enabled: !_isSavingConfig,
                      decoration: _inputDeco('Contoh: 10'),
                    ),
                    const SizedBox(height: 18),
                    // Aksi sekunder: outline, agar tombol Generate tetap dominan.
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isSavingConfig ? null : _saveSppConfig,
                        icon: _isSavingConfig
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: eloraPrimary,
                                ),
                              )
                            : const Icon(Icons.save_outlined, size: 18),
                        label: const Text('Simpan Konfigurasi'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: eloraPrimary,
                          minimumSize: const Size.fromHeight(46),
                          side: const BorderSide(color: eloraPrimary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),

        const SizedBox(height: 28),

        _sectionTitle('Generate Tagihan Bulan Baru'),
        const SizedBox(height: 4),
        _hint(
          'Tagihan SPP dibuat untuk semua siswa aktif pada bulan yang dipilih. '
          'Siswa yang sudah punya tagihan di bulan tersebut otomatis di-skip.',
        ),
        const SizedBox(height: 14),
        _Panel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('BULAN'),
                        const SizedBox(height: 8),
                        _buildDropdown(
                          value: _genMonth,
                          items: List.generate(12, (i) => i + 1),
                          labelOf: _monthName,
                          onChanged: _isGenerating
                              ? null
                              : (v) => setState(() => _genMonth = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('TAHUN'),
                        const SizedBox(height: 8),
                        _buildDropdown(
                          value: _genYear,
                          items: List.generate(
                            5,
                            (i) => DateTime.now().year - 1 + i,
                          ),
                          labelOf: (y) => '$y',
                          onChanged: _isGenerating
                              ? null
                              : (v) => setState(() => _genYear = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _summaryTile('Nominal', _formatRupiah(_sppAmount)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _summaryTile('Jatuh Tempo', 'Tanggal $_sppDueDay'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Aksi utama halaman ini.
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
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
                  style: FilledButton.styleFrom(
                    backgroundColor: eloraPrimary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================
  // TAB 3: CHAIN LOG
  // =========================================================

  Widget _buildChainTab() {
    final blocks = _chainBlocks.reversed.toList();

    final statusText = _chainValid
        ? 'Rantai valid, semua blok terverifikasi'
        : _chainBlocks.isEmpty
        ? 'Belum ada blok dalam rantai'
        : 'Ditemukan ketidaksesuaian pada rantai';
    final statusIcon = _chainValid
        ? Icons.verified_rounded
        : _chainBlocks.isEmpty
        ? Icons.link_rounded
        : Icons.warning_rounded;
    final statusColor = _chainValid
        ? Colors.lightGreenAccent
        : Colors.orangeAccent;

    return RefreshIndicator(
      color: eloraPrimary,
      onRefresh: _fetchChain,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: _listPadding,
        children: [
          _HeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.link_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Blockchain SPP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_chainBlocks.length} blok tercatat dengan SHA-256',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.70),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, color: statusColor, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          statusText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          if (_isLoadingChain)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(color: eloraPrimary),
              ),
            )
          else if (_chainError != null)
            _EmptyState(
              icon: Icons.cloud_off_rounded,
              message: _chainError!,
              isError: true,
              actionLabel: 'Coba Lagi',
              actionIcon: Icons.refresh_rounded,
              onAction: _fetchChain,
            )
          else if (_chainBlocks.isEmpty)
            const _EmptyState(
              icon: Icons.link_rounded,
              message: 'Belum ada riwayat perubahan status SPP.',
            )
          else ...[
            _sectionTitle('Riwayat Perubahan'),
            const SizedBox(height: 14),
            for (var i = 0; i < blocks.length; i++)
              _buildChainBlockCard(blocks[i], isLast: i == blocks.length - 1),
          ],

          if (!_isLoadingChain) ...[
            const SizedBox(height: 8),
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

  Widget _buildChainBlockCard(Map<String, dynamic> b, {required bool isLast}) {
    final oldStatus = b['old_status']?.toString() ?? '';
    final newStatus = b['new_status']?.toString() ?? '';
    final blockHash = b['block_hash']?.toString() ?? '';
    final shortHash = blockHash.length > 8
        ? blockHash.substring(0, 8)
        : blockHash;
    final isValid = b['is_valid'] == true;
    final dotColor = isValid ? eloraPrimary : Colors.orange;

    // Tata letak timeline: garis dan titik di kiri, kartu di kanan.
    return Stack(
      children: [
        if (!isLast)
          Positioned(
            left: 6,
            top: 16,
            bottom: 0,
            child: Container(
              width: 2,
              color: eloraPrimary.withValues(alpha: 0.18),
            ),
          ),
        Positioned(
          left: 0,
          top: 6,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
              border: Border.all(color: eloraBackground, width: 3),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 28, bottom: 14),
          child: _Panel(
            padding: const EdgeInsets.all(14),
            borderColor: isValid
                ? _fieldBorder
                : Colors.orange.withValues(alpha: 0.45),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: eloraPrimary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#${b['block_index'] ?? '-'}',
                        style: const TextStyle(
                          color: eloraPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        b['period']?.toString() ?? '-',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: eloraDark,
                        ),
                      ),
                    ),
                    Icon(
                      isValid
                          ? Icons.verified_rounded
                          : Icons.warning_amber_rounded,
                      color: dotColor,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _badge(
                      _labelStatus(oldStatus),
                      oldStatus == 'paid' ? Colors.green : Colors.orange,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: Colors.black45,
                      ),
                    ),
                    _badge(
                      _labelStatus(newStatus),
                      newStatus == 'paid' ? Colors.green : Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${b['nama'] ?? '-'} (${b['student_id'] ?? '-'})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: eloraDark,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _detailItem(
                        'Admin',
                        b['changed_by_name']?.toString() ?? '-',
                      ),
                    ),
                    Expanded(
                      child: _detailItem(
                        'Waktu',
                        b['timestamp']?.toString() ?? '-',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        blockHash.isEmpty ? 'Hash: -' : 'Hash: $shortHash...',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Colors.black45,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Salin hash',
                      onPressed: blockHash.isEmpty
                          ? null
                          : () async {
                              await Clipboard.setData(
                                ClipboardData(text: blockHash),
                              );
                              if (!mounted) return;
                              _showSnack('Hash blok disalin.');
                            },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 16,
                      color: Colors.black45,
                      icon: const Icon(Icons.copy_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // KOMPONEN KECIL
  // =========================================================

  Widget _sectionTitle(String title) {
    return EloraSectionHeader(title: title);
  }

  Widget _badge(String label, Color color) {
    return EloraStatusBadge(label: label, color: color);
  }

  Widget _hint(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
    );
  }

  Widget _detailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: eloraDark,
          ),
        ),
      ],
    );
  }

  Widget _summaryTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: eloraPrimary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: eloraPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Colors.grey.shade500,
      ),
    );
  }

  Widget _buildDropdown({
    required int value,
    required List<int> items,
    required String Function(int) labelOf,
    required ValueChanged<int>? onChanged,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _fieldBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          style: const TextStyle(
            fontSize: 13,
            color: eloraDark,
            fontWeight: FontWeight.w600,
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<int>(
                  value: item,
                  child: Text(labelOf(item)),
                ),
              )
              .toList(),
          onChanged: onChanged == null
              ? null
              : (v) {
                  if (v != null) onChanged(v);
                },
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, {String? prefix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
      prefixText: prefix,
      prefixStyle: const TextStyle(
        color: eloraDark,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: eloraPrimary, width: 1.4),
      ),
    );
  }
}

// =========================================================
// WIDGET PRIVAT: TAB SEGMENTED
// =========================================================

class _SegmentTab extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SegmentTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 42,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// WIDGET PRIVAT: KARTU HERO (GRADIEN)
// =========================================================

class _HeroCard extends StatelessWidget {
  final Widget child;

  const _HeroCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final light = Color.lerp(eloraPrimary, Colors.black, 0.18)!;
    final dark = Color.lerp(eloraPrimary, Colors.black, 0.52)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [light, dark],
        ),
        boxShadow: [
          BoxShadow(
            color: eloraPrimary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -46,
            top: -58,
            child: _circle(170, Colors.white.withValues(alpha: 0.06)),
          ),
          Positioned(
            left: -50,
            bottom: -84,
            child: _circle(160, Colors.white.withValues(alpha: 0.05)),
          ),
          child,
        ],
      ),
    );
  }

  static Widget _circle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

// =========================================================
// WIDGET PRIVAT: PIL AKSEN
// =========================================================

class _AccentPill extends StatelessWidget {
  final String text;

  const _AccentPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _accent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: _deepGreen,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// =========================================================
// WIDGET PRIVAT: PANEL PUTIH
// =========================================================

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color borderColor;

  const _Panel({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.borderColor = _fieldBorder,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      // Material dipakai agar efek ripple ExpansionTile tetap terlihat.
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: borderColor),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

// =========================================================
// WIDGET PRIVAT: STATE KOSONG DAN ERROR
// =========================================================

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool isError;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.message,
    this.isError = false,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: eloraPrimary.withValues(alpha: 0.08),
            ),
            child: Icon(icon, size: 34, color: eloraPrimary),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              height: 1.4,
              color: isError ? Colors.red.shade700 : eloraDark,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAction,
              icon: Icon(actionIcon ?? Icons.arrow_forward_rounded, size: 18),
              label: Text(actionLabel!),
              style: FilledButton.styleFrom(
                backgroundColor: eloraPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}