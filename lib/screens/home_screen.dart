import 'package:flutter/material.dart';

import 'package:elora_school/services/auth_service.dart';
import 'package:elora_school/services/payment_service.dart';
import 'package:elora_school/services/notification_data_service.dart';
import 'package:elora_school/theme/colors.dart';
import 'package:elora_school/widgets/elora_components.dart';
import 'package:elora_school/screens/tic_tac_toe_screen.dart';
import 'package:elora_school/screens/payment_screen.dart';
import 'package:elora_school/screens/explore_screen.dart';
import 'package:elora_school/screens/ai_screen.dart';
import 'package:elora_school/screens/currency_screen.dart';
import 'package:elora_school/screens/profile_screen.dart';
import 'package:elora_school/screens/time_screen.dart';
import 'package:elora_school/screens/blockchain_screen.dart';
import 'package:elora_school/screens/notification_screen.dart';
import 'package:get/get.dart';
import 'package:elora_school/controllers/notification_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int selectedIndex = 0;

  String _studentName = '';
  String _institution = '';
  String _studyProgram = '';

  int _unpaidMonths = 0;
  String _unpaidAmount = '—';

  bool _isLoadingProfile = true;
  bool _isLoadingPayment = true;

  List<Map<String, dynamic>> _recentNotifs = [];
  bool _isLoadingNotifs = true;

  static const Color _forest = eloraPrimary;
  static const Color _forestDark = Color(0xFF034F4C);
  static const Color _sage = Color(0xFFE5F3F1);
  static const Color _cream = eloraBackground;
  static const Color _ink = eloraDark;
  static const Color _muted = Color(0xFF737E7B);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProfile();
    _fetchPaymentSummary();
    _fetchRecentNotifications();
    Get.put(NotificationController(), permanent: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchPaymentSummary();
      _fetchRecentNotifications();
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadProfile(),
      _fetchPaymentSummary(),
      _fetchRecentNotifications(),
    ]);
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await AuthService.instance.currentProfile();
      if (!mounted) return;
      setState(() {
        _studentName = profile['nama']?.toString() ?? '';
        _institution = profile['institution']?.toString() ?? '';
        _studyProgram = profile['role']?.toString() ?? '';
        _isLoadingProfile = false;
      });
    } catch (e) {
      debugPrint('HOME PROFILE ERROR: $e');
      if (!mounted) return;
      setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _fetchPaymentSummary() async {
    try {
      final data = await PaymentService.instance.myPayments();
      final unpaid = data
          .where((p) => p['status'].toString().toLowerCase() != 'paid')
          .toList();
      final total = unpaid.fold<double>(0, (sum, p) {
        final amount = double.tryParse('${p['amount']}') ?? 0;
        final paid = double.tryParse('${p['paid_amount'] ?? 0}') ?? 0;
        return sum + (amount - paid).clamp(0, amount);
      });
      if (!mounted) return;
      setState(() {
        _unpaidMonths = unpaid.length;
        _unpaidAmount = _formatCurrency(total);
        _isLoadingPayment = false;
      });
    } catch (e) {
      debugPrint('HOME PAYMENT SUMMARY ERROR: $e');
      if (!mounted) return;
      setState(() {
        _unpaidAmount = 'Tidak tersedia';
        _isLoadingPayment = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    final value = amount.round().toString();
    final formatted = value.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => '.',
    );
    return 'Rp $formatted';
  }

  Future<void> _fetchRecentNotifications() async {
    try {
      final data = await NotificationDataService.instance.list();
      if (!mounted) return;
      setState(() {
        _recentNotifs = data.take(2).toList();
        _isLoadingNotifs = false;
      });
    } catch (e) {
      debugPrint('HOME NOTIFICATION ERROR: $e');
      if (!mounted) return;
      setState(() => _isLoadingNotifs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: IndexedStack(
          index: selectedIndex,
          children: [
            _buildHomeContent(),
            const ExplorePage(),
            const EloraAiPage(),
            const ProfilePage(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildHomeContent() {
    final displayName = _isLoadingProfile ? '...' : _studentName;

    return RefreshIndicator(
      onRefresh: _refreshAll,
      color: _forest,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: _buildHeroHeader(displayName),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _buildInstitutionCard(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              child: _buildPaymentCard(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 27, 20, 13),
              child: const EloraSectionHeader(
                title: 'Quick access',
                subtitle: 'Tools for your daily needs',
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: EloraQuickAccessGrid(
                items: [
                  // 1. Mini Game
                  EloraQuickAccessItem(
                    icon: Icons.grid_3x3_outlined,
                    title: 'Tic Tac Toe',
                    subtitle: 'Game Strategi',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TicTacToeScreen(),
                        ),
                      );
                    },
                  ),

                  // 2. Currency
                  EloraQuickAccessItem(
                    icon: Icons.currency_exchange_rounded,
                    title: 'Currency',
                    subtitle: 'Konversi mata uang',
                    backgroundColor: const Color(0xFFFFF0E5),
                    accentColor: const Color(0xFFBE865A),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CurrencyPage()),
                      );
                    },
                  ),

                  // 3. Time
                  EloraQuickAccessItem(
                    icon: Icons.schedule_rounded,
                    title: 'Time',
                    subtitle: 'Konversi waktu',
                    backgroundColor: const Color(0xFFF0ECF8),
                    accentColor: const Color(0xFF8D79B7),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TimePage()),
                      );
                    },
                  ),

                  // 4. Riwayat Perubahan
                  EloraQuickAccessItem(
                    icon: Icons.link_rounded,
                    title: 'Riwayat',
                    subtitle: 'Riwayat administrasi',
                    backgroundColor: const Color(0xFFEAF2F1),
                    accentColor: eloraPrimary,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BlockchainPage(),
                        ),
                      );
                    },
                  ),

                  // 5. ELORA AI
                  EloraQuickAccessItem(
                    icon: Icons.auto_awesome_rounded,
                    title: 'ELORA AI',
                    subtitle: 'Asisten pintar',
                    backgroundColor: const Color(0xFFECEFF8),
                    accentColor: const Color(0xFF687DAF),
                    onTap: () {
                      setState(() {
                        selectedIndex = 2;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: EloraSectionHeader(
                title: 'Recent notifications',
                trailing: TextButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationPage(),
                      ),
                    );

                    _fetchRecentNotifications();

                    Get.find<NotificationController>().refreshUnreadStatus();
                  },
                  child: const Text('See all'),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              child: _buildRecentNotifications(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(String displayName) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: SizedBox(
        height: 245,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/classroom.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: _forestDark);
              },
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xE6103028),
                    Color(0xA6103028),
                    Color(0x25103028),
                  ],
                  stops: [0, 0.62, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 17, 17, 19),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 9),
                      const Text(
                        'ELORA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      _buildNotificationButton(),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    _greeting(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _shortName(displayName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    _institution.isEmpty
                        ? 'Your learning journey starts here.'
                        : _institution,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Learn, grow, and move forward.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Good morning,';
    if (hour < 15) return 'Good afternoon,';
    if (hour < 18) return 'Good evening,';
    return 'Good night,';
  }

  Widget _buildRecentNotifications() {
    if (_isLoadingNotifs) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: _forest),
          ),
        ),
      );
    }

    if (_recentNotifs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8EAE3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.notifications_none_rounded, color: _muted),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Belum ada notifikasi.',
                style: TextStyle(fontSize: 12, color: _muted),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _recentNotifs.asMap().entries.map((entry) {
        final n = entry.value;
        final isFirst = entry.key == 0;
        final isUnread = n['is_read'] == false || n['is_read'] == 0;
        return Padding(
          padding: EdgeInsets.only(top: isFirst ? 0 : 10),
          child: _buildNotificationCard(
            icon: Icons.notifications_none_rounded,
            title: n['title']?.toString() ?? 'Notifikasi',
            description: n['message']?.toString() ?? '',
            time: n['created_at']?.toString().substring(0, 10) ?? '',
            isImportant: isUnread,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInstitutionCard() {
    return GestureDetector(
      onTap: () {
        setState(() => selectedIndex = 1);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: const Color(0xFFE9EAE3)),
        ),
        child: Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: _sage,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.account_balance_outlined,
                color: _forest,
                size: 21,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'YOUR INSTITUTION',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 0.8,
                      color: _muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _institution.isEmpty ? '—' : _institution,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _studyProgram.isEmpty ? '—' : _studyProgram,
                    style: const TextStyle(fontSize: 10, color: _muted),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: _muted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9EAE3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF20332D).withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Payment overview',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _unpaidMonths > 0 ? const Color(0xFFFFF1DD) : _sage,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  _unpaidMonths > 0 ? 'Action needed' : 'On track',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: _unpaidMonths > 0
                        ? const Color(0xFF9A6422)
                        : _forest,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 19),
          const Text(
            'Outstanding balance',
            style: TextStyle(fontSize: 11, color: _muted),
          ),
          const SizedBox(height: 5),
          _isLoadingPayment
              ? const SizedBox(
                  height: 34,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        color: _forest,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                )
              : Text(
                  _unpaidAmount,
                  style: const TextStyle(
                    color: _forestDark,
                    fontSize: 27,
                    letterSpacing: -0.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
          const SizedBox(height: 5),
          Text(
            '$_unpaidMonths months unpaid',
            style: const TextStyle(fontSize: 11, color: _muted),
          ),
          const SizedBox(height: 17),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PaymentPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _forest,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View payment details',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationButton() {
    return EloraNotificationButton(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationPage()),
        );

        if (!mounted) return;

        await _fetchRecentNotifications();
        await Get.find<NotificationController>().refreshUnreadStatus();
      },
    );
  }

  Widget _buildNotificationCard({
    required IconData icon,
    required String title,
    required String description,
    required String time,
    required bool isImportant,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE9EAE3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: isImportant ? const Color(0xFFFFF1DD) : _sage,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              size: 19,
              color: isImportant ? const Color(0xFFB8792F) : _forest,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: const TextStyle(fontSize: 9, color: _muted),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.4,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return NavigationBar(
      height: 70,
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        setState(() {
          selectedIndex = index;
        });
      },
      backgroundColor: Colors.white,
      elevation: 0,
      indicatorColor: _sage,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined, size: 21),
          selectedIcon: Icon(Icons.home_rounded, size: 21, color: _forest),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.explore_outlined, size: 21),
          selectedIcon: Icon(Icons.explore_rounded, size: 21, color: _forest),
          label: 'Explore',
        ),
        NavigationDestination(
          icon: Icon(Icons.smart_toy_outlined, size: 21),
          selectedIcon: Icon(Icons.smart_toy_rounded, size: 21, color: _forest),
          label: 'ELORA AI',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded, size: 21),
          selectedIcon: Icon(Icons.person_rounded, size: 21, color: _forest),
          label: 'Profile',
        ),
      ],
    );
  }

  String _shortName(String name) {
    if (name.isEmpty) return '';
    final firstName = name.trim().split(' ').first;
    return firstName;
  }
}
