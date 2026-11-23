import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'config/supabase_config.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'theme/colors.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/admin_dashboard_screen.dart';

String? startupError;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    startupError = e.toString().replaceFirst('Bad state: ', '');
  }
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('FIREBASE INIT ERROR: $e');
  }
  if (!kIsWeb && startupError == null) {
    try { await NotificationService.instance.init(); } catch (e) { debugPrint('FCM INIT ERROR: $e'); }
  }
  runApp(const EloraApp());
}

class EloraApp extends StatelessWidget {
  const EloraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'ELORA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthCheckPage(),
    );
  }
}

class AuthCheckPage extends StatefulWidget {
  const AuthCheckPage({super.key});
  @override
  State<AuthCheckPage> createState() => _AuthCheckPageState();
}

class _AuthCheckPageState extends State<AuthCheckPage> {
  bool isLoading = true;
  String? errorMessage;
  Widget? nextPage;

  @override
  void initState() { super.initState(); checkSession(); }

  Future<void> checkSession() async {
    if (mounted) setState(() { isLoading = true; errorMessage = null; });
    if (startupError != null) {
      setState(() { errorMessage = startupError; isLoading = false; });
      return;
    }
    try {
      if (!AuthService.instance.isSignedIn) {
        nextPage = const LoginPage();
      } else {
        final user = await AuthService.instance.currentProfile();
        if (user['is_active'] != true) {
          await AuthService.instance.signOut();
          nextPage = const LoginPage();
        } else if (user['role']?.toString().toLowerCase() == 'admin') {
          nextPage = AdminDashboardPage(user: user);
        } else {
          nextPage = const HomePage();
        }
      }
    } catch (e) {
      debugPrint('ELORA SESSION ERROR: $e');
      if (!mounted) return;
      setState(() { errorMessage = 'Tidak dapat memeriksa sesi Supabase. Periksa konfigurasi project dan koneksi internet.\n$e'; isLoading = false; });
      return;
    }
    if (!mounted) return;
    setState(() => isLoading = false);
  }

  Future<void> _returnToLogin() async {
    try { await AuthService.instance.signOut(); } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: eloraPrimary)));
    if (errorMessage != null) {
      return Scaffold(body: Center(child: Padding(
        padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: eloraPrimary),
          const SizedBox(height: 16), Text(errorMessage!, textAlign: TextAlign.center),
          const SizedBox(height: 16), ElevatedButton(onPressed: checkSession, child: const Text('Coba Lagi')),
          TextButton(onPressed: _returnToLogin, child: const Text('Kembali ke Login')),
        ]),
      )));
    }
    return nextPage ?? const LoginPage();
  }
}
