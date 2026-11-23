import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:elora_school/theme/colors.dart';

class CurrencyPage extends StatefulWidget {
  const CurrencyPage({super.key});

  @override
  State<CurrencyPage> createState() => _CurrencyPageState();
}

class _CurrencyPageState extends State<CurrencyPage> {
  final TextEditingController amountController = TextEditingController(
    text: '100000',
  );

  static const List<Map<String, dynamic>> _fallbackCurrencies = [
    {'code': 'IDR', 'name': 'Indonesian Rupiah', 'rate': 1.0},
    {'code': 'USD', 'name': 'US Dollar', 'rate': 16000.0},
    {'code': 'EUR', 'name': 'Euro', 'rate': 17500.0},
    {'code': 'GBP', 'name': 'British Pound', 'rate': 20500.0},
    {'code': 'JPY', 'name': 'Japanese Yen', 'rate': 107.0},
    {'code': 'SGD', 'name': 'Singapore Dollar', 'rate': 12000.0},
    {'code': 'AUD', 'name': 'Australian Dollar', 'rate': 10500.0},
    {'code': 'CNY', 'name': 'Chinese Yuan', 'rate': 2200.0},
    {'code': 'SAR', 'name': 'Saudi Riyal', 'rate': 4300.0},
    {'code': 'MYR', 'name': 'Malaysian Ringgit', 'rate': 3700.0},
  ];

  List<Map<String, dynamic>> _currencies = _fallbackCurrencies;
  bool _isLoadingRates = false;
  String? _ratesError;
  DateTime? _ratesLastUpdated;

  String fromCurrency = 'IDR';
  String toCurrency = 'USD';
  double? result;

  @override
  void initState() {
    super.initState();
    _fetchRates();
  }

  Future<void> _fetchRates() async {
    setState(() {
      _isLoadingRates = true;
      _ratesError = null;
    });
    try {
      final response = await http
          .get(Uri.parse('https://open.er-api.com/v6/latest/IDR'))
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body);
      if (decoded['result'] == 'success') {
        final Map<String, dynamic> rawRates = Map<String, dynamic>.from(
          decoded['rates'],
        );
        final updated = <Map<String, dynamic>>[];
        const wantedCodes = [
          'IDR',
          'USD',
          'EUR',
          'GBP',
          'JPY',
          'SGD',
          'AUD',
          'CNY',
          'SAR',
          'MYR',
        ];
        const names = {
          'IDR': 'Indonesian Rupiah',
          'USD': 'US Dollar',
          'EUR': 'Euro',
          'GBP': 'British Pound',
          'JPY': 'Japanese Yen',
          'SGD': 'Singapore Dollar',
          'AUD': 'Australian Dollar',
          'CNY': 'Chinese Yuan',
          'SAR': 'Saudi Riyal',
          'MYR': 'Malaysian Ringgit',
        };
        for (final code in wantedCodes) {
          final apiRate = (rawRates[code] as num?)?.toDouble();
          if (apiRate == null || apiRate == 0) continue;

          final rateInIdr = code == 'IDR' ? 1.0 : 1.0 / apiRate;
          updated.add({
            'code': code,
            'name': names[code] ?? code,
            'rate': rateInIdr,
          });
        }
        if (updated.isNotEmpty) {
          setState(() {
            _currencies = updated;
            _ratesLastUpdated = DateTime.now();
            if (!updated.any((c) => c['code'] == fromCurrency)) {
              fromCurrency = 'IDR';
            }
            if (!updated.any((c) => c['code'] == toCurrency)) {
              toCurrency = 'USD';
            }
          });
        }
      } else {
        setState(() => _ratesError = 'Using offline rates.');
      }
    } catch (e) {
      debugPrint('CURRENCY RATE FETCH ERROR: $e');
      setState(() => _ratesError = 'Using offline rates.');
    } finally {
      setState(() => _isLoadingRates = false);
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  void convertCurrency() {
    final amount = double.tryParse(
      amountController.text.replaceAll(',', '').trim(),
    );

    if (amount == null || amount < 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid amount.')));
      return;
    }

    final fromRate =
        _currencies.firstWhere(
              (currency) => currency['code'] == fromCurrency,
            )['rate']
            as double;

    final toRate =
        _currencies.firstWhere(
              (currency) => currency['code'] == toCurrency,
            )['rate']
            as double;

    setState(() {
      result = amount * fromRate / toRate;
    });
  }

  void swapCurrencies() {
    setState(() {
      final temp = fromCurrency;
      fromCurrency = toCurrency;
      toCurrency = temp;
      result = null;
    });
  }

  String formatAmount(double amount) {
    return amount.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: eloraBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 28),
              _buildIntro(),
              const SizedBox(height: 24),
              _buildConverterCard(),
              const SizedBox(height: 20),
              _buildCurrencyInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: eloraDark,
        ),
        const Expanded(
          child: Text(
            'Currency Converter',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: eloraDark,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Refresh rates',
          onPressed: _isLoadingRates ? null : _fetchRates,
          icon: _isLoadingRates
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: eloraPrimary,
                  ),
                )
              : const Icon(Icons.refresh_rounded, color: eloraPrimary),
        ),
        const Icon(
          Icons.currency_exchange_rounded,
          color: eloraPrimary,
          size: 25,
        ),
      ],
    );
  }

  Widget _buildIntro() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Convert your currency',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: eloraDark,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Check estimated currency conversions in one place.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildConverterCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Amount',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: eloraDark,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'Enter amount',
              filled: true,
              fillColor: eloraBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'From',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: eloraDark,
            ),
          ),
          const SizedBox(height: 8),
          _buildCurrencyDropdown(
            value: fromCurrency,
            onChanged: (value) {
              setState(() {
                fromCurrency = value!;
                result = null;
              });
            },
          ),
          Center(
            child: IconButton(
              onPressed: swapCurrencies,
              icon: const Icon(
                Icons.swap_vert_rounded,
                color: eloraPrimary,
                size: 28,
              ),
            ),
          ),
          const Text(
            'To',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: eloraDark,
            ),
          ),
          const SizedBox(height: 8),
          _buildCurrencyDropdown(
            value: toCurrency,
            onChanged: (value) {
              setState(() {
                toCurrency = value!;
                result = null;
              });
            },
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: convertCurrency,
              style: ElevatedButton.styleFrom(
                backgroundColor: eloraPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Convert Currency',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (result != null) ...[
            const SizedBox(height: 22),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: eloraPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Converted Amount',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$toCurrency ${formatAmount(result!)}',
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: eloraPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrencyDropdown({
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: eloraBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: _currencies.map((currency) {
            return DropdownMenuItem<String>(
              value: currency['code'] as String,
              child: Text(
                '${currency['code']} - ${currency['name']}',
                style: const TextStyle(fontSize: 12),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildCurrencyInfo() {
    String infoText;
    if (_isLoadingRates) {
      infoText = 'Loading live rates…';
    } else if (_ratesError != null) {
      infoText = 'Using offline rates. Tap refresh to retry.';
    } else if (_ratesLastUpdated != null) {
      final h = _ratesLastUpdated!.hour.toString().padLeft(2, '0');
      final m = _ratesLastUpdated!.minute.toString().padLeft(2, '0');
      infoText = 'Live rates from open.er-api.com. Last updated: $h:$m';
    } else {
      infoText = 'Exchange rates are updated on load.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: eloraPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              infoText,
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          if (_ratesError != null)
            TextButton(onPressed: _fetchRates, child: const Text('Retry')),
        ],
      ),
    );
  }
}
