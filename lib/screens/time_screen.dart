import 'package:flutter/material.dart';
import 'package:elora_school/widgets/elora_components.dart';

import 'package:elora_school/theme/colors.dart';

class TimePage extends StatefulWidget {
  const TimePage({super.key});

  @override
  State<TimePage> createState() => _TimePageState();
}

class _TimePageState extends State<TimePage> {
  TimeOfDay selectedTime = TimeOfDay.now();
  String selectedZone = 'WIB';

  final List<Map<String, dynamic>> zones = [
    {
      'name': 'WIB',
      'location': 'Western Indonesia',
      'offset': 7,
      'icon': Icons.location_on_outlined,
    },
    {
      'name': 'WITA',
      'location': 'Central Indonesia',
      'offset': 8,
      'icon': Icons.location_on_outlined,
    },
    {
      'name': 'WIT',
      'location': 'Eastern Indonesia',
      'offset': 9,
      'icon': Icons.location_on_outlined,
    },
    {
      'name': 'London',
      'location': 'United Kingdom',
      'offset': 0,
      'icon': Icons.language_rounded,
    },
  ];

  static DateTime _lastSundayUtc(int year, int month) {

    DateTime d = DateTime.utc(year, month + 1, 0);
    while (d.weekday != DateTime.sunday) {
      d = DateTime.utc(d.year, d.month, d.day - 1);
    }
    return DateTime.utc(year, d.month, d.day, 1);
  }

  static int _londonOffsetFor(DateTime utcInstant) {
    final bstStart = _lastSundayUtc(utcInstant.year, 3);
    final bstEnd = _lastSundayUtc(utcInstant.year, 10);
    return (utcInstant.isAfter(
              bstStart.subtract(const Duration(microseconds: 1)),
            ) &&
            utcInstant.isBefore(bstEnd))
        ? 1
        : 0;
  }

  int get sourceOffset {
    return zones.firstWhere((zone) => zone['name'] == selectedZone)['offset']
        as int;
  }

  String convertTime(int targetOffset) {
    final wibDateTime = DateTime.now().toUtc().add(const Duration(hours: 7));

    final sourceDateTime = DateTime(
      wibDateTime.year,
      wibDateTime.month,
      wibDateTime.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    final utcDateTime = sourceDateTime.subtract(Duration(hours: sourceOffset));

    final targetDateTime = utcDateTime.add(Duration(hours: targetOffset));

    final hour = targetDateTime.hour.toString().padLeft(2, '0');
    final minute = targetDateTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );

    if (picked != null) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    final londonOffset = _londonOffsetFor(DateTime.now().toUtc());
    for (final zone in zones) {
      if (zone['name'] == 'London') zone['offset'] = londonOffset;
    }

    return Scaffold(
      backgroundColor: eloraBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 25),
              _buildIntro(),
              const SizedBox(height: 22),
              _buildTimePicker(),
              const SizedBox(height: 25),
              const Text(
                'Converted Time',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: eloraDark,
                ),
              ),
              const SizedBox(height: 14),
              ...zones.map((zone) => _buildZoneCard(zone)),
              const SizedBox(height: 15),
              _buildInfo(),
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
            'Time Converter',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: eloraDark,
            ),
          ),
        ),
        const Icon(Icons.access_time_rounded, color: eloraPrimary, size: 25),
      ],
    );
  }

  Widget _buildIntro() {
    return const EloraSectionHeader(
      title: 'Time across locations',
      subtitle: 'Check the time in different time zones.',
    );
  }

  Widget _buildTimePicker() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: eloraPrimary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select source time',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedZone,
            dropdownColor: Colors.white,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            items: zones.map((zone) {
              return DropdownMenuItem<String>(
                value: zone['name'] as String,
                child: Text(zone['name'] as String),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  selectedZone = value;
                });
              }
            },
          ),
          const SizedBox(height: 15),
          InkWell(
            onTap: _pickTime,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white30),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedTime.format(context),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.edit_outlined,
                    color: Colors.white,
                    size: 19,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the time to change it',
            style: TextStyle(fontSize: 10, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneCard(Map<String, dynamic> zone) {
    final name = zone['name'] as String;
    final offset = zone['offset'] as int;
    final offsetLabel = 'UTC${offset >= 0 ? '+' : ''}$offset';
    final isSelected = name == selectedZone;

    return EloraCard(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(16),
      color: isSelected ? eloraPrimary.withValues(alpha: 0.08) : Colors.white,
      border: Border.all(
        color: isSelected
            ? eloraPrimary.withValues(alpha: 0.35)
            : Colors.grey.shade200,
      ),
      borderRadius: BorderRadius.circular(15),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: eloraPrimary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              zone['icon'] as IconData,
              color: eloraPrimary,
              size: 21,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: eloraDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${zone['location']} • $offsetLabel',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            convertTime(offset),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: eloraPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfo() {
    return EloraCard(
      padding: const EdgeInsets.all(15),
      borderRadius: BorderRadius.circular(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: eloraPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'London menerapkan British Summer Time (BST, UTC+1) dari '
              'Minggu terakhir Maret hingga Minggu terakhir Oktober, '
              'dan Greenwich Mean Time (GMT, UTC+0) di luar periode tersebut. '
              'Offset London dihitung otomatis berdasarkan tanggal hari ini.',
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
