import 'package:flutter/material.dart';

import 'package:elora_school/theme/colors.dart';
import 'package:elora_school/services/notification_data_service.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchNotifications();
    }
  }

  Future<void> _fetchNotifications() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final data = await NotificationDataService.instance.list();
      if (!mounted) return;
      final mapped = data
          .map<Map<String, dynamic>>(
            (item) => {
              'id': item['id'],
              'title': item['title']?.toString() ?? '',
              'message': item['message']?.toString() ?? '',
              'time': _formatTime(item['created_at']?.toString()),
              'icon': _iconForType(item['type']?.toString() ?? ''),
              'is_read': _normalizeRead(item['is_read']),
            },
          )
          .toList();
      setState(() {
        _notifications = mapped;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('NOTIFICATION FETCH ERROR: $e');
      if (!mounted) return;
      setState(() {
        _notifications = [];
        _isLoading = false;
      });
    }
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'payment':
      case 'spp':
        return Icons.payments_outlined;

      case 'announcement':
      case 'pengumuman':
        return Icons.campaign_outlined;

      case 'academic':
      case 'akademik':
        return Icons.school_outlined;

      case 'reminder':
      case 'reminder_payment':
        return Icons.alarm_outlined;

      default:
        return Icons.notifications_outlined;
    }
  }

  bool _normalizeRead(dynamic value) {
    if (value == true || value == 1) return true;

    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }

    return false;
  }

  String _formatTime(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw);
      final diff = DateTime.now().difference(dt).inDays;
      if (diff == 0) return 'Hari ini';
      if (diff == 1) return 'Kemarin';
      return '$diff hari lalu';
    } catch (_) {
      return raw;
    }
  }

  Future<void> _markAsRead(dynamic id, int index) async {
    if (_notifications[index]['is_read'] == true) return;
    try {
      await NotificationDataService.instance.markRead(int.parse(id.toString()));
      if (!mounted) return;
      setState(() => _notifications[index]['is_read'] = true);
    } catch (e) {
      debugPrint('MARK READ ERROR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: eloraBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: eloraPrimary),
                    )
                  : RefreshIndicator(
                      color: eloraPrimary,
                      onRefresh: _fetchNotifications,
                      child: _notifications.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                const SizedBox(height: 120),
                                Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.notifications_none_rounded,
                                        size: 56,
                                        color: Colors.grey.shade300,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Belum ada notifikasi',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                              itemCount: _notifications.length,
                              itemBuilder: (context, index) {
                                return _buildNotification(
                                  _notifications[index],
                                  index,
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: eloraDark,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: eloraDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotification(Map<String, dynamic> notification, int index) {
    final isUnread = notification['is_read'] == false;

    return GestureDetector(
      onTap: () => _markAsRead(notification['id'], index),
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: eloraPrimary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    notification['icon'] as IconData? ??
                        Icons.notifications_outlined,
                    color: eloraPrimary,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification['title']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: eloraDark,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        notification['message']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.4,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        notification['time']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isUnread)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 9,
                height: 9,
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
}
