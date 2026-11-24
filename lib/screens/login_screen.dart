import 'package:flutter/material.dart';
import 'package:elora_school/widgets/elora_components.dart';
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

  // Perangkat mendukung biometrik atau kunci layar.
  bool _canUseBiometric = false;

  // Sudah ada kredensial tersimpan dari login manual sebelumnya.
  bool _hasBiometricCredentials = false;

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

  // =========================================================
  // BIOMETRIK
  // =========================================================

  Future<void> _checkBiometricAvailability() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      final available = await _localAuth.getAvailableBiometrics();

      debugPrint(
        'BIOMETRIC canCheck=$canCheck '
        'isSupported=$isSupported '
        'available=$available',
      );

      if (!canCheck && !isSupported) return;

      final hasCredentials = await AuthService.instance
          .hasBiometricCredentials();

      if (!mounted) return;

      setState(() {
        _canUseBiometric = true;
        _hasBiometricCredentials = hasCredentials;
      });
    } catch (e) {
      debugPrint('BIOMETRIC CHECK ERROR: $e');
    }
  }

  Future<void> _syncBiometricCredentials(
    String identifier,
    String password,
  ) async {
    if (!_canUseBiometric) return;

    try {
      final stored = await AuthService.instance
          .storedBiometricIdentifier();

      final sameAccount =
          stored != null &&
          stored.trim().toLowerCase() ==
              identifier.trim().toLowerCase();

      if (sameAccount) {
        await AuthService.instance.saveBiometricCredentials(
          identifier: identifier,
          password: password,
        );
        return;
      }

      if (!mounted) return;

      final enable = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Aktifkan Login Biometrik?'),
          content: const Text(
            'Setelah logout, kamu bisa masuk kembali hanya '
            'dengan sidik jari, wajah, atau PIN perangkat. '
            'Data login disimpan terenkripsi di perangkat ini.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Nanti Saja'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: eloraPrimary,
              ),
              child: const Text('Aktifkan'),
            ),
          ],
        ),
      );

      if (enable != true) return;

      await AuthService.instance.saveBiometricCredentials(
        identifier: identifier,
        password: password,
      );

      if (mounted) {
        setState(() {
          _hasBiometricCredentials = true;
        });
      }
    } catch (e) {
      debugPrint('BIOMETRIC ENROLL ERROR: $e');
    }
  }

  Future<void> _loginWithBiometric() async {
    if (_isBiometricLoading) return;

    setState(() {
      _isBiometricLoading = true;
    });

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason:
            'Gunakan biometrik untuk masuk ke ELORA',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      if (!authenticated) return;
      if (!mounted) return;

      if (!AuthService.instance.isSignedIn) {
        await AuthService.instance.signInWithBiometric();
        await NotificationService.instance.onLogin();

        if (!mounted) return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const AuthCheckPage(),
        ),
        (route) => false,
      );
    } on PlatformException catch (e) {
      if (!mounted) return;

      debugPrint(
        'BIOMETRIC ERROR code=${e.code} '
        'msg=${e.message}',
      );

      final msg = switch (e.code) {
        'NotAvailable' =>
          'Biometrik tidak tersedia di perangkat ini.',
        'NotEnrolled' =>
          'Belum ada sidik jari/wajah yang terdaftar.',
        'LockedOut' =>
          'Terlalu banyak percobaan. Coba lagi nanti.',
        'PermanentlyLockedOut' =>
          'Biometrik dikunci. Gunakan PIN perangkat.',
        _ =>
          'Autentikasi biometrik gagal. (${e.code})',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } on AuthFailure catch (e) {
      if (!mounted) return;

      debugPrint(
        'BIOMETRIC SIGN IN ERROR: ${e.message}',
      );

      if (e.invalidCredentials) {
        setState(() {
          _hasBiometricCredentials = false;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      debugPrint('BIOMETRIC UNKNOWN ERROR: $e');

      if (!mounted) return;

      final text = e.toString().toLowerCase();

      if (text.contains('cancel')) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBiometricLoading = false;
        });
      }
    }
  }

  // =========================================================
  // LOGIN MANUAL
  // =========================================================

  Future<void> _login() async {
    final identifier =
        _studentIdController.text.trim();

    final password =
        _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nomor pelajar/email dan password harus diisi.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService.instance.signIn(
        identifier: identifier,
        password: password,
      );

      await NotificationService.instance.onLogin();

      await _syncBiometricCredentials(
        identifier,
        password,
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const AuthCheckPage(),
        ),
        (route) => false,
      );
    } catch (e) {
      debugPrint('ELORA LOGIN ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // =================================================
              // HEADER TEAL
              // =================================================
              //
              // DIBUAT LEBIH TINGGI supaya ELORA putih
              // benar-benar berada di atas background teal.
              //
              SizedBox(
                height: 390,
                width: double.infinity,
                child: ClipPath(
                  clipper: LoginWaveClipper(),
                  child: Container(
                    width: double.infinity,
                    color: eloraPrimary,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: 18,
                          bottom: 55,
                          left: 30,
                          right: 30,
                        ),
                        child: _buildLogo(),
                      ),
                    ),
                  ),
                ),
              ),

              // =================================================
              // LOGIN PANEL
              // =================================================

              Transform.translate(
                offset: const Offset(0, -1),
                child: _buildLoginPanel(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // LOGO
  // =========================================================

  Widget _buildLogo() {
    return Image.asset(
      'assets/logo.png',
      width: 150,
      height: 150,
      fit: BoxFit.contain,
      errorBuilder: (
        context,
        error,
        stackTrace,
      ) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                ),
              ),
              child: const Icon(
                Icons.school_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'ELORA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Your student companion',
              style: TextStyle(
                color: Colors.white.withOpacity(0.78),
                fontSize: 12,
              ),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // LOGIN PANEL
  // =========================================================

  Widget _buildLoginPanel() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            39,
            28,
            39,
            30,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome back.',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: eloraDark,
                  height: 1.1,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Sign in to continue to your ELORA account.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),

              const SizedBox(height: 32),

              // NOMOR PELAJAR
              _buildLabel(
                'NOMOR PELAJAR / EMAIL',
              ),

              const SizedBox(height: 9),

              _buildTextField(
                controller:
                    _studentIdController,
                hintText:
                    'Nomor pelajar atau email',
                keyboardType:
                    TextInputType.emailAddress,
              ),

              const SizedBox(height: 26),

              // PASSWORD
              _buildLabel('PASSWORD'),

              const SizedBox(height: 9),

              _buildTextField(
                controller:
                    _passwordController,
                hintText: 'Password',
                obscureText:
                    _obscurePassword,
                suffixIcon:
                    IconButton(
                  splashRadius: 20,
                  onPressed: () {
                    setState(() {
                      _obscurePassword =
                          !_obscurePassword;
                    });
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color:
                        Colors.grey.shade500,
                    size: 20,
                  ),
                ),
              ),

              const SizedBox(height: 33),

              // LOGIN BUTTON
              EloraPrimaryButton(
                label: 'Log in',
                onPressed: _login,
                isLoading: _isLoading,
                height: 45,
              ),

              // BIOMETRIC
              if (_canUseBiometric &&
                  _hasBiometricCredentials) ...[
                const SizedBox(height: 17),

                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color:
                            Colors.grey.shade300,
                      ),
                    ),

                    Padding(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      child: Text(
                        'atau',
                        style: TextStyle(
                          fontSize: 10,
                          color:
                              Colors.grey.shade400,
                        ),
                      ),
                    ),

                    Expanded(
                      child: Divider(
                        color:
                            Colors.grey.shade300,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: OutlinedButton.icon(
                    onPressed:
                        (_isBiometricLoading ||
                                _isLoading)
                            ? null
                            : _loginWithBiometric,
                    icon:
                        _isBiometricLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                  color:
                                      eloraPrimary,
                                ),
                              )
                            : const Icon(
                                Icons
                                    .fingerprint_rounded,
                                size: 22,
                              ),
                    label: const Text(
                      'Masuk dengan Biometrik',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    style:
                        OutlinedButton.styleFrom(
                      foregroundColor:
                          eloraPrimary,
                      side:
                          const BorderSide(
                        color:
                            eloraPrimary,
                        width: 1.2,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          11,
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 27),

              // SIGN UP
              Center(
                child: GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const RegisterPage(),
                            ),
                          );
                        },
                  child: Text(
                    "Don't have an account? "
                    "Sign up",
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          Colors.grey.shade500,
                    ),
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

  // =========================================================
  // LABEL
  // =========================================================

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
        color: Colors.grey.shade500,
      ),
    );
  }

  // =========================================================
  // TEXT FIELD
  // =========================================================

  Widget _buildTextField({
    required TextEditingController
        controller,
    required String hintText,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return SizedBox(
      height: 59,
      child: EloraTextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(
          fontSize: 13,
          color: eloraDark,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade400,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 21,
            vertical: 18,
          ),
          suffixIcon: suffixIcon,

          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(17),
            borderSide: BorderSide(
              color:
                  Colors.grey.shade200,
            ),
          ),

          enabledBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(17),
            borderSide: BorderSide(
              color:
                  Colors.grey.shade200,
            ),
          ),

          focusedBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(17),
            borderSide:
                const BorderSide(
              color: eloraPrimary,
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================
// CURVE TEAL
// =============================================================

class LoginWaveClipper
    extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    // Mulai dari kiri atas
    path.moveTo(0, 0);

    // Turun sampai bagian kiri bawah
    path.lineTo(
      0,
      size.height - 70,
    );

    // Curve pertama
    path.cubicTo(
      size.width * 0.20,
      size.height - 35,
      size.width * 0.42,
      size.height - 5,
      size.width * 0.62,
      size.height - 30,
    );

    // Curve kedua menuju kanan
    path.cubicTo(
      size.width * 0.79,
      size.height - 48,
      size.width * 0.91,
      size.height - 65,
      size.width,
      size.height - 78,
    );

    // Naik ke kanan atas
    path.lineTo(
      size.width,
      0,
    );

    path.close();

    return path;
  }

  @override
  bool shouldReclip(
    covariant LoginWaveClipper oldClipper,
  ) {
    return false;
  }
}