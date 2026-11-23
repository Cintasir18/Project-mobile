import 'package:flutter/material.dart';

import 'package:elora_school/theme/colors.dart';
import 'package:elora_school/services/auth_service.dart';
import 'package:elora_school/screens/login_screen.dart';
import 'package:elora_school/screens/admin_institution_screen.dart';
import 'package:elora_school/screens/admin_student_screen.dart';
import 'package:elora_school/screens/admin_payment_screen.dart';
import 'package:elora_school/screens/admin_notification_screen.dart';

class AdminDashboardPage extends StatelessWidget {
  final Map<String, dynamic> user;

  const AdminDashboardPage({super.key, required this.user});

  Future<void> _logout(BuildContext context) async {
    try { await AuthService.instance.signOut(); } catch (e) { debugPrint('ELORA ADMIN LOGOUT ERROR: $e'); }
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nama = user['nama']?.toString() ?? 'Admin';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: eloraPrimary,
        foregroundColor: Colors.white,
        title: const Text(
          'Dashboard Admin',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: eloraPrimary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.white,
                  size: 42,
                ),
                const SizedBox(height: 16),
                Text(
                  'Halo, $nama!',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Selamat datang di panel administrasi ELORA.',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Menu Administrasi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: eloraDark,
            ),
          ),
          const SizedBox(height: 12),
          _AdminMenuCard(
            icon: Icons.location_city_rounded,
            title: 'Kelola Institusi',
            subtitle: 'Tambah, ubah, dan nonaktifkan data institusi.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminInstitutionPage()),
              );
            },
          ),
          const SizedBox(height: 12),
          _AdminMenuCard(
            icon: Icons.people_alt_rounded,
            title: 'Data Siswa',
            subtitle: 'Kelola data dan status akun siswa.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminStudentPage()),
              );
            },
          ),
          const SizedBox(height: 12),
          _AdminMenuCard(
            icon: Icons.receipt_long_rounded,
            title: 'Administrasi Pembayaran',
            subtitle: 'Kelola data dan status pembayaran.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminPaymentPage()),
              );
            },
          ),
          const SizedBox(height: 12),
          _AdminMenuCard(
            icon: Icons.notifications_active_rounded,
            title: 'Kirim Notifikasi',
            subtitle: 'Kirim push notification ke semua siswa.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminNotificationPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Keluar dari Akun'),
            style: OutlinedButton.styleFrom(
              foregroundColor: eloraPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminMenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: eloraPrimary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: eloraPrimary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
