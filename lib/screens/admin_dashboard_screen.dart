import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:elora_school/widgets/elora_components.dart';

import 'package:elora_school/theme/colors.dart';
import 'package:elora_school/services/auth_service.dart';
import 'package:elora_school/screens/login_screen.dart';
import 'package:elora_school/screens/admin_institution_screen.dart';
import 'package:elora_school/screens/admin_student_screen.dart';
import 'package:elora_school/screens/admin_payment_screen.dart';
import 'package:elora_school/screens/admin_notification_screen.dart';

const Color _accent = Color(0xFFF2B84B);

Color get _deepGreen => Color.lerp(eloraPrimary, Colors.black, 0.62)!;

class AdminDashboardPage extends StatelessWidget {
  final Map<String, dynamic> user;

  const AdminDashboardPage({super.key, required this.user});

  Future<void> _logout(BuildContext context) async {
    try {
      await AuthService.instance.signOut();
    } catch (e) {
      debugPrint('ELORA ADMIN LOGOUT ERROR: $e');
    }

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _open(BuildContext context, WidgetBuilder builder) {
    Navigator.push(context, MaterialPageRoute(builder: builder));
  }

  @override
  Widget build(BuildContext context) {
    final nama = user['nama']?.toString() ?? 'Admin';
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // Satu sumber data untuk akses cepat dan daftar menu,
    // sehingga judul, ikon, dan tujuan navigasi selalu konsisten.
    final menus = <_AdminMenu>[
      _AdminMenu(
        icon: Icons.location_city_rounded,
        shortLabel: 'Institusi',
        title: 'Kelola Institusi',
        subtitle: 'Tambah, ubah, dan nonaktifkan data institusi.',
        builder: (_) => const AdminInstitutionPage(),
      ),
      _AdminMenu(
        icon: Icons.people_alt_rounded,
        shortLabel: 'Siswa',
        title: 'Data Siswa',
        subtitle: 'Kelola data dan status akun siswa.',
        builder: (_) => const AdminStudentPage(),
      ),
      _AdminMenu(
        icon: Icons.receipt_long_rounded,
        shortLabel: 'Pembayaran',
        title: 'Administrasi Pembayaran',
        subtitle: 'Kelola data dan status pembayaran.',
        builder: (_) => const AdminPaymentPage(),
      ),
      _AdminMenu(
        icon: Icons.notifications_active_rounded,
        shortLabel: 'Notifikasi',
        title: 'Kirim Notifikasi',
        subtitle: 'Kirim push notification ke semua siswa.',
        builder: (_) => const AdminNotificationPage(),
      ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _deepGreen,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              // =====================================================
              // BAGIAN ATAS (GELAP): identitas dan akses cepat
              // =====================================================
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AdminHeader(
                        nama: nama,
                        onLogout: () => _logout(context),
                      ),
                      const SizedBox(height: 22),
                      _AdminHeroCard(nama: nama),
                      const SizedBox(height: 22),
                      Text(
                        'Akses Cepat',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          for (var i = 0; i < menus.length; i++) ...[
                            if (i > 0) const SizedBox(width: 10),
                            Expanded(
                              child: _QuickActionTile(
                                icon: menus[i].icon,
                                label: menus[i].shortLabel,
                                // Menu pertama diberi penekanan sebagai aksi utama.
                                highlight: i == 0,
                                onTap: () => _open(context, menus[i].builder),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // =====================================================
              // BAGIAN BAWAH (TERANG): daftar menu lengkap
              // =====================================================
              SliverFillRemaining(
                hasScrollBody: false,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 28 + bottomInset),
                  decoration: const BoxDecoration(
                    color: eloraBackground,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const EloraSectionHeader(title: 'Menu Administrasi'),
                      const SizedBox(height: 4),
                      Text(
                        'Selamat datang di panel administrasi ELORA.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (final menu in menus)
                        _AdminMenuCard(
                          icon: menu.icon,
                          title: menu.title,
                          subtitle: menu.subtitle,
                          onTap: () => _open(context, menu.builder),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================
// MODEL MENU
// =========================================================

class _AdminMenu {
  final IconData icon;
  final String shortLabel;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;

  const _AdminMenu({
    required this.icon,
    required this.shortLabel,
    required this.title,
    required this.subtitle,
    required this.builder,
  });
}

// =========================================================
// HEADER
// =========================================================

class _AdminHeader extends StatelessWidget {
  final String nama;
  final VoidCallback onLogout;

  const _AdminHeader({required this.nama, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          child: const Icon(
            Icons.admin_panel_settings_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selamat datang kembali',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                nama,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Logout',
          onPressed: onLogout,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.10),
            foregroundColor: Colors.white,
            fixedSize: const Size(46, 46),
          ),
          icon: const Icon(Icons.logout_rounded, size: 22),
        ),
      ],
    );
  }
}

// =========================================================
// KARTU UTAMA (GRADIEN)
// =========================================================

class _AdminHeroCard extends StatelessWidget {
  final String nama;

  const _AdminHeroCard({required this.nama});

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
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Lingkaran dekoratif di latar kartu.
          Positioned(
            right: -46,
            top: -58,
            child: _circle(170, Colors.white.withValues(alpha: 0.06)),
          ),
          Positioned(
            left: -50,
            bottom: -80,
            child: _circle(160, Colors.white.withValues(alpha: 0.05)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ELORA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                  ),
                  SizedBox(
                    width: 46,
                    height: 28,
                    child: Stack(
                      children: [
                        Positioned(left: 0, child: _circle(28, _accent)),
                        Positioned(
                          left: 17,
                          child: _circle(
                            28,
                            Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: 38,
                height: 28,
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  Icons.verified_user_rounded,
                  size: 16,
                  color: _deepGreen,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _heroField(label: 'PEMILIK AKUN', value: nama),
                  ),
                  const SizedBox(width: 12),
                  _heroField(
                    label: 'PERAN',
                    value: 'Administrator',
                    alignEnd: true,
                  ),
                ],
              ),
            ],
          ),
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

  static Widget _heroField({
    required String label,
    required String value,
    bool alignEnd = false,
  }) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// =========================================================
// TOMBOL AKSES CEPAT
// =========================================================

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = highlight ? _deepGreen : Colors.white;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: highlight
          ? BorderSide.none
          : BorderSide(color: Colors.white.withValues(alpha: 0.10)),
    );

    return Material(
      color: highlight ? _accent : Colors.white.withValues(alpha: 0.08),
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foreground,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================
// KARTU MENU (MEMAKAI EloraCard)
// =========================================================

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
    return EloraCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: eloraPrimary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: eloraPrimary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: eloraDark,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: eloraPrimary),
        ],
      ),
    );
  }
}