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
import 'screens/splash_screen.dart';

String? startupError;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ==============================
  // SUPABASE
  // ==============================

  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    startupError = e.toString().replaceFirst(
          'Bad state: ',
          '',
        );
  }

  // ==============================
  // FIREBASE
  // ==============================

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint(
      'FIREBASE INIT ERROR: $e',
    );
  }

  // ==============================
  // NOTIFICATION
  // ==============================

  if (!kIsWeb && startupError == null) {
    try {
      await NotificationService.instance.init();
    } catch (e) {
      debugPrint(
        'FCM INIT ERROR: $e',
      );
    }
  }

  runApp(
    const EloraApp(),
  );
}

class EloraApp extends StatelessWidget {
  const EloraApp({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return GetMaterialApp(
      title: 'ELORA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,

      // ==============================
      // SPLASH DULU
      // ==============================

      home: const EloraSplashPage(),
    );
  }
}

// ==========================================================
// AUTH CHECK
// ==========================================================

class AuthCheckPage extends StatefulWidget {
  const AuthCheckPage({
    super.key,
  });

  @override
  State<AuthCheckPage> createState() =>
      _AuthCheckPageState();
}

class _AuthCheckPageState
    extends State<AuthCheckPage> {
  bool isLoading = true;

  String? errorMessage;

  Widget? nextPage;

  @override
  void initState() {
    super.initState();

    checkSession();
  }

  Future<void> checkSession() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    // ==========================================
    // STARTUP ERROR
    // ==========================================

    if (startupError != null) {
      if (!mounted) return;

      setState(() {
        errorMessage = startupError;
        isLoading = false;
      });

      return;
    }

    try {
      // ========================================
      // BELUM LOGIN
      // ========================================

      if (!AuthService.instance.isSignedIn) {
        nextPage = const LoginPage();
      }

      // ========================================
      // SUDAH LOGIN
      // ========================================

      else {
        final user =
            await AuthService.instance.currentProfile();

        // ======================================
        // USER TIDAK AKTIF
        // ======================================

        if (user['is_active'] != true) {
          await AuthService.instance.signOut();

          nextPage =
              const LoginPage();
        }

        // ======================================
        // ADMIN
        // ======================================

        else if (
          user['role']
                  ?.toString()
                  .toLowerCase() ==
              'admin'
        ) {
          nextPage =
              AdminDashboardPage(
            user: user,
          );
        }

        // ======================================
        // STUDENT
        // ======================================

        else {
          nextPage =
              const HomePage();
        }
      }
    } catch (e) {
      debugPrint(
        'ELORA SESSION ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        errorMessage =
            'Tidak dapat memeriksa sesi Supabase. '
            'Periksa konfigurasi project dan koneksi internet.\n$e';

        isLoading = false;
      });

      return;
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _returnToLogin() async {
    try {
      await AuthService.instance.signOut();
    } catch (_) {}

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            const LoginPage(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    // ==========================================
    // LOADING
    // ==========================================

    if (isLoading) {
      return const Scaffold(
        backgroundColor:
            eloraBackground,
        body: Center(
          child:
              CircularProgressIndicator(
            color:
                eloraPrimary,
          ),
        ),
      );
    }

    // ==========================================
    // ERROR
    // ==========================================

    if (errorMessage != null) {
      return Scaffold(
        backgroundColor:
            eloraBackground,
        body: Center(
          child: Padding(
            padding:
                const EdgeInsets.all(
              24,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width:
                      72,
                  height:
                      72,
                  decoration:
                      BoxDecoration(
                    color:
                        eloraPrimary.withValues(
                      alpha:
                          0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      22,
                    ),
                  ),
                  child:
                      const Icon(
                    Icons.cloud_off_rounded,
                    size:
                        34,
                    color:
                        eloraPrimary,
                  ),
                ),

                const SizedBox(
                  height:
                      18,
                ),

                const Text(
                  'Something went wrong',
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    fontSize:
                        18,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        eloraDark,
                  ),
                ),

                const SizedBox(
                  height:
                      10,
                ),

                Text(
                  errorMessage!,
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    fontSize:
                        11,
                    height:
                        1.5,
                    color:
                        Colors.grey.shade600,
                  ),
                ),

                const SizedBox(
                  height:
                      22,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  height:
                      48,
                  child:
                      ElevatedButton(
                    onPressed:
                        checkSession,
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          eloraPrimary,
                      foregroundColor:
                          Colors.white,
                      elevation:
                          0,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                    ),
                    child:
                        const Text(
                      'Coba Lagi',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                TextButton(
                  onPressed:
                      _returnToLogin,
                  child:
                      const Text(
                    'Kembali ke Login',
                    style:
                        TextStyle(
                      color:
                          eloraPrimary,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return nextPage ??
        const LoginPage();
  }
}