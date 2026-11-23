import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'package:elora_school/main.dart' show AuthCheckPage;
import 'package:elora_school/theme/colors.dart';
import 'package:elora_school/services/auth_service.dart';
import 'package:elora_school/services/notification_service.dart';

import 'register_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _studentIdController = TextEditingController();
  final _passwordController = TextEditingController();

  final _localAuth = LocalAuthentication();

  bool _obscurePassword = true;
  bool _isLoading = false;

  bool _canUseBiometric = false;
  bool _isBiometricLoading = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      final available = await _localAuth.getAvailableBiometrics();

      debugPrint(
        'BIOMETRIC canCheck=$canCheck isSupported=$isSupported available=$available',
      );

      if (!canCheck && !isSupported) return;

      if (!mounted) return;
      setState(() => _canUseBiometric = true);
    } catch (e) {
      debugPrint('BIOMETRIC CHECK ERROR: $e');
    }
  }

  Future<void> _loginWithBiometric() async {
    if (_isBiometricLoading) return;
    setState(() => _isBiometricLoading = true);

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Gunakan biometrik untuk masuk ke ELORA',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      if (!authenticated) {
        return;
      }

      if (!mounted) return;

      if (!AuthService.instance.isSignedIn) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Silakan login manual terlebih dahulu, '
              'lalu biometrik bisa digunakan untuk login berikutnya.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthCheckPage()),
        (route) => false,
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      debugPrint('BIOMETRIC ERROR code=${e.code} msg=${e.message}');
      final msg = switch (e.code) {
        'NotAvailable' => 'Biometrik tidak tersedia di perangkat ini.',
        'NotEnrolled' => 'Belum ada sidik jari/wajah yang terdaftar.',
        'LockedOut' => 'Terlalu banyak percobaan. Coba lagi nanti.',
        'PermanentlyLockedOut' => 'Biometrik dikunci. Gunakan PIN perangkat.',
        _ => 'Autentikasi biometrik gagal. (${e.code})',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      debugPrint('BIOMETRIC UNKNOWN ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isBiometricLoading = false);
    }
  }

  Future<void> _login() async {
    final identifier = _studentIdController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor pelajar/email dan password harus diisi.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.instance.signIn(identifier: identifier, password: password);
      await NotificationService.instance.onLogin();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthCheckPage()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('ELORA LOGIN ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')),
          duration: const Duration(seconds: 5)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: eloraPrimary,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [

          Expanded(flex: 3, child: Center(child: _buildLogo())),

          Expanded(flex: 7, child: _buildLoginPanel()),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/logo.png',
      errorBuilder: (context, error, stackTrace) => const Icon(Icons.school_rounded, color: Colors.white, size: 78),
      width: 100,
      height: 100,
      fit: BoxFit.contain,
    );
  }

  Widget _buildLoginPanel() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(38),
          topRight: Radius.circular(38),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(36, 42, 36, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Center(
                child: Column(
                  children: [
                    const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w800,
                        color: eloraDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sign in to continue.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 35),

              _buildLabel('NOMOR PELAJAR / EMAIL'),
              const SizedBox(height: 7),
              _buildTextField(
                controller: _studentIdController,
                hintText: 'Nomor pelajar atau email',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 25),

              _buildLabel('PASSWORD'),
              const SizedBox(height: 7),
              _buildTextField(
                controller: _passwordController,
                hintText: 'Password',
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  splashRadius: 20,
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 19,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: eloraPrimary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: eloraPrimary.withValues(
                      alpha: 0.6,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Log in',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),

              if (_canUseBiometric) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'atau',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: OutlinedButton.icon(
                    onPressed: _isBiometricLoading ? null : _loginWithBiometric,
                    icon: _isBiometricLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: eloraPrimary,
                            ),
                          )
                        : const Icon(Icons.fingerprint_rounded, size: 22),
                    label: const Text(
                      'Masuk dengan Biometrik',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: eloraPrimary,
                      side: const BorderSide(color: eloraPrimary, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 27),

              Center(
                child: GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterPage(),
                          ),
                        ),
                  child: Text(
                    'Sign up!',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
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
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
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
}
