
import 'package:flutter/material.dart';

import 'package:elora_school/theme/colors.dart';
import 'package:elora_school/services/auth_service.dart';
import 'package:elora_school/services/payment_service.dart';
import 'package:elora_school/services/notification_data_service.dart';
import 'package:elora_school/screens/quiz_screen.dart';
import 'package:elora_school/screens/payment_screen.dart';
import 'package:elora_school/screens/explore_screen.dart';
import 'package:elora_school/screens/ai_screen.dart';
import 'package:elora_school/screens/currency_screen.dart';
import 'package:elora_school/screens/profile_screen.dart';
import 'package:elora_school/screens/time_screen.dart';
import 'package:elora_school/screens/blockchain_screen.dart';
import 'package:elora_school/screens/notification_screen.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProfile();
    _fetchPaymentSummary();
    _fetchRecentNotifications();
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
      final unpaid = data.where((p) => p['status'].toString().toLowerCase() != 'paid').toList();
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
      setState(() { _unpaidAmount = 'Tidak tersedia'; _isLoadingPayment = false; });
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
      backgroundColor: eloraBackground,

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
      color: eloraPrimary,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: eloraPrimary,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(displayName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 13),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good morning,',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _shortName(displayName),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: eloraDark,
                          ),
                        ),
                      ],
                    ),
                  ),

                  _buildNotificationButton(),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
              child: _buildInstitutionCard(),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
              child: _buildPaymentCard(),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 12),
              child: const Text(
                'Quick Access',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: eloraDark,
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.45,
              ),
              delegate: SliverChildListDelegate([
                _buildQuickAccess(
                  icon: Icons.emoji_events_outlined,
                  title: 'Quiz',
                  subtitle: 'Test your knowledge',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const QuizPage()),
                    );
                  },
                ),
                _buildQuickAccess(
                  icon: Icons.currency_exchange,
                  title: 'Currency',
                  subtitle: 'Currency converter',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CurrencyPage(),
                      ),
                    );
                  },
                ),
                _buildQuickAccess(
                  icon: Icons.access_time_outlined,
                  title: 'Time',
                  subtitle: 'Time converter',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const TimePage()),
                    );
                  },
                ),
                _buildQuickAccess(
                  icon: Icons.link_outlined,
                  title: 'Riwayat Perubahan',
                  subtitle: 'Riwayat perubahan SPP terverifikasi',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BlockchainPage(),
                      ),
                    );
                  },
                ),
              ]),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Recent Notifications',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: eloraDark,
                      ),
                    ),
                  ),

                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationPage(),
                        ),
                      ).then((_) => _fetchRecentNotifications());
                    },
                    child: Text(
                      'See all',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: eloraPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 30),
              child: _buildRecentNotifications(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentNotifications() {
    if (_isLoadingNotifs) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: eloraPrimary,
            ),
          ),
        ),
      );
    }

    if (_recentNotifs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: eloraCard,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          'Belum ada notifikasi.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
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
            icon: Icons.notifications_outlined,
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
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: eloraCard,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: eloraPrimary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.school_outlined,
                color: eloraPrimary,
                size: 22,
              ),
            ),

            const SizedBox(width: 13),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Institution',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _institution.isEmpty ? '—' : _institution,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: eloraDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _studyProgram.isEmpty ? '—' : _studyProgram,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: eloraPrimary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Payment Status',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Action needed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 17),

          const Text(
            'Outstanding',
            style: TextStyle(color: Colors.white70, fontSize: 10),
          ),

          const SizedBox(height: 3),

          _isLoadingPayment
              ? const SizedBox(
                  height: 36,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                )
              : Text(
                  _unpaidAmount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),

          const SizedBox(height: 5),

          Text(
            '$_unpaidMonths months unpaid',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),

          const SizedBox(height: 17),

          SizedBox(
            width: double.infinity,
            height: 39,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PaymentPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: eloraPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'View Payment Details',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccess({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: eloraCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 37,
              height: 37,
              decoration: BoxDecoration(
                color: eloraPrimary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: eloraPrimary, size: 20),
            ),

            const Spacer(),

            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: eloraDark,
              ),
            ),

            const SizedBox(height: 2),

            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NotificationPage()),
        ).then((_) => _fetchRecentNotifications());
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: eloraDark,
              size: 22,
            ),
          ),

          Positioned(
            right: 7,
            top: 6,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
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
        color: eloraCard,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: isImportant
                  ? Colors.orange.withValues(alpha: 0.12)
                  : eloraPrimary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 19,
              color: isImportant ? Colors.orange.shade700 : eloraPrimary,
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
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: eloraDark,
                        ),
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                Text(
                  description,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.35,
                    color: Colors.grey.shade600,
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
      height: 68,
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        setState(() {
          selectedIndex = index;
        });
      },
      backgroundColor: Colors.white,
      elevation: 0,
      indicatorColor: eloraPrimary.withValues(alpha: 0.12),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined, size: 22),
          selectedIcon: Icon(Icons.home_rounded, size: 22, color: eloraPrimary),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.location_on_outlined, size: 22),
          selectedIcon: Icon(
            Icons.location_on_rounded,
            size: 22,
            color: eloraPrimary,
          ),
          label: 'Explore',
        ),
        NavigationDestination(
          icon: Icon(Icons.smart_toy_outlined, size: 22),
          selectedIcon: Icon(
            Icons.smart_toy_rounded,
            size: 22,
            color: eloraPrimary,
          ),
          label: 'ELORA AI',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded, size: 22),
          selectedIcon: Icon(
            Icons.person_rounded,
            size: 22,
            color: eloraPrimary,
          ),
          label: 'Profile',
        ),
      ],
    );
  }

  String _getInitials(String name) {
    final words = name.trim().split(' ');

    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }

    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  String _shortName(String name) {
    if (name.isEmpty) return '';
    final firstName = name.trim().split(' ').first;
    return firstName;
  }
}
