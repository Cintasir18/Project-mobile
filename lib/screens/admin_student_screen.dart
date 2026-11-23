
import 'package:flutter/material.dart';

import 'package:elora_school/theme/colors.dart';
import 'package:elora_school/services/student_service.dart';

class AdminStudentPage extends StatefulWidget {
  const AdminStudentPage({super.key});

  @override
  State<AdminStudentPage> createState() => _AdminStudentPageState();
}

class _AdminStudentPageState extends State<AdminStudentPage> {

  List<Map<String, dynamic>> _students = [];
  bool _loading = true;
  bool _updating = false;
  String _query = '';
  String _filter = 'Semua';

  @override
  void initState() {
    super.initState();
    fetchStudents();
  }


  Future<void> fetchStudents() async {
    if (mounted) setState(() => _loading = true);
    try {
      final data = await StudentService.instance.listStudents();
      if (!mounted) return;
      setState(() => _students = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat data siswa: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredStudents {
    return _students.where((student) {
      final q = _query.toLowerCase();

      final name = '${student['nama'] ?? ''}'.toLowerCase();
      final id = '${student['student_id'] ?? ''}'.toLowerCase();
      final email = '${student['email'] ?? ''}'.toLowerCase();
      final institution = '${student['institution'] ?? ''}'.toLowerCase();

      final matchesQuery =
          name.contains(q) ||
          id.contains(q) ||
          email.contains(q) ||
          institution.contains(q);

      final active =
          student['is_active'] == 1 ||
          student['is_active'] == true ||
          student['is_active'] == '1';

      final matchesFilter =
          _filter == 'Semua' ||
          (_filter == 'Aktif' && active) ||
          (_filter == 'Nonaktif' && !active);

      return matchesQuery && matchesFilter;
    }).toList();
  }

  bool _isActive(Map<String, dynamic> student) {
    return student['is_active'] == 1 ||
        student['is_active'] == true ||
        student['is_active'] == '1';
  }

  Future<void> _changeStatus(Map<String, dynamic> student) async {
    if (_updating) return;

    final active = _isActive(student);
    final newStatus = active ? 0 : 1;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(active ? 'Nonaktifkan Akun?' : 'Aktifkan Akun?'),
        content: Text(
          'Apakah kamu yakin ingin ${active ? 'menonaktifkan' : 'mengaktifkan'} '
          'akun ${student['nama'] ?? 'siswa ini'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(active ? 'Nonaktifkan' : 'Aktifkan'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _updating = true);

    try {
      await StudentService.instance.setActive(student['id'].toString(), newStatus == 1);
      await fetchStudents();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status akun berhasil diperbarui.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal mengubah status: $e')));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _students.where(_isActive).length;
    final inactiveCount = _students.length - activeCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Data Siswa',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : fetchStudents,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: fetchStudents,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    'Total Siswa',
                    '${_students.length}',
                    Icons.people_alt_outlined,
                    eloraPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _summaryCard(
                    'Aktif',
                    '$activeCount',
                    Icons.check_circle_outline,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _summaryCard(
                    'Nonaktif',
                    '$inactiveCount',
                    Icons.block_outlined,
                    Colors.redAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: InputDecoration(
                hintText: 'Cari nama, ID, email, atau institusi',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _filter,
              decoration: InputDecoration(
                labelText: 'Status Akun',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'Semua', child: Text('Semua Siswa')),
                DropdownMenuItem(value: 'Aktif', child: Text('Akun Aktif')),
                DropdownMenuItem(
                  value: 'Nonaktif',
                  child: Text('Akun Nonaktif'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _filter = value);
              },
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filteredStudents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline_rounded,
                      size: 56,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Data siswa tidak ditemukan',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )
            else ...[
              Text(
                '${_filteredStudents.length} siswa ditemukan',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              ..._filteredStudents.map(_studentCard),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _studentCard(Map<String, dynamic> student) {
    final active = _isActive(student);
    final statusColor = active ? Colors.green : Colors.redAccent;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: eloraPrimary.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: eloraPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${student['nama'] ?? '-'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('ID: ${student['student_id'] ?? '-'}'),
                      Text('${student['email'] ?? '-'}'),
                      Text('${student['institution'] ?? '-'}'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    active ? 'Aktif' : 'Nonaktif',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _updating ? null : () => _changeStatus(student),
                  icon: Icon(
                    active ? Icons.block_outlined : Icons.check_circle_outline,
                  ),
                  label: Text(active ? 'Nonaktifkan' : 'Aktifkan'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
