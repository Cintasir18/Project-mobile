
import 'package:flutter/material.dart';

import 'package:elora_school/theme/colors.dart';
import 'package:elora_school/services/payment_service.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {

  String selectedYear = DateTime.now().year.toString();

  List<Map<String, dynamic>> paymentHistory = [];
  bool isLoading = true;
  String? errorMessage;

  List<Map<String, dynamic>> _chainBlocks = [];
  bool _isLoadingChain = false;
  bool _chainValid = false;
  String? _chainError;

  @override
  void initState() {
    super.initState();
    fetchPayments();
    _fetchChain();
  }

  Future<void> _fetchChain() async {
    if (mounted) setState(() { _isLoadingChain = true; _chainError = null; });
    try {
      final body = await PaymentService.instance.fetchChain();
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

  Future<void> _refreshAll() async {
    await Future.wait([fetchPayments(), _fetchChain()]);
  }

  Future<void> fetchPayments() async {
    if (mounted) setState(() { isLoading = true; errorMessage = null; });
    try {
      final data = await PaymentService.instance.myPayments();
      final parsedPayments = data.map<Map<String, dynamic>>((item) {
        final period = item['period'].toString();
        final parts = period.split('-');
        final year = parts.isNotEmpty ? parts[0] : '';
        final monthNumber = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
        final status = item['status'].toString().toLowerCase();
        final isPaid = status == 'paid';
        final amount = double.tryParse(item['amount'].toString()) ?? 0;
        return {
          'id': item['id'], 'period': period, 'year': year,
          'monthNumber': monthNumber, 'month': _formatMonth(monthNumber, year),
          'amountValue': amount, 'amount': _formatCurrency(amount),
          'status': isPaid ? 'Paid' : 'Unpaid', 'isPaid': isPaid,
          'dueDate': item['due_date']?.toString() ?? '', 'paidAt': item['paid_at']?.toString(),
        };
      }).toList();
      if (!mounted) return;
      setState(() {
        paymentHistory = parsedPayments;
        final years = parsedPayments.map((p) => p['year'].toString()).toSet().toList()..sort((a,b) => b.compareTo(a));
        if (years.isNotEmpty && !years.contains(selectedYear)) selectedYear = years.first;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { errorMessage = e.toString().replaceFirst('Exception: ', ''); isLoading = false; });
    }
  }

  String _formatMonth(int month, String year) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    if (month < 1 || month > 12) return year;
    return '${months[month - 1]} $year';
  }

  String _formatCurrency(double amount) {
    final value = amount.round().toString();
    final formatted = value.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
    return 'Rp $formatted';
  }

  List<Map<String, dynamic>> get filteredPayments {
    final result = paymentHistory
        .where((payment) => payment['year'].toString() == selectedYear)
        .toList();

    result.sort(
      (a, b) => b['period'].toString().compareTo(a['period'].toString()),
    );

    return result;
  }

  double get outstandingAmount {
    return paymentHistory
        .where((payment) => payment['isPaid'] != true)
        .fold<double>(
          0,
          (total, payment) => total + (payment['amountValue'] as double),
        );
  }

  int get unpaidCount {
    return paymentHistory.where((payment) => payment['isPaid'] != true).length;
  }

  List<String> get availableYears {
    final years =
        paymentHistory
            .map((payment) => payment['year'].toString())
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

    if (!years.contains(selectedYear)) {
      years.insert(0, selectedYear);
    }

    return years;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: eloraBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                color: eloraPrimary,
                onRefresh: _refreshAll,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCard(),
                      const SizedBox(height: 26),
                      _buildFilter(),
                      const SizedBox(height: 20),
                      _buildHistorySection(),
                      const SizedBox(height: 26),
                      _buildInformationCard(),
                      const SizedBox(height: 20),
                      _buildChainSection(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: eloraDark,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment & Administration',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: eloraDark,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'View your payment status and history',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh_rounded, color: eloraPrimary),
            tooltip: 'Refresh payments',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: eloraPrimary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: eloraPrimary.withValues(alpha: 0.18),
            blurRadius: 15,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Payment Status',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  unpaidCount > 0 ? 'Action needed' : 'All settled',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Outstanding',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 5),
          Text(
            _formatCurrency(outstandingAmount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '$unpaidCount ${unpaidCount == 1 ? 'month' : 'months'} unpaid',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFilter() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Payment History',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: eloraDark,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: availableYears.contains(selectedYear)
                  ? selectedYear
                  : availableYears.first,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              style: const TextStyle(
                color: eloraDark,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              items: availableYears.map((year) {
                return DropdownMenuItem(value: year, child: Text(year));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedYear = value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection() {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(35),
        child: Center(child: CircularProgressIndicator(color: eloraPrimary)),
      );
    }

    if (errorMessage != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 36, color: Colors.grey),
            const SizedBox(height: 10),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: fetchPayments,
              style: ElevatedButton.styleFrom(
                backgroundColor: eloraPrimary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    final payments = filteredPayments;

    if (payments.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 38, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              'No payment records for this year.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(children: payments.map(_buildPaymentItem).toList());
  }

  Widget _buildPaymentItem(Map<String, dynamic> payment) {
    final bool isPaid = payment['isPaid'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: eloraCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isPaid
                  ? Colors.green.withValues(alpha: 0.10)
                  : Colors.orange.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPaid
                  ? Icons.check_circle_outline_rounded
                  : Icons.schedule_rounded,
              color: isPaid ? Colors.green : Colors.orange,
              size: 21,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment['month'].toString(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: eloraDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  payment['amount'].toString(),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                if (payment['dueDate'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Due: ${payment['dueDate']}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isPaid
                  ? Colors.green.withValues(alpha: 0.10)
                  : Colors.orange.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              payment['status'].toString(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isPaid ? Colors.green : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: eloraPrimary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: eloraPrimary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Information',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: eloraDark,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Payment status is updated by the administration.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: Colors.grey,
                  ),
                ),
              ],
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

  Widget _buildChainSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        leading: const Icon(Icons.verified_outlined, color: eloraPrimary),
        title: const Text(
          'Riwayat Administrasi Terverifikasi',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: eloraDark,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isLoadingChain)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      (_chainBlocks.isEmpty
                              ? Colors.grey
                              : _chainValid
                              ? Colors.green
                              : Colors.orange)
                          .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _chainBlocks.isEmpty
                      ? 'Belum ada data'
                      : _chainValid
                      ? 'Chain Valid'
                      : 'Chain Error',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _chainBlocks.isEmpty
                        ? Colors.grey
                        : _chainValid
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildChainContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildChainContent() {
    if (_isLoadingChain) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: CircularProgressIndicator(color: eloraPrimary, strokeWidth: 2),
        ),
      );
    }

    if (_chainError != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          _chainError!,
          style: const TextStyle(color: Colors.red, fontSize: 12),
        ),
      );
    }

    if (_chainBlocks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'Belum ada riwayat perubahan.',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._chainBlocks.reversed.map((b) => _buildChainBlockTile(b)),
        const SizedBox(height: 10),
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
                  fontSize: 10,
                  color: Colors.black45,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChainBlockTile(Map<String, dynamic> b) {
    final oldStatus = b['old_status']?.toString() ?? '';
    final newStatus = b['new_status']?.toString() ?? '';
    final blockHash = b['block_hash']?.toString() ?? '';
    final shortHash = blockHash.length > 8
        ? blockHash.substring(0, 8)
        : blockHash;
    final isValid = b['is_valid'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: eloraBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: eloraPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${b['block_index'] ?? '-'}',
                        style: const TextStyle(
                          color: eloraPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      b['period']?.toString() ?? '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: eloraDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_labelStatus(oldStatus)} → ${_labelStatus(newStatus)}',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(height: 2),
                Text(
                  'Oleh: ${b['changed_by_name'] ?? '-'}',
                  style: const TextStyle(fontSize: 10, color: Colors.black45),
                ),
                Text(
                  b['timestamp']?.toString() ?? '-',
                  style: const TextStyle(fontSize: 10, color: Colors.black45),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hash: $shortHash...',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.black45,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isValid ? Icons.verified_rounded : Icons.warning_amber_rounded,
            size: 16,
            color: isValid ? eloraPrimary : Colors.orange,
          ),
        ],
      ),
    );
  }
}
