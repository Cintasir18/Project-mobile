import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:elora_school/theme/colors.dart';
import 'package:elora_school/services/auth_service.dart';
import 'package:elora_school/screens/login_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? profile;
  bool isLoading = true;
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final result = await AuthService.instance.currentProfile();
      if (!mounted) return;
      setState(() {
        profile = result;
        _photoPath = result['avatar_url']?.toString();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('ELORA READ PROFILE ERROR: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  String _value(String? key, {String fallback = 'Belum tersedia'}) {
    final value = profile?[key];

    if (value == null || value.toString().trim().isEmpty) {
      return fallback;
    }

    return value.toString();
  }

  Future<void> _pickPhoto() async {
    try {
      final xfile = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85,
      );
      if (xfile == null) return;
      final extension = xfile.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final url = await AuthService.instance.uploadAvatar(await xfile.readAsBytes(), extension);
      if (!mounted) return;
      setState(() => _photoPath = url);
    } catch (e) {
      debugPrint('ELORA PICK PHOTO ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Gagal menyimpan foto ke Supabase Storage.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: eloraBackground,
        body: Center(child: CircularProgressIndicator(color: eloraPrimary)),
      );
    }

    final nama = _value('nama', fallback: 'Pengguna ELORA');
    final studentId = _value('student_id');
    final institution = _value('institution');
    final role = _value('role', fallback: 'Pengguna');

    return Scaffold(
      backgroundColor: eloraBackground,
      body: SafeArea(
        child: RefreshIndicator(
          color: eloraPrimary,
          onRefresh: _loadProfile,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 25),
                _buildProfileCard(
                  nama: nama,
                  studentId: studentId,
                  institution: institution,
                  role: role,
                ),
                const SizedBox(height: 20),
                _buildPersonalInfo(
                  studentId: studentId,
                  institution: institution,
                  role: role,
                ),
                const SizedBox(height: 20),
                _buildFeedback(),
                const SizedBox(height: 20),
                _buildLogout(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Profile',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: eloraDark,
        ),
      ),
    );
  }

  Widget _buildProfileCard({
    required String nama,
    required String studentId,
    required String institution,
    required String role,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 82,
            height: 82,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 41,
                  backgroundColor: eloraPrimary.withValues(alpha: 0.10),
                  backgroundImage: _photoPath != null && _photoPath!.startsWith('http')
                      ? NetworkImage(_photoPath!)
                      : null,
                  child: _photoPath == null
                      ? const Icon(
                          Icons.person_rounded,
                          color: eloraPrimary,
                          size: 43,
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: eloraPrimary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          Text(
            nama,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: eloraDark,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            studentId,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            '$institution • $role',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfo({
    required String studentId,
    required String institution,
    required String role,
  }) {
    return _buildSection(
      title: 'Personal Information',
      child: Column(
        children: [
          _buildInfoItem(Icons.badge_outlined, 'Student ID', studentId),
          _buildInfoItem(Icons.school_outlined, 'Institution', institution),
          _buildInfoItem(Icons.manage_accounts_outlined, 'Role', role),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: eloraPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: eloraPrimary, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: eloraDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedback() {
    return _buildSection(
      title: 'PAM Feedback',
      child: const Text(
        'Mata kuliah Pemrograman Aplikasi Mobile memberikan '
        'pengalaman yang cukup menarik karena saya dapat mempelajari '
        'proses pengembangan aplikasi mobile menggunakan Flutter. '
        'Materi yang diberikan membantu saya memahami konsep dasar '
        'pembuatan aplikasi, mulai dari perancangan tampilan hingga '
        'implementasi fitur. Saya berharap pembelajaran PAM ke depannya '
        'dapat tetap dilakukan secara praktik agar siswa lebih mudah '
        'memahami materi yang diberikan.',
        style: TextStyle(fontSize: 12, height: 1.6, color: eloraDark),
        textAlign: TextAlign.justify,
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: eloraDark,
            ),
          ),
          const SizedBox(height: 17),
          child,
        ],
      ),
    );
  }

  Widget _buildLogout(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: OutlinedButton.icon(
        onPressed: () => _showLogoutDialog(context),
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text(
          'Logout',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red.shade600,
          side: BorderSide(color: Colors.red.shade200),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _performLogout(BuildContext context) async {
    try { await AuthService.instance.signOut(); } catch (e) { debugPrint('ELORA LOGOUT ERROR: $e'); }
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Logout',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _performLogout(context);
              },
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
