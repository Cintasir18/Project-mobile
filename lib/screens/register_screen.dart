import 'package:flutter/material.dart';
import 'package:elora_school/widgets/elora_components.dart';

import 'package:elora_school/theme/colors.dart';
import 'package:elora_school/services/auth_service.dart';
import 'package:elora_school/services/institution_service.dart';

import 'login_screen.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nisController = TextEditingController();
  final _namaController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _institutions = [];
  int? _selectedInstitutionId;
  bool _isLoadingInstitutions = true;
  String? _institutionsError;

  @override
  void initState() {
    super.initState();
    _fetchInstitutions();
  }

  @override
  void dispose() {
    _nisController.dispose();
    _namaController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _fetchInstitutions() async {
    setState(() {
      _isLoadingInstitutions = true;
      _institutionsError = null;
    });
    try {
      final data = await InstitutionService.instance.fetchInstitutions();
      if (!mounted) return;
      setState(() {
        _institutions = data;
        _isLoadingInstitutions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _institutionsError = 'Tidak dapat memuat institusi dari Supabase. Periksa koneksi dan kebijakan RLS.';
        _isLoadingInstitutions = false;
      });
    }
  }

  Future<void> _register() async {
    final nis = _nisController.text.trim();
    final nama = _namaController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (nis.isEmpty || nama.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showSnack('Semua data harus diisi.');
      return;
    }
    if (_selectedInstitutionId == null) {
      _showSnack('Pilih institusi terlebih dahulu.');
      return;
    }
    if (password.length < 8) {
      _showSnack('Password minimal 8 karakter.');
      return;
    }
    if (password != confirm) {
      _showSnack('Konfirmasi password tidak sesuai.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await AuthService.instance.signUp(
        studentId: nis,
        fullName: nama,
        institutionId: _selectedInstitutionId!,
        password: password,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registrasi berhasil! Silakan login dengan NIS dan password kamu.'), backgroundColor: eloraPrimary),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('ELORA REGISTER ERROR: $e');
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: eloraPrimary,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 70,
              width: double.infinity,
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.pop(context),
                  padding: const EdgeInsets.only(left: 20),
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(38),
          topRight: Radius.circular(38),
        ),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(42, 42, 42, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Center(
              child: Column(
                children: [
                  Text(
                    'Daftar Akun',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: eloraDark,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 9),
                  Text(
                    'Masukkan data kamu untuk membuat akun',
                    style: TextStyle(fontSize: 10.5, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            _buildLabel('NIS / ID PELAJAR'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _nisController,
              hintText: 'Nomor Induk Siswa / ID Pelajar',
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 20),

            _buildLabel('NAMA LENGKAP'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _namaController,
              hintText: 'Nama lengkap sesuai kartu pelajar',
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 20),

            _buildLabel('INSTITUSI'),
            const SizedBox(height: 8),
            _buildInstitutionDropdown(),
            const SizedBox(height: 20),

            _buildLabel('PASSWORD'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _passwordController,
              hintText: 'Minimal 8 karakter',
              obscureText: _obscurePassword,
              suffixIcon: _toggleIcon(
                obscure: _obscurePassword,
                onTap: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            const SizedBox(height: 20),

            _buildLabel('KONFIRMASI PASSWORD'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _confirmController,
              hintText: 'Ulangi password',
              obscureText: _obscureConfirmPassword,
              suffixIcon: _toggleIcon(
                obscure: _obscureConfirmPassword,
                onTap: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
              ),
            ),
            const SizedBox(height: 48),

            EloraPrimaryButton(
              label: 'Daftar',
              onPressed: _isLoadingInstitutions ? null : _register,
              isLoading: _isSubmitting,
              height: 46,
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildInstitutionDropdown() {
    if (_isLoadingInstitutions) {
      return Container(
        height: 45,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: eloraInput,
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: eloraPrimary,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Memuat institusi...',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_institutionsError != null) {
      return GestureDetector(
        onTap: _fetchInstitutions,
        child: Container(
          height: 45,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.refresh_rounded, size: 16, color: Colors.red.shade400),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _institutionsError!,
                  style: TextStyle(fontSize: 10.5, color: Colors.red.shade600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: eloraInput,
        borderRadius: BorderRadius.circular(11),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedInstitutionId,
          isExpanded: true,
          hint: const Text(
            'Pilih institusi',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: eloraDark),
          style: const TextStyle(fontSize: 12, color: eloraDark),
          items: _institutions.map((inst) {
            return DropdownMenuItem<int>(
              value: inst['id'] as int,
              child: Text(
                inst['name']?.toString() ?? '',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: _isSubmitting
              ? null
              : (value) => setState(() => _selectedInstitutionId = value),
        ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return SizedBox(
      height: 45,
      child: EloraTextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        enabled: !_isSubmitting,
        style: const TextStyle(fontSize: 12, color: eloraDark),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          filled: true,
          fillColor: eloraInput,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 12,
          ),
          suffixIcon: suffixIcon,
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
        ),
      ),
    );
  }

  Widget _toggleIcon({required bool obscure, required VoidCallback onTap}) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 20,
        color: Colors.grey.shade600,
      ),
    );
  }
}
