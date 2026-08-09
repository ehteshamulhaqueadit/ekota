import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  final String authToken;

  const NotificationsScreen({Key? key, required this.authToken}) : super(key: key);

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _service = NotificationService();
  List<NotificationModel> _notifications = [];

  final List<NotificationModel> _mockNotifications = [
    NotificationModel(
      id: 'n1',
      title: 'Payment Successful',
      message: 'Your payment of ৳15,000 BDT (RENT) with Tran ID EKOTA-PAY-991 was completed successfully.',
      type: 'PAYMENT_SUCCESS',
      isRead: false,
      createdAt: DateTime.now().subtract(Duration(minutes: 35)).toIso8601String(),
    ),
    NotificationModel(
      id: 'n2',
      title: 'Withdrawal Approved',
      message: 'Your withdrawal request of ৳142,500 has been approved. Transaction Ref: TXN-EKT-998811',
      type: 'WITHDRAWAL_APPROVED',
      isRead: true,
      createdAt: DateTime.now().subtract(Duration(hours: 3)).toIso8601String(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final list = await _service.fetchNotifications(widget.authToken);
    if (mounted) {
      setState(() {
        _notifications = list.isNotEmpty ? list : _mockNotifications;
      });
    }
  }

  Future<void> _markAllRead() async {
    await _service.markAllAsRead(widget.authToken);
    if (mounted) {
      setState(() {
        _notifications = _notifications.map((n) => NotificationModel(
          id: n.id,
          title: n.title,
          message: n.message,
          type: n.type,
          isRead: true,
          createdAt: n.createdAt,
        )).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        title: Row(
          children: [
            Text('Notifications', style: AppTextStyles.h2),
            if (unreadCount > 0) ...[
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primaryAccent, borderRadius: BorderRadius.circular(12)),
                child: Text('$unreadCount unread', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.done_all, color: AppColors.primaryAccent),
            tooltip: 'Mark all as read',
            onPressed: _markAllRead,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        color: AppColors.primaryAccent,
        child: _notifications.isEmpty
            ? Container(
                padding: EdgeInsets.all(AppSpacing.xxl),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.notifications_none_outlined, color: AppColors.textMuted, size: 48),
                    SizedBox(height: 12),
                    Text('No notifications yet', style: AppTextStyles.h2),
                    Text('You will receive updates here regarding your payments & payout requests.', style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
                  ],
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.all(AppSpacing.lg),
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final n = _notifications[index];
                  final isWithdrawal = n.type.contains('WITHDRAWAL');

                  return Container(
                    margin: EdgeInsets.only(bottom: AppSpacing.md),
                    padding: EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: n.isRead ? AppColors.cardBackground : AppColors.cardBackground.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: n.isRead ? AppColors.cardBorder : AppColors.primaryAccent.withOpacity(0.5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: isWithdrawal ? AppColors.warningBg : AppColors.successBg,
                          child: Icon(
                            isWithdrawal ? Icons.account_balance_wallet_outlined : Icons.check_circle_outline,
                            color: isWithdrawal ? AppColors.warning : AppColors.success,
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      n.title,
                                      style: AppTextStyles.h3.copyWith(
                                        fontWeight: n.isRead ? FontWeight.w600 : FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (!n.isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(color: AppColors.primaryAccent, shape: BoxShape.circle),
                                    ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(n.message, style: AppTextStyles.bodySecondary),
                              SizedBox(height: 6),
                              Text(
                                n.createdAt.split('T')[0],
                                style: AppTextStyles.bodySecondary.copyWith(color: AppColors.textMuted, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
